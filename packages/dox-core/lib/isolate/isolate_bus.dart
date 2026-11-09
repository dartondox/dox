import 'dart:async';
import 'dart:isolate';

/// Sends messages between the isolates of one Dox app.
///
/// Each isolate has its own memory. To tell the other isolates about
/// something (a broadcast for their sockets, a cache key to forget), an
/// isolate [publish]es a message on a channel. Every other isolate that
/// listens [on] that channel gets it. A listener never sees the messages
/// of another channel.
///
/// ```
/// IsolateBus.instance.on('users').listen(onMessage);
/// IsolateBus.instance.publish('users', <Object>['changed', 42]);
/// ```
///
/// The main isolate keeps a hub. `DoxIsolate` gives every isolate it
/// starts the [port] of the hub, and the isolate calls [connect] with it.
/// With one isolate, nothing is sent: there is no other isolate.
///
/// A message must be something a [SendPort] can send: null, bool, num,
/// String, typed data, and lists and maps of those.
class IsolateBus {
  IsolateBus._();

  /// one per isolate
  static final IsolateBus instance = IsolateBus._();

  /// the hub, only in the main isolate
  ReceivePort? _hubPort;

  /// hub: isolate id -> inbox of the isolates that listen
  final Map<int, SendPort> _members = <int, SendPort>{};

  /// the hub of the main isolate, null in the main isolate itself
  SendPort? _hub;
  int _id = 1;

  /// messages from the hub to this isolate
  ReceivePort? _inbox;

  /// channel name -> its listeners in this isolate
  final Map<String, StreamController<Object?>> _channels =
      <String, StreamController<Object?>>{};
  int _size = 1;

  /// The port of the hub. Opened on the first call, in the main isolate.
  ///
  /// Internal: `DoxIsolate` uses it. Apps do not call it.
  SendPort get port {
    ReceivePort hub = _hubPort ??= ReceivePort()..listen(_serve);
    return hub.sendPort;
  }

  /// Use the hub [hub] (a [port] of the main isolate) from now on.
  /// [id] is the id of this isolate. null [hub]: this is the main isolate.
  ///
  /// Internal: the isolate start code calls it. Apps do not call it.
  void connect(SendPort? hub, int id) {
    _hub = hub;
    _id = id;
  }

  /// Messages on [channel] from the other isolates. The first call (on
  /// any channel) joins the bus. An isolate never gets its own messages.
  Stream<Object?> on(String channel) {
    if (_inbox == null) {
      ReceivePort inbox = ReceivePort()..listen(_onInbox);
      _inbox = inbox;
      _send(<Object>['join', _id, inbox.sendPort]);
    }
    return _channels
        .putIfAbsent(channel, StreamController<Object?>.broadcast)
        .stream;
  }

  /// Number of isolates that listen on the bus, this one included.
  /// It is 1 until this isolate calls [on] and the hub answers.
  int get size => _size;

  /// Sends [message] to every other isolate that listens [on] [channel].
  void publish(String channel, Object? message) {
    _send(<Object?>['send', _id, channel, message]);
  }

  /// In the main isolate: forget isolate [id], because it stopped.
  /// `DoxIsolate` calls it when an isolate exits, also after a crash.
  ///
  /// Internal: apps do not call it.
  void drop(int id) {
    if (_members.remove(id) != null) _sendSize();
  }

  /// Leave the bus and close the ports. In the main isolate it also
  /// closes the hub.
  ///
  /// Internal: Dox calls it when the app stops. Apps do not call it.
  void close() {
    if (_inbox != null) _send(<Object>['leave', _id]);
    _inbox?.close();
    _inbox = null;
    _hubPort?.close();
    _hubPort = null;
    _members.clear();
    _hub = null;
    _id = 1;
    _size = 1;
    for (StreamController<Object?> channel in _channels.values) {
      unawaited(channel.close());
    }
    _channels.clear();
  }

  void _send(List<Object?> message) {
    SendPort? hub = _hub;
    if (hub != null) {
      hub.send(message);
    } else {
      // the main isolate: the hub is here, so no message is needed
      _serve(message);
    }
  }

  /// the hub: keeps the members and passes the messages on
  void _serve(dynamic message) {
    List<Object?> m = message as List<Object?>;
    int from = m[1] as int;
    switch (m[0]) {
      case 'join':
        _members[from] = m[2] as SendPort;
        _sendSize();
      case 'leave':
        drop(from);
      case 'send':
        // ponytail: every member gets every channel and drops the ones
        // it does not listen to. Filter in the hub if channels get busy.
        List<Object?> out = <Object?>['msg', m[2], m[3]];
        _members.forEach((int id, SendPort member) {
          if (id != from) member.send(out);
        });
    }
  }

  void _sendSize() {
    List<Object> out = <Object>['size', _members.length];
    for (SendPort member in _members.values) {
      member.send(out);
    }
  }

  void _onInbox(dynamic message) {
    List<Object?> m = message as List<Object?>;
    if (m[0] == 'size') {
      _size = m[1] as int;
    } else {
      _channels[m[1] as String]?.add(m[2]);
    }
  }
}

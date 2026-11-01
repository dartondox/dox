import 'dart:async';
import 'dart:isolate';

/// Rate limit counts shared by all isolates of the app.
///
/// The main isolate owns the counts. The other isolates send each
/// increment to it through a [SendPort] and wait for the new count.
/// `DoxIsolate` gives every isolate it starts the [port] of the main
/// isolate, and the isolate calls [connect] with it.
///
/// In the main isolate (and in an app with one isolate) the count is
/// made in place, with no message.
class RateLimitCounter {
  RateLimitCounter._();

  /// one per isolate
  static final RateLimitCounter instance = RateLimitCounter._();

  /// the most time to wait for the main isolate. After it, the count is
  /// made in this isolate, so a request never hangs (eg. during shutdown).
  static const Duration timeout = Duration(seconds: 5);

  /// key => count, only used in the isolate that owns the counts
  final Map<String, _Count> _counts = <String, _Count>{};
  int _nextSweep = 0;
  ReceivePort? _server;

  /// the owner of the counts, null in the owner itself
  SendPort? _owner;
  ReceivePort? _replies;
  int _nextId = 0;
  final Map<int, Completer<int>> _waiting = <int, Completer<int>>{};

  /// The port other isolates send their increments to. Opened on the
  /// first call, in the isolate that owns the counts (the main isolate).
  SendPort get port {
    ReceivePort server = _server ??= ReceivePort()..listen(_serve);
    return server.sendPort;
  }

  /// count in the isolate that owns [owner] (a [port]) from now on.
  /// null counts in this isolate.
  void connect(SendPort? owner) {
    _owner = owner;
  }

  /// Adds one to [key] and gives the new count. A new key, or a key
  /// older than [ttl], starts at 1.
  Future<int> increment(String key, Duration ttl) {
    int ttlMs = ttl.inMilliseconds;
    SendPort? owner = _owner;
    if (owner == null) return Future<int>.value(_increment(key, ttlMs));

    ReceivePort replies = _replies ??= ReceivePort()..listen(_onReply);
    int id = _nextId++;
    Completer<int> done = Completer<int>();
    _waiting[id] = done;
    owner.send(<Object>[replies.sendPort, id, key, ttlMs]);
    return done.future.timeout(
      timeout,
      onTimeout: () {
        _waiting.remove(id);
        return _increment(key, ttlMs);
      },
    );
  }

  /// close the ports and forget all counts
  void close() {
    _server?.close();
    _server = null;
    _replies?.close();
    _replies = null;
    _owner = null;
    _waiting.clear();
    _counts.clear();
    _nextSweep = 0;
  }

  void _serve(dynamic message) {
    List<Object?> m = message as List<Object?>;
    SendPort reply = m[0] as SendPort;
    int count = _increment(m[2] as String, m[3] as int);
    reply.send(<int>[m[1] as int, count]);
  }

  void _onReply(dynamic message) {
    List<int> m = message as List<int>;
    _waiting.remove(m[0])?.complete(m[1]);
  }

  int _increment(String key, int ttlMs) {
    int now = DateTime.now().millisecondsSinceEpoch;
    // drop old keys at most once a second, so the map does not grow
    if (now >= _nextSweep) {
      _counts.removeWhere((String _, _Count c) => c.expiresAt <= now);
      _nextSweep = now + 1000;
    }
    _Count? count = _counts[key];
    if (count == null || count.expiresAt <= now) {
      count = _Count(now + ttlMs);
      _counts[key] = count;
    }
    return ++count.hits;
  }
}

class _Count {
  _Count(this.expiresAt);

  final int expiresAt;
  int hits = 0;
}

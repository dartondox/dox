import 'dart:async';
import 'dart:convert';

import '../constants/engine_constants.dart';
import 'engine_packet.dart';
import 'engine_request.dart';
import 'polling_transport.dart';
import 'server_options.dart';
import 'transport.dart';
import 'websocket_transport.dart';

/// Gets events from an [EngineSocket]. The Socket.IO client implements it.
abstract class EngineSocketListener {
  /// A message came in. [data] is a [String] or a binary list.
  void onEngineMessage(Object data);

  /// The session is closed.
  void onEngineClose(String reason);
}

/// Gets told when a session is closed. The Engine.IO server implements it.
abstract class EngineSessionStore {
  /// Forgets the session with [id].
  void removeSession(String id);
}

enum _ReadyState { opening, open, closing, closed }

/// One Engine.IO session (one client connection).
///
/// It owns the transport, the heartbeat and the upgrade to websocket.
class EngineSocket implements TransportListener {
  EngineSocket({
    required this.id,
    required this.request,
    required Transport transport,
    required ServerOptions options,
    required EngineSessionStore store,
  })  : _transport = transport,
        _options = options,
        _store = store {
    transport.listener = this;
  }

  /// Session id (`sid`).
  final String id;

  /// The request that opened the session.
  final EngineRequest request;

  final ServerOptions _options;
  final EngineSessionStore _store;

  Transport _transport;
  WebsocketTransport? _probe;
  _ReadyState _state = _ReadyState.opening;
  final List<EnginePacket> _writeBuffer = <EnginePacket>[];
  bool _closeAfterFlush = false;
  String _closeReason = CloseReason.forcedClose;

  Timer? _pingTimer;
  Timer? _pingTimeoutTimer;
  Timer? _upgradeTimeoutTimer;
  Timer? _upgradeCheckTimer;

  /// Gets messages and the close event.
  EngineSocketListener? listener;

  /// Current transport.
  Transport get transport => _transport;

  /// True while a websocket upgrade is going on.
  bool get upgrading => _probe != null;

  /// True when the session is open.
  bool get isOpen => _state == _ReadyState.open;

  /// Sends the open packet and starts the heartbeat.
  void open() {
    _state = _ReadyState.open;
    bool canUpgrade = _options.allowUpgrades &&
        _transport is PollingTransport &&
        _options.transports.contains(transportWebsocket);
    String handshake = jsonEncode(<String, Object>{
      'sid': id,
      'upgrades': canUpgrade ? <String>[transportWebsocket] : <String>[],
      'pingInterval': _options.pingInterval.inMilliseconds,
      'pingTimeout': _options.pingTimeout.inMilliseconds,
      'maxPayload': _options.maxHttpBufferSize,
    });
    _sendPacket(EnginePacket(EnginePacketType.open, handshake));
    _schedulePing();
  }

  /// Sends a message. [data] is a [String] or a [Uint8List].
  void send(Object data) {
    _sendPacket(EnginePacket(EnginePacketType.message, data));
  }

  /// Closes the session after the buffered packets are sent.
  void close([String reason = CloseReason.forcedClose]) {
    if (_state != _ReadyState.open) return;
    _state = _ReadyState.closing;
    _closeReason = reason;
    if (_writeBuffer.isEmpty) {
      _onClose(reason);
      return;
    }
    _closeAfterFlush = true;
    _flush();
  }

  /// Starts an upgrade to [websocket]. The client sends probe packets next.
  void maybeUpgrade(WebsocketTransport websocket) {
    if (upgrading || _transport is! PollingTransport || !isOpen) {
      websocket.close();
      return;
    }
    _probe = websocket;
    websocket.listener = this;
    _upgradeTimeoutTimer = Timer(_options.upgradeTimeout, _cancelUpgrade);
  }

  @override
  void onTransportPacket(Transport transport, EnginePacket packet) {
    if (transport != _transport) {
      _onProbePacket(transport, packet);
      return;
    }
    switch (packet.type) {
      case EnginePacketType.pong:
        _pingTimeoutTimer?.cancel();
        _schedulePing();
      case EnginePacketType.message:
        Object? data = packet.data;
        if (data != null) listener?.onEngineMessage(data);
      case EnginePacketType.close:
        _onClose(CloseReason.transportClose);
      case EnginePacketType.open:
      case EnginePacketType.ping:
      case EnginePacketType.upgrade:
      case EnginePacketType.noop:
        break;
    }
  }

  @override
  void onTransportWritable(Transport transport) {
    if (transport == _transport) _flush();
  }

  @override
  void onTransportClose(Transport transport, String reason) {
    if (transport == _transport) {
      _onClose(reason);
    } else if (transport == _probe) {
      _cancelUpgrade();
    }
  }

  void _onProbePacket(Transport probe, EnginePacket packet) {
    if (probe != _probe) return;
    if (packet.type == EnginePacketType.ping && packet.data == probeData) {
      probe.send(const <EnginePacket>[
        EnginePacket(EnginePacketType.pong, probeData),
      ]);
      _upgradeCheckTimer?.cancel();
      _upgradeCheckTimer = Timer.periodic(upgradeCheckInterval, _releasePoll);
    } else if (packet.type == EnginePacketType.upgrade && isOpen) {
      _finishUpgrade(probe);
    } else {
      _cancelUpgrade();
    }
  }

  /// Answers a waiting poll with a noop, so the client can pause polling.
  void _releasePoll(Timer _) {
    if (_transport.writable && _writeBuffer.isEmpty) {
      _transport.send(const <EnginePacket>[
        EnginePacket(EnginePacketType.noop),
      ]);
    }
  }

  void _finishUpgrade(Transport websocket) {
    _clearUpgradeTimers();
    Transport old = _transport;
    _probe = null;
    _transport = websocket;
    old.listener = null;
    if (old is PollingTransport) {
      old.discard();
    } else {
      old.close();
    }
    _flush();
  }

  void _cancelUpgrade() {
    _clearUpgradeTimers();
    WebsocketTransport? probe = _probe;
    _probe = null;
    probe?.listener = null;
    probe?.close();
  }

  void _clearUpgradeTimers() {
    _upgradeTimeoutTimer?.cancel();
    _upgradeCheckTimer?.cancel();
    _upgradeTimeoutTimer = null;
    _upgradeCheckTimer = null;
  }

  void _schedulePing() {
    _pingTimer?.cancel();
    _pingTimer = Timer(_options.pingInterval, _sendPing);
  }

  void _sendPing() {
    _sendPacket(const EnginePacket(EnginePacketType.ping));
    _pingTimeoutTimer?.cancel();
    _pingTimeoutTimer = Timer(_options.pingTimeout, _onPingTimeout);
  }

  void _onPingTimeout() => _onClose(CloseReason.pingTimeout);

  void _sendPacket(EnginePacket packet) {
    if (_state == _ReadyState.closing || _state == _ReadyState.closed) return;
    _writeBuffer.add(packet);
    _flush();
  }

  void _flush() {
    if (_state == _ReadyState.closed || _writeBuffer.isEmpty) return;
    if (!_transport.writable) return;
    List<EnginePacket> packets = List<EnginePacket>.of(_writeBuffer);
    _writeBuffer.clear();
    _transport.send(packets);
    if (_closeAfterFlush) _onClose(_closeReason);
  }

  void _onClose(String reason) {
    if (_state == _ReadyState.closed) return;
    _state = _ReadyState.closed;
    _pingTimer?.cancel();
    _pingTimeoutTimer?.cancel();
    _cancelUpgrade();
    _transport.listener = null;
    _transport.close();
    _writeBuffer.clear();
    _store.removeSession(id);
    EngineSocketListener? current = listener;
    listener = null;
    current?.onEngineClose(reason);
  }
}

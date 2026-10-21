import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../constants/engine_constants.dart';
import 'engine_packet.dart';
import 'http_responder.dart';
import 'transport.dart';

/// HTTP long-polling transport.
///
/// A GET request waits until the server has packets to send.
/// A POST request carries packets from the client.
class PollingTransport extends Transport {
  PollingTransport({
    required this.maxHttpBufferSize,
    this._parser = const EngineParser(),
    this._responder = const HttpResponder(),
  });

  final int maxHttpBufferSize;
  final EngineParser _parser;
  final HttpResponder _responder;

  HttpRequest? _poll;
  bool _readingData = false;
  bool _closed = false;

  @override
  String get name => transportPolling;

  @override
  bool get writable => _poll != null && !_closed;

  /// Handles one GET (poll) or POST (data) request.
  Future<void> handleRequest(HttpRequest request) async {
    if (request.method == 'GET') {
      _onPoll(request);
    } else if (request.method == 'POST') {
      await _onData(request);
    } else {
      _responder.error(request.response, EngineError.badRequest);
    }
  }

  void _onPoll(HttpRequest request) {
    if (_closed) {
      _responder.send(request.response, HttpStatus.ok, _closePayload());
      return;
    }
    if (_poll != null) {
      // Two GET requests at the same time is a client bug. Close the session.
      _responder.error(request.response, EngineError.badRequest);
      listener?.onTransportClose(this, CloseReason.transportError);
      return;
    }
    _poll = request;
    listener?.onTransportWritable(this);
  }

  Future<void> _onData(HttpRequest request) async {
    if (_readingData) {
      _responder.error(request.response, EngineError.badRequest);
      listener?.onTransportClose(this, CloseReason.transportError);
      return;
    }
    _readingData = true;
    Uint8List? body = await _readBody(request);
    _readingData = false;
    if (body == null) {
      _responder.send(request.response, HttpStatus.requestEntityTooLarge, '');
      listener?.onTransportClose(this, CloseReason.transportError);
      return;
    }
    List<EnginePacket> packets;
    try {
      packets = _parser.decodePayload(utf8.decode(body));
    } on FormatException {
      _responder.error(request.response, EngineError.badRequest);
      listener?.onTransportClose(this, CloseReason.parseError);
      return;
    }
    _responder.send(
      request.response,
      HttpStatus.ok,
      'ok',
      contentType: 'text/html',
    );
    for (EnginePacket packet in packets) {
      if (_closed) break;
      listener?.onTransportPacket(this, packet);
    }
  }

  /// Reads the body. Returns null when it is bigger than the limit.
  Future<Uint8List?> _readBody(HttpRequest request) async {
    BytesBuilder builder = BytesBuilder(copy: false);
    await for (List<int> chunk in request) {
      builder.add(chunk);
      if (builder.length > maxHttpBufferSize) return null;
    }
    return builder.takeBytes();
  }

  @override
  void send(List<EnginePacket> packets) {
    HttpRequest? poll = _poll;
    if (poll == null) return;
    _poll = null;
    _responder.send(
      poll.response,
      HttpStatus.ok,
      _parser.encodePayload(packets),
    );
  }

  /// Stops this transport after an upgrade. A waiting poll gets a noop.
  void discard() {
    if (_poll != null) {
      send(const <EnginePacket>[EnginePacket(EnginePacketType.noop)]);
    }
    _closed = true;
  }

  @override
  void close() {
    if (_closed) return;
    if (_poll != null) {
      send(const <EnginePacket>[EnginePacket(EnginePacketType.close)]);
    }
    _closed = true;
  }

  String _closePayload() {
    return _parser.encodePayload(const <EnginePacket>[
      EnginePacket(EnginePacketType.close),
    ]);
  }
}

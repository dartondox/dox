import 'dart:async';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/json.dart';

class LogMiddleware implements IDoxMiddleware {
  Map<String, dynamic> Function(Map<String, dynamic>)? filter;

  final bool withHeader;
  final bool enabled;

  LogMiddleware({
    required this.enabled,
    this.filter,
    this.withHeader = false,
  });

  @override
  IDoxRequest handle(IDoxRequest req) {
    if (!enabled) {
      return req;
    }
    Map<String, dynamic> payload = <String, dynamic>{
      'request': req.toJson(),
    };

    if (withHeader) {
      payload['headers'] = req.headers;
    }

    Map<String, dynamic> text = <String, dynamic>{
      'level': 'INFO',
      'message': '${req.method} ${req.uri.path}',
      'source_ip': req.ip(),
      'timestamp': DateTime.now().toIso8601String(),
      'payload': payload
    };
    if (filter != null) {
      text = filter!(text);
    }
    _LogBuffer.write(JSON.stringify(text));
    return req;
  }
}

/// collects log lines and writes them in one go every few ms.
/// one big write is much cheaper than one blocking write per request.
class _LogBuffer {
  static final StringBuffer _buffer = StringBuffer();
  static Timer? _timer;

  static void write(String line) {
    _buffer.writeln(line);
    if (_buffer.length > 64 * 1024) {
      flush();
    } else {
      _timer ??= Timer(const Duration(milliseconds: 20), flush);
    }
  }

  static void flush() {
    _timer?.cancel();
    _timer = null;
    if (_buffer.isEmpty) return;
    stdout.write(_buffer.toString());
    _buffer.clear();
  }
}

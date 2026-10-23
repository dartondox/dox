import 'dart:async';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/json.dart';

class LogMiddleware implements IDoxMiddleware {
  Map<String, dynamic> Function(Map<String, dynamic>)? filter;

  final bool withHeader;
  final bool enabled;

  /// a body field or header whose name (lowercase) contains one of these
  /// is logged as `[REDACTED]`, so passwords and tokens stay out of logs.
  final List<String> redact;

  static const List<String> defaultRedact = <String>[
    'password',
    'passwd',
    'secret',
    'token',
    'authorization',
    'cookie',
    'api_key',
    'apikey',
  ];

  LogMiddleware({
    required this.enabled,
    this.filter,
    this.withHeader = false,
    this.redact = defaultRedact,
  });

  @override
  IDoxRequest handle(IDoxRequest req) {
    if (!enabled) {
      return req;
    }
    Map<String, dynamic> payload = <String, dynamic>{
      'request': _redact(req.toJson()),
    };

    if (withHeader) {
      payload['headers'] = _redact(req.headers);
    }

    Map<String, dynamic> text = <String, dynamic>{
      'level': 'INFO',
      'message': '${req.method} ${req.uri.path}',
      'source_ip': req.ip(),
      'timestamp': DateTime.now().toIso8601String(),
      'payload': payload,
    };
    if (filter != null) {
      text = filter!(text);
    }
    _LogBuffer.write(JSON.stringify(text));
    return req;
  }

  /// a copy of [value] with the values of secret keys replaced
  dynamic _redact(dynamic value) {
    if (value is Map) {
      return <String, dynamic>{
        for (MapEntry<dynamic, dynamic> e in value.entries)
          '${e.key}': _isSecret('${e.key}') ? '[REDACTED]' : _redact(e.value),
      };
    }
    if (value is List) return value.map(_redact).toList();
    return value;
  }

  bool _isSecret(String key) {
    String name = key.toLowerCase();
    for (String word in redact) {
      if (name.contains(word)) return true;
    }
    return false;
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

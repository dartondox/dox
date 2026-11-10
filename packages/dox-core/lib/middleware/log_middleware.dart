import 'package:dox_core/dox_core.dart';

class LogMiddleware implements IDoxMiddleware {
  Map<String, dynamic> Function(Map<String, dynamic>)? filter;

  final bool withHeader;

  /// `false` turns the request logs off. Not set: follow the logger config
  /// (`LoggerConfig.enabled` and `level`). The logger config always wins.
  final bool? enabled;

  /// a body field or header whose name contains one of these (any case)
  /// is logged as `[REDACTED]`, so passwords and tokens stay out of logs.
  final List<String> redact;

  /// [redact] in lower case, made once
  late final List<String> _redactLower = <String>[
    for (String word in redact) word.toLowerCase(),
  ];

  static const List<String> defaultRedact = <String>[
    'password',
    'passwd',
    'secret',
    'token',
    'authorization',
    'cookie',
    'api_key',
    'api-key',
    'apikey',
  ];

  LogMiddleware({
    this.enabled,
    this.filter,
    this.withHeader = false,
    this.redact = defaultRedact,
  });

  @override
  IDoxRequest handle(IDoxRequest req) {
    if (enabled == false) {
      return req;
    }
    Map<String, dynamic> payload = <String, dynamic>{
      'request': _redact(req.toJson()),
    };

    if (withHeader) {
      payload['headers'] = _redact(req.headers);
    }

    String? requestId = req is DoxRequest ? req.requestId : null;
    Map<String, dynamic> text = <String, dynamic>{
      'status': 'info',
      'message': '${req.method} ${req.uri.path}',
      'network': <String, dynamic>{
        'client': <String, dynamic>{'ip': req.ip()},
      },
      'http': <String, dynamic>{
        'method': req.method,
        'url': req.uri.path,
        'request_id': ?requestId,
      },
      'payload': payload,
    };
    if (filter != null) {
      text = filter!(text);
    }
    // the logger config decides if the line is written, and how
    String status = '${text.remove('status') ?? 'info'}';
    String message = '${text.remove('message') ?? ''}';
    Logger.log(status, message, text);
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
    for (String word in _redactLower) {
      if (name.contains(word)) return true;
    }
    return false;
  }
}

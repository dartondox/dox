import 'dart:convert';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/logger.dart';

class LogMiddleware extends DoxMiddleware {
  Function(Map<String, dynamic>)? filter;

  final bool withHeader;

  LogMiddleware({this.filter, this.withHeader = false});

  @override
  DoxRequest handle(DoxRequest req) {
    Map<String, dynamic> text = <String, dynamic>{
      'level': 'INFO',
      'message': '${req.method} ${req.uri.path}',
      'source_ip': req.ip(),
      'timestamp': DateTime.now().toIso8601String(),
      'payload': <String, dynamic>{
        'request': req.all(),
        'headers': withHeader ? req.headers : null,
      }
    };
    if (filter != null) {
      text = filter!(text);
    }
    DoxLogger.log(jsonEncode(text));
    return req;
  }
}

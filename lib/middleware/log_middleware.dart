import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/logger.dart';

class LogMiddleware extends DoxMiddleware {
  Function(Map<String, dynamic>)? filter;

  final bool withHeader;

  LogMiddleware({this.filter, this.withHeader = false});

  @override
  handle(DoxRequest req) {
    var text = {
      'level': 'INFO',
      'message': "${req.method} ${req.uri.path}",
      'source_ip': req.ip(),
      'timestamp': DateTime.now().toIso8601String(),
      'payload': {
        'request': req.all(),
        'headers': withHeader ? req.headers : null,
      }
    };
    if (filter != null) {
      text = filter!(text);
    }
    DoxLogger.log(text);
    return req;
  }
}

/// coverage:ignore-file
library;

import 'package:dox_core/app.dart';
import 'package:dox_core/interfaces/app_config.dart';
import 'package:dox_core/utils/json.dart';

class Logger {
  /// rank of each level. a line prints when its rank is at least
  /// the rank of `LoggerConfig.level`.
  static const Map<String, int> _ranks = <String, int>{
    'debug': 0,
    'info': 1,
    'success': 1,
    'warn': 2,
    'warning': 2,
    'danger': 3,
    'error': 3,
  };

  /// true when a line of [level] passes the [minLevel] setting.
  /// an unknown [minLevel] prints every line, so no log is lost.
  static bool shouldLog(String level, String minLevel) {
    int min = _ranks[minLevel.toLowerCase()] ?? 0;
    return (_ranks[level] ?? 3) >= min;
  }

  static void log(String level, dynamic message, [dynamic data]) {
    LoggerConfig config = Dox().config.logger;
    if (!config.enabled || !shouldLog(level, config.level)) return;
    Dox().config.logger.prettyPrint
        ? _prettyLog(level, message, data)
        : _log(level, message, data);
  }

  /// log the text using info color (lightblue)
  /// ```
  /// Logger.info('using dox is fun');
  /// ```
  static void info(dynamic message, [dynamic data]) {
    log('info', message, data);
  }

  /// log the text using warn color (yellow)
  /// ```
  /// Logger.warn('careful!');
  ///
  static void warn(dynamic message, [dynamic data]) {
    log('warn', message, data);
  }

  /// log the text using success color (green)
  /// ```
  /// Logger.success('success');
  ///
  static void success(dynamic message, [dynamic data]) {
    log('success', message, data);
  }

  /// log the text using danger color (red)
  /// ```
  /// Logger.danger('failed');
  ///
  static void danger(dynamic message, [dynamic data]) {
    log('danger', message, data);
  }

  /// log as json string
  /// this function is use for logging services
  /// eg. datadog, sentry etc..
  static void _prettyLog(String level, dynamic message, dynamic data) {
    String? payload = '';
    if (data == null || data is String) {
      payload = data;
    } else if (data is DateTime) {
      payload = data.toIso8601String();
    } else {
      payload = JSON.stringify(data);
    }
    Map<String, String> colors = <String, String>{
      'info': '36',
      'warn': '33',
      'success': '32',
      'danger': '31',
    };
    String? color = colors[level];
    if (payload == null || payload.isEmpty) {
      print('\x1B[${color}m$message\x1B[0m');
      return;
    }
    print('\x1B[${color}m$message => $payload\x1B[0m');
  }

  /// log as json string
  /// this function is use for logging services
  /// eg. datadog, sentry etc..
  static void _log(String level, dynamic message, dynamic data) {
    Map<String, dynamic> text = <String, dynamic>{
      'level': level.toUpperCase(),
      'name': Dox().config.logger.name,
      'message': message.toString(),
      'timestamp': DateTime.now().toIso8601String(),
      'payload': data,
    };
    print(JSON.stringify(text));
  }
}

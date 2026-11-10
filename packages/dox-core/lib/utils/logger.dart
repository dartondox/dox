/// coverage:ignore-file
library;

import 'package:dox_core/app.dart';
import 'package:dox_core/interfaces/app_config.dart';
import 'package:dox_core/utils/json.dart';
import 'package:dox_core/utils/log_buffer.dart';

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
    String line = config.prettyPrint
        ? _prettyLog(level, message, data)
        : _log(config, level, message, data);
    // a warning or an error is written at once, it must not be lost
    LogBuffer.write(line, now: (_ranks[level] ?? 3) >= 2);
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

  /// the colored text line
  static String _prettyLog(String level, dynamic message, dynamic data) {
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
      return '\x1B[${color}m$message\x1B[0m';
    }
    return '\x1B[${color}m$message => $payload\x1B[0m';
  }

  /// one JSON line, with the standard attributes of log services
  /// (eg. datadog). A Map in [data] is merged into the top level.
  /// Any other value goes under `payload`.
  static String _log(
    LoggerConfig config,
    String level,
    dynamic message,
    dynamic data,
  ) {
    Map<String, dynamic> text = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'status': level,
      'message': message.toString(),
      if (config.name.isNotEmpty)
        'logger': <String, dynamic>{'name': config.name},
    };
    if (data is Map) {
      for (MapEntry<dynamic, dynamic> e in data.entries) {
        text['${e.key}'] = e.value;
      }
    } else if (data != null) {
      text['payload'] = data;
    }
    return JSON.stringify(text);
  }
}

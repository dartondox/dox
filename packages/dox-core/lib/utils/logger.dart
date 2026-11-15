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
    return (_ranks[level.toLowerCase()] ?? 3) >= min;
  }

  /// [tag] names where the line comes from, like `request` or `server`.
  /// No tag gives `app`. It is the third positional argument, because
  /// Dart does not allow a named argument next to the optional [data].
  /// ```
  /// Logger.info('done', null, 'billing');
  /// ```
  static void log(String level, dynamic message, [dynamic data, String? tag]) {
    tag ??= 'app';
    // `INFO` from a filter ranks as `info`
    level = level.toLowerCase();
    LoggerConfig config = Dox().config.logger;
    if (!config.enabled || !shouldLog(level, config.level)) return;
    String line;
    try {
      line = _build(config, level, message, data, tag);
    } catch (_) {
      // data that can not become JSON must not break the caller (eg. a
      // request). Log its text instead.
      try {
        line = _build(config, level, message, data?.toString(), tag);
      } catch (_) {
        return;
      }
    }
    // a warning or an error is written at once, it must not be lost
    LogBuffer.write(line, now: (_ranks[level] ?? 3) >= 2);
  }

  /// log the text using info color (lightblue)
  /// ```
  /// Logger.info('using dox is fun');
  /// ```
  static void info(dynamic message, [dynamic data, String? tag]) {
    log('info', message, data, tag);
  }

  /// log the text using warn color (yellow)
  /// ```
  /// Logger.warn('careful!');
  ///
  static void warn(dynamic message, [dynamic data, String? tag]) {
    log('warn', message, data, tag);
  }

  /// log the text using success color (green)
  /// ```
  /// Logger.success('success');
  ///
  static void success(dynamic message, [dynamic data, String? tag]) {
    log('success', message, data, tag);
  }

  /// log the text using danger color (red)
  /// ```
  /// Logger.danger('failed');
  ///
  static void danger(dynamic message, [dynamic data, String? tag]) {
    log('danger', message, data, tag);
  }

  static String _build(
    LoggerConfig config,
    String level,
    dynamic message,
    dynamic data,
    String tag,
  ) {
    return config.prettyPrint
        ? _prettyLog(level, message, data, tag)
        : _log(config, level, message, data, tag);
  }

  /// the colored text line, after a dim `[tag]`
  static String _prettyLog(
    String level,
    dynamic message,
    dynamic data,
    String tag,
  ) {
    String? payload = '';
    if (data == null || data is String) {
      payload = data;
    } else if (data is DateTime) {
      payload = data.toIso8601String();
    } else {
      payload = JSON.stringify(data);
    }
    Map<String, String> colors = <String, String>{
      'debug': '90',
      'info': '36',
      'warn': '33',
      'warning': '33',
      'success': '32',
      'danger': '31',
      'error': '31',
    };
    // an unknown level gets the default color
    String color = colors[level] ?? '0';
    String prefix = '\x1B[2m[$tag]\x1B[0m ';
    if (payload == null || payload.isEmpty) {
      return '$prefix\x1B[${color}m$message\x1B[0m';
    }
    return '$prefix\x1B[${color}m$message => $payload\x1B[0m';
  }

  /// one JSON line, with the standard attributes of log services
  /// (eg. datadog). A Map in [data] is merged into the top level.
  /// Any other value goes under `payload`.
  static String _log(
    LoggerConfig config,
    String level,
    dynamic message,
    dynamic data,
    String tag,
  ) {
    Map<String, dynamic> text = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'status': level,
      'source': tag,
      'message': message.toString(),
      if (config.name.isNotEmpty)
        'logger': <String, dynamic>{'name': config.name},
    };
    if (data is Map) {
      for (MapEntry<dynamic, dynamic> e in data.entries) {
        // the standard fields stay: a key with the same name is dropped
        String key = e.key is String ? e.key : '${e.key}';
        // `logger` is always ours: it is left out when the name is empty
        if (key == 'logger') continue;
        text.putIfAbsent(key, () => e.value);
      }
    } else if (data != null) {
      text['payload'] = data;
    }
    return JSON.stringify(text);
  }
}

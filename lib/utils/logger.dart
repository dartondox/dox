/// coverage:ignore-file
import 'package:dox_core/utils/json.dart';

class DoxLogger {
  /// log the text with white color
  static void log(dynamic text) {
    print(text);
  }

  /// log the text using info color (lightblue)
  /// ```
  /// DoxLogger.info('using dox is fun');
  /// ```
  static void info(dynamic text) {
    print('\x1B[36m$text\x1B[0m');
  }

  /// log the text using warn color (yellow)
  /// ```
  /// DoxLogger.warn('careful!');
  ///
  static void warn(dynamic text) {
    print('\x1B[33m$text\x1B[0m');
  }

  /// log the text using success color (green)
  /// ```
  /// DoxLogger.success('success');
  ///
  static void success(dynamic text) {
    print('\x1B[32m$text\x1B[0m');
  }

  /// log the text using danger color (red)
  /// ```
  /// DoxLogger.danger('failed');
  ///
  static void danger(dynamic text) {
    print('\x1B[31m$text\x1B[0m');
  }

  /// log as json string
  /// this function is user for logging services
  /// eg. datadog, sentry etc..
  static void prettyLog(String level, String message, [dynamic data]) {
    Map<String, dynamic> text = <String, dynamic>{
      'level': level.toUpperCase(),
      'message': message.toString(),
      'timestamp': DateTime.now().toIso8601String(),
      'payload': data
    };
    DoxLogger.log(JSON.stringify(text));
  }
}

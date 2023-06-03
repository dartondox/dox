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
    print("\x1B[36m$text\x1B[0m");
  }

  /// log the text using warn color (yellow)
  /// ```
  /// DoxLogger.info('careful!');
  ///
  static void warn(dynamic text) {
    print("\x1B[34m$text\x1B[0m");
  }

  /// log the text using success color (green)
  /// ```
  /// DoxLogger.info('success');
  ///
  static void success(dynamic text) {
    print("\x1B[32m$text\x1B[0m");
  }

  /// log the text using danger color (red)
  /// ```
  /// DoxLogger.danger('failed');
  ///
  static void danger(dynamic text) {
    print("\x1B[31m$text\x1B[0m");
  }
}

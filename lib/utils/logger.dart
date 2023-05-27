class DoxLogger {
  /// log the text with white color
  static log(text) {
    print(text);
  }

  /// log the text using info color (lightblue)
  /// ```
  /// DoxLogger.info('using dox is fun');
  /// ```
  static info(text) {
    print("\x1B[36m$text\x1B[0m");
  }

  /// log the text using warn color (yellow)
  /// ```
  /// DoxLogger.info('careful!');
  ///
  static warn(text) {
    print("\x1B[34m$text\x1B[0m");
  }

  /// log the text using success color (green)
  /// ```
  /// DoxLogger.info('success');
  ///
  static success(text) {
    print("\x1B[32m$text\x1B[0m");
  }

  /// log the text using danger color (red)
  /// ```
  /// DoxLogger.danger('failed');
  ///
  static danger(text) {
    print("\x1B[31m$text\x1B[0m");
  }
}

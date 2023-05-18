class DoxLogger {
  static log(text) {
    print(text);
  }

  static info(text) {
    print("\x1B[36m$text\x1B[0m");
  }

  static warn(text) {
    print("\x1B[34m$text\x1B[0m");
  }

  static success(text) {
    print("\x1B[32m$text\x1B[0m");
  }

  static danger(text) {
    print("\x1B[31m$text\x1B[0m");
  }
}

class DoxMultiThread {
  /// singleton
  static final DoxMultiThread _singleton = DoxMultiThread._internal();
  factory DoxMultiThread() => _singleton;
  DoxMultiThread._internal();

  int totalThread = 1;

  void increase() {
    totalThread = totalThread + 1;
  }

  void decrease() {
    totalThread = totalThread - 1;
  }
}

import 'dart:async';
import 'dart:io';

/// Internal. Collects log lines and writes them in one go every few ms.
/// One big write is much cheaper than one blocking write per line.
/// Used by `Logger`. Not part of the public API.
class LogBuffer {
  static final StringBuffer _buffer = StringBuffer();
  static Timer? _timer;

  /// where the text goes. Tests change it.
  static void Function(String) writer = _stdoutWrite;

  static bool _guarded = false;

  static void _stdoutWrite(String text) {
    if (!_guarded) {
      _guarded = true;
      // a broken pipe (EPIPE) is reported later through this future.
      // Without a handler it would crash the isolate.
      stdout.done.catchError((Object _) {});
    }
    stdout.write(text);
  }

  /// Add [line]. With [now] true, write everything at once.
  /// Lines that came before go first, so the order stays.
  static void write(String line, {bool now = false}) {
    _buffer.writeln(line);
    if (now || _buffer.length > 64 * 1024) {
      flush();
    } else {
      _timer ??= Timer(const Duration(milliseconds: 20), flush);
    }
  }

  static void flush() {
    _timer?.cancel();
    _timer = null;
    if (_buffer.isEmpty) return;
    String text = _buffer.toString();
    _buffer.clear();
    try {
      writer(text);
    } catch (_) {
      // a failed write (eg. closed stdout) must not crash the app.
      // try stderr once, so the lines are not lost without a trace.
      // We can not know how much of the text the writer wrote before it
      // threw, so a few lines can appear twice. This is on purpose: a
      // double line is better than a lost line.
      try {
        stderr.write(text);
      } catch (_) {}
    }
  }
}

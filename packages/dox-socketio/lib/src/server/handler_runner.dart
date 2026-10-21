import 'dart:async';
import 'dart:io';

/// Runs user handlers and reports their errors without crashing the server.
class HandlerRunner {
  const HandlerRunner();

  /// Runs [handler] with [argument]. Errors are written to stderr.
  Future<void> run<T>(FutureOr<void> Function(T) handler, T argument) async {
    try {
      await handler(argument);
    } catch (error, stack) {
      stderr.writeln('dox_socketio: handler error: $error\n$stack');
    }
  }
}

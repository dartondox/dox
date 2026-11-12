import 'dart:async';

import 'package:dox_core/dox_core.dart';

/// A middleware that runs code after the answer is sent to the client.
/// Good for work the client should not wait for: logs, metrics, cleanup.
///
/// [terminate] gets the request and the answer that was sent.
/// `res.status` is the status that was sent. An error in [terminate] is
/// sent to `ExceptionHandler.report`. It never changes the answer.
///
/// A class can also implement `IDoxMiddleware` or `IDoxNextMiddleware`,
/// to run code before the controller too.
/// ```
/// class Metrics implements IDoxMiddleware, IDoxTerminableMiddleware {
///   @override
///   dynamic handle(IDoxRequest req) => req;
///
///   @override
///   void terminate(DoxRequest req, DoxResponse res) {
///     print('${req.method} ${req.uri.path} ${res.status}');
///   }
/// }
/// ```
abstract class IDoxTerminableMiddleware {
  FutureOr<void> terminate(DoxRequest req, DoxResponse res);
}

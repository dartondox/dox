import 'dart:async';

import 'package:dox_core/dox_core.dart';

/// Runs the rest of the middleware and the controller. It gives the
/// response. An error on the way is already turned into its error
/// response by the `ExceptionHandler`.
typedef Next = Future<DoxResponse> Function();

/// A function middleware that runs code before and after the controller.
/// ```
/// Future<DoxResponse> timer(DoxRequest req, Next next) async {
///   Stopwatch watch = Stopwatch()..start();
///   DoxResponse res = await next();
///   return res.header('X-Time', '${watch.elapsedMilliseconds}ms');
/// }
/// ```
typedef NextMiddlewareFunction = FutureOr<dynamic> Function(
  DoxRequest req,
  Next next,
);

/// A class middleware that runs code before and after the controller.
///
/// Call [Next] to run the rest of the middleware and the controller.
/// Change the response it gives, then return it. Return something else
/// without calling [Next] to stop early.
/// ```
/// class SeeOther implements IDoxNextMiddleware {
///   @override
///   Future<DoxResponse> handle(DoxRequest req, Next next) async {
///     DoxResponse res = await next();
///     if (res.status == 302 && req.method != 'GET') res.statusCode(303);
///     return res;
///   }
/// }
/// ```
abstract class IDoxNextMiddleware {
  FutureOr<dynamic> handle(DoxRequest req, Next next);
}

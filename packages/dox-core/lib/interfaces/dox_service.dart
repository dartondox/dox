/// coverage:ignore-file
library;

import 'dart:async';

abstract class DoxService {
  dynamic setup() {}
}

/// Add this to a service that must clean up when the server stops, eg.
/// close database or Redis connections. It runs in every isolate, after
/// the open requests are done (on SIGTERM, SIGINT or `Dox().stop()`).
/// ```
/// class RedisService implements DoxService, DoxShutdown {
///   late RedisConnection redis;
///
///   @override
///   Future<void> setup() async {
///     redis = await RedisConnection.open();
///   }
///
///   @override
///   Future<void> shutdown() async {
///     await redis.close();
///   }
/// }
/// ```
abstract class DoxShutdown {
  FutureOr<void> shutdown();
}

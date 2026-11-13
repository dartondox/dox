/// coverage:ignore-file
library;

import 'dart:async';

/// A provider sets up a part of the app when it starts, eg. the database,
/// Redis or the auth guards. Dox finds every class that extends it (with
/// `dox_builder`) and runs it in every isolate.
/// ```
/// class RedisProvider extends DoxProvider {
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
abstract class DoxProvider {
  /// Runs once in every isolate when the app starts, before the routes
  /// are registered.
  FutureOr<void> setup();

  /// Runs once in every isolate when the server stops, eg. to close
  /// database or Redis connections. It runs after the open requests are
  /// done (on SIGTERM, SIGINT or `Dox().stop()`). Optional.
  FutureOr<void> shutdown() {}
}

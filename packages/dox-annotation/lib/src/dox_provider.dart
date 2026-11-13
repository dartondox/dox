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

  /// Runs once in every isolate after `setup()` of every provider is
  /// done, so the other providers are ready. Use it for work that needs
  /// them, eg. a background worker. Optional. The web server, the queue
  /// worker (`bin/queue.dart`) and the scheduler (`bin/schedule.dart`)
  /// call it. `Dox().writeOpenApi()` does not: it runs only `setup()`.
  /// The boots run one by one, in the provider order, and each is awaited.
  /// When one throws, the start fails with its error and the next ones do
  /// not run.
  FutureOr<void> boot() {}

  /// Runs once in every isolate when the server stops, eg. to close
  /// database or Redis connections. It runs after the open requests are
  /// done (on SIGTERM, SIGINT or `Dox().stop()`). Optional.
  FutureOr<void> shutdown() {}
}

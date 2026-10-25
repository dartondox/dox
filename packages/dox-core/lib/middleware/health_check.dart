import 'dart:async';
import 'dart:io';

import 'package:dox_core/dox_core.dart';

/// One health check. It fails when it throws, returns `false`, or takes
/// longer than the timeout.
typedef HealthCheckFunction = FutureOr<Object?> Function();

/// The controller of `Route.health()`. It runs the [checks] at the same
/// time and answers:
///
/// - 200 `{"status": "ok", "checks": {"database": "ok"}}` when all pass
/// - 503 `{"status": "fail", "checks": {"database": "fail"}}` when one fails
///
/// With no checks the answer is 200 `{"status": "ok"}`.
/// The error text of a failed check is in `errors` only when `APP_ENV` is
/// `development` or `local`, because it can hold hosts or passwords.
/// It is always given to `AppConfig.exceptionHandler.report()`.
///
/// ```
/// Route.health('/health', checks: <String, HealthCheckFunction>{
///   'database': () => QueryBuilder.query('select 1'),
///   'cache': HealthCheck.cache(),
/// });
/// ```
class HealthCheck {
  const HealthCheck({
    this.checks = const <String, HealthCheckFunction>{},
    this.timeout = const Duration(seconds: 5),
  });

  /// check name to check
  final Map<String, HealthCheckFunction> checks;

  /// a check that takes longer fails
  final Duration timeout;

  /// A check that writes a key to the cache and reads it back.
  /// [store] is a store name of `AppConfig.cache`, default store when null.
  static HealthCheckFunction cache([String? store]) {
    Future<bool> check() async {
      Cache cache = Cache();
      if (store != null) cache.store(store);
      String key = 'dox_health_check';
      await cache.put(key, 'ok', duration: const Duration(minutes: 1));
      return await cache.get(key) == 'ok';
    }

    return check;
  }

  /// The route controller.
  Future<DoxResponse> handle(DoxRequest req) async {
    if (checks.isEmpty) return response(<String, String>{'status': 'ok'});
    List<String> names = checks.keys.toList();
    List<Object?> errors = await Future.wait(<Future<Object?>>[
      for (String name in names) _run(checks[name]!),
    ]);
    Map<String, String> results = <String, String>{};
    Map<String, String> details = <String, String>{};
    for (int i = 0; i < names.length; i++) {
      Object? error = errors[i];
      results[names[i]] = error == null ? 'ok' : 'fail';
      if (error != null) details[names[i]] = '$error';
    }
    bool ok = details.isEmpty;
    return response(<String, dynamic>{
      'status': ok ? 'ok' : 'fail',
      'checks': results,
      if (!ok && _showErrors()) 'errors': details,
    }).statusCode(ok ? HttpStatus.ok : HttpStatus.serviceUnavailable);
  }

  /// null when [check] passed, else why it failed
  Future<Object?> _run(HealthCheckFunction check) async {
    try {
      Object? result = await Future<Object?>.sync(check).timeout(timeout);
      return result == false ? 'returned false' : null;
    } catch (error, stackTrace) {
      Dox().config.exceptionHandler.report(error, stackTrace);
      return error;
    }
  }

  static bool _showErrors() {
    String env = Env.get<String>('APP_ENV').toLowerCase();
    return env == 'development' || env == 'local';
  }
}

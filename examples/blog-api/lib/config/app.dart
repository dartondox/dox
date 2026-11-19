import 'package:blog/config/cache.dart';
import 'package:blog/config/cors.dart';
import 'package:blog/config/env.dart';
import 'package:blog/config/logger.dart';
import 'package:blog/generated/container.g.dart';
import 'package:blog/generated/dtos.g.dart';
import 'package:dox_core/dox_core.dart';

AppConfig appConfig = AppConfig(
  /// Application secret key
  /// -------------------------------
  /// This key is use to encrypt/decrypt the data such as cache and cookies.
  /// Make sure to keep the `APP_KEY` as an environment variable and secure.
  ///
  /// Note: Changing the application key for an existing app will make all
  /// the cookies and cache invalid and also the existing encrypted data
  /// will not be decrypted.
  appKey: env.appKey,

  /// Server port
  /// -------------------------------
  /// App will be running on this port.
  serverPort: env.appPort,

  /// Total isolate (multi thread)
  /// -------------------------------
  /// Isolates that serve http requests, all on the same port.
  /// Default is one per CPU the process may use.
  /// Set `APP_TOTAL_ISOLATE` to change it.
  totalIsolate: env.appTotalIsolate,

  /// Global middleware
  /// -------------------------------
  /// By registering global middleware here,
  /// middleware will be applied to all the routes.
  globalMiddleware: <dynamic>[
    /// one log line per request. off in production: the proxy logs there.
    LogMiddleware(enabled: env.appEnv != 'production'),
  ],

  /// Container
  /// -------------------------------
  /// Every @Inject class, router and provider of the app,
  /// from lib/generated/container.g.dart (made by build_runner).
  container: registerContainer,

  /// DTOs (generated list in lib/generated/dtos.g.dart)
  dtos: dtos,

  /// Strict mode
  /// -------------------------------
  /// Only in development. It warns in the log when a handler blocks the
  /// isolate, or when sync `Hash.make` / `Hash.verify` runs in the web server.
  /// Fix the warning. Do not turn strict mode off.
  strict: StrictConfig(enabled: env.appEnv == 'development'),

  /// Cache stores (config/cache.dart)
  cache: cache,

  /// Cors configuration
  cors: cors,

  /// logger configuration
  logger: logger,
);

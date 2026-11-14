import 'package:blog/config/env.dart';
import 'package:dox_core/dox_core.dart';

LoggerConfig logger = LoggerConfig(
  /// Application name
  /// -------------------------------
  /// The name of the application you want to add to the log.
  name: env.appName,

  /// Toggle logger
  /// -------------------------------
  /// Enable or disable logger in application.
  enabled: true,

  /// Logging level
  /// -------------------------------
  /// The level from which you want the logger to flush logs.
  level: env.logLevel,

  /// Pretty print
  /// -------------------------------
  /// It is highly advised NOT to use `prettyPrint` in production, since it
  /// can have huge impact on performance.
  // not appConfig.isDevelopment: appConfig is built from this logger,
  // so reading it here loops until the stack overflows.
  prettyPrint: Env.appEnv == 'development',
);

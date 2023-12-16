import 'package:dox_core/dox_core.dart';

LoggerConfig logger = LoggerConfig(
  /// Application name
  /// -------------------------------
  /// The name of the application you want to add to the log.
  name: Env.get('APP_NAME'),

  /// Toggle logger
  /// -------------------------------
  /// Enable or disable logger in application.
  enabled: true,

  /// Logging level
  /// -------------------------------
  /// The level from which you want the logger to flush logs.
  level: Env.get('LOG_LEVEL', 'info'),

  /// Pretty print
  /// -------------------------------
  /// It is highly advised NOT to use `prettyPrint` in production, since it
  /// can have huge impact on performance.
  prettyPrint: Env.get('APP_ENV') == 'development',
);

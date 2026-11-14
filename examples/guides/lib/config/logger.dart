import 'package:dox_core/dox_core.dart';
import 'package:my_app/config/env.dart';

LoggerConfig logger = LoggerConfig(
  name: env.appName,
  enabled: true,
  level: env.logLevel,
  // colors on your machine, one JSON line per log in staging and production
  // not appConfig.isDevelopment: appConfig is built from this logger,
  // so reading it here loops until the stack overflows.
  prettyPrint: env.appEnv == 'development',
);

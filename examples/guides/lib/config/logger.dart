import 'package:dox_core/dox_core.dart';
import 'package:my_app/config/env.dart';

LoggerConfig logger = LoggerConfig(
  name: env.appName,
  enabled: true,
  level: env.logLevel,
  // colors on your machine, one JSON line per log in staging and production
  prettyPrint: env.isDevelopment,
);

import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/error_handler.dart';
import 'package:my_app/app/http/response_handler.dart';
import 'package:my_app/config/cache.dart';
import 'package:my_app/config/cors.dart';
import 'package:my_app/config/env.dart';
import 'package:my_app/config/logger.dart';
import 'package:my_app/config/services.dart';
import 'package:my_app/config/storage.dart';
import 'package:my_app/dtos.g.dart';
import 'package:my_app/routes/api.dart';
import 'package:my_app/routes/web.dart';

AppConfig appConfig = AppConfig(
  appKey: env.appKey,
  serverPort: env.appPort,
  totalIsolate: env.appTotalIsolate ?? Platform.numberOfProcessors,
  globalMiddleware: <dynamic>[
    LogMiddleware(enabled: env.appEnv != 'production'),
  ],

  /// the SPA catch-all route is in WebRouter, so it comes last
  routers: <Router>[ApiRouter(), WebRouter()],

  /// every @Dto class, from lib/dtos.g.dart
  dtos: dtos,

  /// one JSON shape for every error (custom errors guide)
  responseHandler: ResponseHandler(),

  /// log unexpected errors (custom errors guide)
  errorHandler: reportError,

  cache: cache,
  storage: storage,
  cors: cors,
  services: services,
  logger: logger,
);

import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/error_handler.dart';
import 'package:my_app/app/http/response_handler.dart';
import 'package:my_app/config/cache.dart';
import 'package:my_app/config/cors.dart';
import 'package:my_app/config/env.dart';
import 'package:my_app/config/logger.dart';
import 'package:my_app/generated/container.g.dart';
import 'package:my_app/generated/dtos.g.dart';
import 'package:my_app/routes/api.dart';
import 'package:my_app/routes/web.dart';
import 'package:my_app/providers/orm_provider.dart';

AppConfig appConfig = AppConfig(
  appKey: env.appKey,
  serverPort: env.appPort,
  totalIsolate: env.appTotalIsolate ?? Platform.numberOfProcessors,
  globalMiddleware: <dynamic>[
    LogMiddleware(enabled: env.appEnv != 'production'),
  ],

  /// the SPA catch-all route is in WebRouter, so it comes last
  routers: <Router>[ApiRouter(), WebRouter()],

  /// every @Inject class, router and provider, from lib/generated/container.g.dart
  container: registerContainer,

  /// every @Dto class, from lib/generated/dtos.g.dart
  dtos: dtos,

  /// one JSON shape for every error (custom errors guide)
  responseHandler: ResponseHandler(),

  /// log unexpected errors (custom errors guide)
  exceptionHandler: const AppExceptionHandler(),

  cache: cache,
  cors: cors,

  /// the ORM first: the other providers use the database
  providers: <DoxProvider>[ORMProvider()],
  logger: logger,
);

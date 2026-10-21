/// coverage:ignore-file
library;

import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/logger.dart';

void defaultErrorHandler(Object? error, StackTrace stackTrace) {
  Logger.warn(error);
  Logger.danger(stackTrace.toString());
}

/// Which HTTP server Dox runs on.
enum ServerBackend {
  /// Rust (hyper) owns the sockets and parses HTTP, see `dox_http_native`.
  /// The default. Dox uses dart:io instead when the native library can not
  /// load, or when the app has WebSocket or Socket.IO routes.
  native,

  /// The `dart:io` HttpServer.
  dartIo,
}

class AppConfig {
  final String appKey;
  final int serverPort;
  final int totalIsolate;
  final ResponseHandlerInterface? responseHandler;
  final Function(Object?, StackTrace) errorHandler;

  /// Every DTO of the app: `dtos` from `lib/dtos.g.dart`.
  /// Dox finds the DTO of a controller parameter and of
  /// `req.validate<T>()` with it.
  final List<DtoSchema<Object>> dtos;

  /// Messages for validation errors, for example in other languages.
  /// Default: the English messages.
  final MessageResolver? validationMessages;
  final List<dynamic> globalMiddleware;
  final List<Router> routers;
  final CORSConfig cors;

  /// cache stores for `Cache()`, see `dox_cache`
  final CacheConfig cache;

  /// storage disks for `Storage()`, see `dox_storage`
  final StorageConfig storage;

  /// `/docs`, `/openapi.json` and `/openapi.yaml`, see `dox_openapi`
  final OpenApiConfig openApi;

  /// Socket.IO on the http port, see `dox_socketio`. Off by default.
  final SocketIoConfig socketIo;
  final LoggerConfig logger;
  final List<DoxService> services;

  /// Max size in bytes of a JSON or urlencoded body. Bigger bodies get
  /// 413 Payload Too Large. Default 10 MB.
  final int maxBodySize;

  /// Max size in bytes of a multipart/form-data body (file uploads).
  /// Bigger bodies get 413 Payload Too Large. Default 100 MB.
  final int maxMultipartSize;

  /// IPs or CIDR ranges of reverse proxies (nginx, Caddy, load balancer)
  /// that Dox trusts. Only when the direct client is in this list does Dox
  /// read `X-Forwarded-For` for `req.ip()` and `X-Forwarded-Proto` for
  /// `req.scheme()`. Use `['*']` to trust any client (only safe when the
  /// app port is not reachable from outside). Empty by default.
  final List<String> trustedProxies;

  /// gzip responses in Dart (`HttpServer.autoCompress`). Off by default.
  /// It costs CPU on every response. Let the proxy do it when you have one.
  final bool compress;

  /// The HTTP server. Default [ServerBackend.native]. The env var
  /// `DOX_SERVER=dartio` wins over this value. `DOX_SERVER=native` forces
  /// the native server, even for an app with WebSocket routes.
  final ServerBackend server;

  AppConfig({
    required this.appKey,
    this.serverPort = 3000,

    /// isolates (threads) that serve http. Default: one per CPU core.
    int? totalIsolate,
    this.services = const <DoxService>[],
    this.dtos = const <DtoSchema<Object>>[],
    this.validationMessages,
    this.globalMiddleware = const <dynamic>[],
    this.routers = const <Router>[],
    this.cors = const CORSConfig(),
    this.logger = const LoggerConfig(),
    this.cache = const CacheConfig(
      defaultStore: 'file',
      stores: <String, Map<String, dynamic>>{
        'file': <String, dynamic>{'driver': 'file', 'path': 'storage/cache'},
        'memory': <String, dynamic>{'driver': 'memory'},
      },
    ),
    this.storage = const StorageConfig(),
    this.openApi = const OpenApiConfig(),
    this.socketIo = const SocketIoConfig(),
    this.errorHandler = defaultErrorHandler,
    this.responseHandler,
    this.maxBodySize = 10 * 1024 * 1024,
    this.maxMultipartSize = 100 * 1024 * 1024,
    this.trustedProxies = const <String>[],
    this.compress = false,
    this.server = ServerBackend.native,
  }) : totalIsolate = totalIsolate ?? Platform.numberOfProcessors;
}

class CORSConfig {
  final bool enabled;
  final dynamic origin;
  final dynamic methods;
  final dynamic headers;
  final dynamic exposeHeaders;
  final bool? credentials;
  final num? maxAge;

  const CORSConfig({
    this.enabled = true,
    this.origin,
    this.methods,
    this.headers,
    this.exposeHeaders,
    this.credentials,
    this.maxAge,
  });
}

class LoggerConfig {
  final String name;
  final bool enabled;
  final bool prettyPrint;
  final String level;

  const LoggerConfig({
    this.name = '',
    this.enabled = false,
    this.prettyPrint = false,
    this.level = 'info',
  });
}

/// coverage:ignore-file
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/logger.dart';

void defaultErrorHandler(Object? error, StackTrace stackTrace) {
  Logger.warn(error);
  Logger.danger(stackTrace.toString());
}

class AppConfig {
  final String appKey;
  final int serverPort;
  final int totalIsolate;
  final ResponseHandlerInterface? responseHandler;
  final Function(Object?, StackTrace) errorHandler;
  final Map<Type, FormRequest Function()> formRequests;
  final List<dynamic> globalMiddleware;
  final List<Router> routers;
  final CORSConfig cors;
  final CacheConfig cache;
  final FileStorageConfig fileStorage;
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

  AppConfig({
    required this.appKey,
    this.serverPort = 3000,

    /// isolates (threads) that serve http. Default: one per CPU core.
    int? totalIsolate,
    this.services = const <DoxService>[],
    this.formRequests = const <Type, FormRequest Function()>{},
    this.globalMiddleware = const <dynamic>[],
    this.routers = const <Router>[],
    this.cors = const CORSConfig(),
    this.logger = const LoggerConfig(),
    this.cache = const CacheConfig(),
    this.fileStorage = const FileStorageConfig(),
    this.errorHandler = defaultErrorHandler,
    this.responseHandler,
    this.maxBodySize = 10 * 1024 * 1024,
    this.maxMultipartSize = 100 * 1024 * 1024,
    this.trustedProxies = const <String>[],
    this.compress = false,
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

class CacheConfig {
  final String defaultDriver;
  final Map<String, CacheDriverInterface> drivers;

  const CacheConfig({
    this.defaultDriver = 'file',
    this.drivers = const <String, CacheDriverInterface>{},
  });
}

class FileStorageConfig {
  final String defaultDriver;
  final Map<String, StorageDriverInterface> drivers;

  const FileStorageConfig({
    this.defaultDriver = 'local',
    this.drivers = const <String, StorageDriverInterface>{},
  });
}

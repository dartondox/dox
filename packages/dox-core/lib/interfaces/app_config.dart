/// coverage:ignore-file
import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/logger.dart';

void defaultErrorHandler(Object? error, StackTrace stackTrace) {
  DoxLogger.warn(error);
  DoxLogger.danger(stackTrace.toString());
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
  final List<DoxService> services;

  AppConfig({
    required this.appKey,
    this.serverPort = 3000,
    this.totalIsolate = 3,
    this.services = const <DoxService>[],
    this.formRequests = const <Type, FormRequest Function()>{},
    this.globalMiddleware = const <dynamic>[],
    this.routers = const <Router>[],
    this.cors = const CORSConfig(),
    this.cache = const CacheConfig(),
    this.fileStorage = const FileStorageConfig(),
    this.errorHandler = defaultErrorHandler,
    this.responseHandler,
  });
}

class CORSConfig {
  final dynamic allowOrigin;
  final dynamic allowMethods;
  final dynamic allowHeaders;
  final dynamic exposeHeaders;
  final bool? allowCredentials;

  const CORSConfig({
    this.allowOrigin,
    this.allowMethods,
    this.allowHeaders,
    this.exposeHeaders,
    this.allowCredentials,
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

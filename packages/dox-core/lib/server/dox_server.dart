import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_request_handler.dart';
import 'package:dox_core/utils/logger.dart';
import 'package:dox_http_native/dox_http_native.dart';

class DoxServer {
  /// register singleton
  static final DoxServer _singleton = DoxServer._internal();
  factory DoxServer() => _singleton;
  DoxServer._internal();

  /// the http server. a `NativeHttpServer` (dox_http_native) or the
  /// dart:io one. both have the same `HttpServer` API.
  late HttpServer httpServer;

  /// set responseHandler
  ResponseHandlerInterface? responseHandler;

  /// true when [listen] will use the native server (dox_http_native).
  /// [log] prints why it does not, once.
  static bool usesNative({bool log = false}) {
    String? env = Platform.environment['DOX_SERVER']?.toLowerCase();
    ServerBackend backend = switch (env) {
      'dartio' || 'dart_io' || 'dart:io' => ServerBackend.dartIo,
      'native' => ServerBackend.native,
      _ => Dox().config.server,
    };
    if (backend == ServerBackend.dartIo) return false;

    // TODO(native): WebSocket upgrade in dox_http_native. Until then these
    // apps stay on dart:io. `DOX_SERVER=native` forces native anyway (the
    // WebSocket upgrade then fails, Socket.IO long-polling still works).
    if (env != 'native' &&
        (Dox().websocket != null || Route().mounts.isNotEmpty)) {
      if (log) {
        Logger.info('WebSocket or Socket.IO routes: using the dart:io server');
      }
      return false;
    }
    if (!NativeHttpServer.isAvailable) {
      /// always shown, also when the logger is off
      if (log) {
        stderr.writeln(
          '[dox] warning: dox_http_native did not load, using the dart:io '
          'server (${NativeHttpServer.loadError})',
        );
      }
      return false;
    }
    return true;
  }

  /// listen the request
  /// ```
  /// DoxServer().listen(3000);
  /// ```
  Future<HttpServer> listen(
    int port, {
    Function? onError,
    int? isolateId,
  }) async {
    AppConfig config = Dox().config;
    HttpServer server;
    if (usesNative(log: (isolateId ?? 1) == 1)) {
      /// Rust stops bodies over the bigger limit. the limit of each body
      /// type is checked again in Dart, with the normal 413 answer.
      server = await NativeHttpServer.bind(
        port,
        maxBodySize: max(config.maxBodySize, config.maxMultipartSize),
      );
    } else {
      server = await HttpServer.bind(
        InternetAddress.anyIPv6,
        port,
        shared: true,
      );
    }
    server.autoCompress = config.compress;

    /// a stray async error from app code (eg. an un-awaited future that
    /// fails) is logged here, instead of killing the whole isolate.
    runZonedGuarded(
      () {
        server.listen(
          httpRequestHandler,
          onError: onError ?? (dynamic error) => stderr.writeln(error),
        );
      },
      (Object error, StackTrace stackTrace) {
        Dox().config.errorHandler(error, stackTrace);
      },
    );
    httpServer = server;
    return server;
  }

  /// close http server
  /// ```
  /// server.close();
  /// ```
  Future<void> close({bool force = false}) async {
    await httpServer.close(force: force);
  }

  /// set response handler
  /// ```
  /// server.setResponseHandler(Handler());
  /// ```
  void setResponseHandler(ResponseHandlerInterface? handler) {
    responseHandler = handler;
  }
}

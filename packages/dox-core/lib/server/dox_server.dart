import 'dart:async';
import 'dart:io';

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

  /// The port to listen on. `APP_PORT` in the env means [configured] (the
  /// app reads it into `serverPort`). With no `APP_PORT`, `PORT` wins:
  /// Cloud Run, Fly, Render and Heroku tell the app its port with it.
  static int portFor(int configured) {
    if (Env.get<String?>('APP_PORT') != null) return configured;
    return int.tryParse(Env.get<String>('PORT')) ?? configured;
  }

  /// The host to listen on: [configured], else `APP_HOST`, else null
  /// (all interfaces).
  static String? hostFor(String? configured) {
    return configured ?? Env.get<String?>('APP_HOST');
  }

  /// listen the request. With no [address] it listens on all interfaces.
  /// ```
  /// DoxServer().listen(3000);
  /// DoxServer().listen(3000, address: '127.0.0.1');
  /// ```
  Future<HttpServer> listen(
    int port, {
    Object? address,
    Function? onError,
    int? isolateId,
  }) async {
    AppConfig config = Dox().config;
    HttpServer server;
    if (usesNative(log: (isolateId ?? 1) == 1)) {
      /// Rust stops a multipart form over maxMultipartSize and any other
      /// body over maxBodySize. Dart checks the limits again.
      server = await NativeHttpServer.bind(
        port,
        address: address,
        maxBodySize: config.maxBodySize,
        maxMultipartSize: config.maxMultipartSize,
        bodyTimeout: config.bodyTimeout,
      );
    } else {
      server = await HttpServer.bind(
        address ?? InternetAddress.anyIPv6,
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

  /// Graceful stop: no new connections, open requests get [timeout] to
  /// finish. Then every connection is closed.
  Future<void> shutdown(Duration timeout) async {
    HttpServer server = httpServer;
    Stopwatch clock = Stopwatch()..start();
    // native: completes when the open requests are done.
    // dart:io: completes at once, so wait for the active connections.
    await server.close().then(_ignore).timeout(timeout, onTimeout: _nothing);
    while (server.connectionsInfo().active > 0 && clock.elapsed < timeout) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await server.close(force: true);
  }

  static void _nothing() {}

  static void _ignore(Object? _) {}

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

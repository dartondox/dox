import 'dart:async';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_request_handler.dart';
import 'package:dox_http_native/dox_http_native.dart';

class DoxServer {
  /// register singleton
  static final DoxServer _singleton = DoxServer._internal();
  factory DoxServer() => _singleton;
  DoxServer._internal();

  /// the http server, a `NativeHttpServer` (dox_http_native). Rust owns
  /// the sockets and parses HTTP. It has the `dart:io` `HttpServer` API.
  late HttpServer httpServer;

  /// set responseHandler
  ResponseHandlerInterface? responseHandler;

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
  }) async {
    AppConfig config = Dox().config;

    /// Rust stops a multipart form over maxMultipartSize and any other
    /// body over maxBodySize. Dart checks the limits again.
    HttpServer server = await NativeHttpServer.bind(
      port,
      address: address,
      maxBodySize: config.maxBodySize,
      maxMultipartSize: config.maxMultipartSize,
      bodyTimeout: config.bodyTimeout,
    );
    server.autoCompress = config.compress;

    /// `X-XSS-Protection: 1; mode=block` (the default of dart:io) turns
    /// on an old browser filter that can make holes. OWASP says send 0.
    server.defaultResponseHeaders.set('X-XSS-Protection', '0');

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
        Dox().config.exceptionHandler.report(error, stackTrace);
      },
    );
    httpServer = server;
    return server;
  }

  /// Graceful stop: no new connections, open requests get [timeout] to
  /// finish. Then every connection is closed.
  Future<void> shutdown(Duration timeout) async {
    HttpServer server = httpServer;
    // completes when the open requests are done. WebSockets get 1001.
    await server.close().then(_ignore).timeout(timeout, onTimeout: _nothing);
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

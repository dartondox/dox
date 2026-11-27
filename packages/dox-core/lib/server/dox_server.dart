import 'dart:async';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_request_handler.dart';
import 'package:dox_core/http/request/trusted_proxy.dart';
import 'package:dox_core/utils/log_buffer.dart';
import 'package:dox_core/utils/strict_mode.dart';
import 'package:dox_http_native/dox_http_native.dart';

class DoxServer {
  /// register singleton
  static final DoxServer _singleton = DoxServer._internal();
  factory DoxServer() => _singleton;
  DoxServer._internal();

  /// the http server, a `NativeHttpServer` (dox_http_native). Rust owns
  /// the sockets and parses HTTP. It has the `dart:io` `HttpServer` API.
  late HttpServer httpServer;

  /// the server of [listen], null before it and after a close
  NativeHttpServer? _native;

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
    NativeHttpServer server = await NativeHttpServer.bind(
      port,
      address: address,
      maxBodySize: config.maxBodySize,
      maxMultipartSize: config.maxMultipartSize,
      bodyTimeout: config.bodyTimeout,
      idleTimeout: config.idleTimeout,
      maxConnections: config.maxConnections,
      http2: config.http2,
      maxConcurrentStreams: config.maxConcurrentStreams,
      tls: config.tls,
    );

    /// on a TLS port every request came over https
    TrustedProxy.directScheme = config.tls == null ? 'http' : 'https';
    server.autoCompress = config.compress;
    server.compressLevel = config.compressLevel;

    /// `X-XSS-Protection: 1; mode=block` (the default of dart:io) turns
    /// on an old browser filter that can make holes. OWASP says send 0.
    server.defaultResponseHeaders.set('X-XSS-Protection', '0');

    /// a stray async error from app code (eg. an un-awaited future that
    /// fails) is logged here, instead of killing the whole isolate.
    runZonedGuarded(
      () {
        server.listen(
          httpRequestHandler,
          onError:
              onError ?? (dynamic error) => stderr.writeln('[server] $error'),
        );
      },
      (Object error, StackTrace stackTrace) {
        try {
          Dox().config.exceptionHandler.report(error, stackTrace);
        } finally {
          LogBuffer.flush();
        }
      },
    );
    httpServer = server;
    _native = server;
    StrictMode.startWatchdog();
    return server;
  }

  /// Graceful stop: no new connections, open requests get [timeout] to
  /// finish. Then every connection is closed.
  Future<void> shutdown(Duration timeout) async {
    StrictMode.stopWatchdog();
    // from now on `reloadCertificate` throws a StateError
    _native = null;
    HttpServer server = httpServer;
    try {
      // completes when the open requests are done. WebSockets get 1001.
      await server.close().then(_ignore).timeout(timeout, onTimeout: _nothing);
      await server.close(force: true);
    } finally {
      _closed();
    }
  }

  /// No server any more: the next request object of this isolate (eg. in
  /// a unit test) is plain http again. Call it after the server closed:
  /// a request that is still open reads its scheme on first use.
  void _closed() {
    TrustedProxy.directScheme = 'http';
  }

  /// Stops the start when the files of `AppConfig.tls` are bad: it throws
  /// a `TlsException`. `Dox().startServer()` runs it once, before any
  /// isolate starts. Else each isolate fails on its own and is started
  /// again, in a loop. It does nothing when `tls` is off.
  Future<void> checkCertificate() async {
    Dox().config.tls?.check();
  }

  static void _nothing() {}

  static void _ignore(Object? _) {}

  /// close http server
  /// ```
  /// server.close();
  /// ```
  Future<void> close({bool force = false}) async {
    StrictMode.stopWatchdog();
    _native = null;
    try {
      await httpServer.close(force: force);
    } finally {
      _closed();
    }
  }

  /// Reads the certificate and key files of `AppConfig.tls` again, for
  /// example after `certbot` renewed them. New connections get the new
  /// certificate. Open connections keep the old one until they close.
  /// One call is enough: every isolate of the process gets it. When a
  /// file is bad, it throws a `TlsException` and the server keeps the old
  /// certificate. It throws a `StateError` when `tls` is off, before the
  /// server starts and after it is closed. Dox does not watch the files:
  /// the app decides when to call it (eg. on `SIGHUP`).
  /// ```
  /// await Dox().server.reloadCertificate();
  /// ```
  Future<void> reloadCertificate() async {
    NativeHttpServer? server = _native;
    if (server == null) {
      throw StateError('reloadCertificate: the server does not run');
    }
    await server.reloadCertificate();
  }

  /// set response handler
  /// ```
  /// server.setResponseHandler(Handler());
  /// ```
  void setResponseHandler(ResponseHandlerInterface? handler) {
    responseHandler = handler;
  }
}

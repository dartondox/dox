/// coverage:ignore-file
library;

import 'dart:io';

import 'package:dox_core/dox_core.dart';

class AppConfig {
  final String appKey;

  /// Old `APP_KEY`s, to change the key without logging out every user.
  /// Encrypted cookies and cookie sessions made with one of them can
  /// still be read. New ones are made with [appKey] only. Remove an old
  /// key once its cookies have expired.
  /// ```
  /// previousKeys: ['the-old-32-character-app-key....'],
  /// ```
  final List<String> previousKeys;

  /// The port to listen on. Default 3000. When the env has no `APP_PORT`
  /// but has `PORT` (Cloud Run, Fly, Render, Heroku set it), Dox listens
  /// on `PORT` instead.
  final int serverPort;

  /// The host (network interface) to listen on, like `127.0.0.1`.
  /// Default: the env var `APP_HOST`, else all interfaces (IPv6 and IPv4).
  final String? host;
  final int totalIsolate;
  final ResponseHandlerInterface? responseHandler;

  /// Reports every error and turns it into a response.
  /// Extend `ExceptionHandler` to log to a tracker or change the answer.
  final ExceptionHandler exceptionHandler;

  /// Every DTO of the app: `dtos` from `lib/generated/dtos.g.dart`.
  /// Dox finds the DTO of a controller parameter and of
  /// `req.validate<T>()` with it.
  final List<DtoSchema<Object>> dtos;

  /// Messages for validation errors, for example in other languages.
  /// Default: the English messages.
  final MessageResolver? validationMessages;
  final List<dynamic> globalMiddleware;

  /// Routers to register. You can leave it empty: every class that
  /// extends `Router` is in `lib/generated/container.g.dart`. A router listed here
  /// comes first, in this order.
  final List<Router> routers;

  /// Fills the container: `registerContainer` from
  /// `lib/generated/container.g.dart`. Every isolate runs it, so each one has its
  /// own instances. It also gives the routers, providers and model
  /// binders that `dox_builder` found.
  final void Function(IocContainer c)? container;
  final CORSConfig cors;

  /// cache stores for `Cache()`, see `dox_cache`
  final CacheConfig cache;

  /// `/docs`, `/openapi.json` and `/openapi.yaml`, see `dox_openapi`
  final OpenApiConfig openApi;
  final LoggerConfig logger;

  /// session settings for `SessionMiddleware`. Cookie driver by default.
  final SessionConfig session;

  /// Providers to run at start, in every isolate. You can leave it empty:
  /// every class that extends `DoxProvider` is in
  /// `lib/generated/container.g.dart`. A provider listed here runs first.
  final List<DoxProvider> providers;

  /// Max size in bytes of a JSON or urlencoded body. Bigger bodies get
  /// 413 Payload Too Large. Default 10 MB.
  final int maxBodySize;

  /// Max size in bytes of a multipart/form-data body (file uploads).
  /// Bigger bodies get 413 Payload Too Large. Default 100 MB.
  final int maxMultipartSize;

  /// Idle time with no body bytes. A client that sends no request body
  /// bytes for this long gets 408 Request Timeout. A slow but steady
  /// upload is fine. It stops clients that hold a connection open.
  /// Native server only. Default 120 seconds.
  final Duration bodyTimeout;

  /// A keep-alive connection with no new request for this long is closed.
  /// A request head must also come whole in this time. Behind a load
  /// balancer, set it longer than the idle timeout of the balancer (eg.
  /// 65 seconds for AWS ALB, which keeps connections for 60 seconds).
  /// Else Dox may close a connection the balancer still uses, and clients
  /// get 502. Default 30 seconds.
  final Duration idleTimeout;

  /// The most connections one isolate holds open at once. Must be 1 or
  /// more. 0 or less throws an `ArgumentError` when the server starts.
  /// When an isolate is full, it stops accepting until one closes. New
  /// clients wait in the OS listen queue (about 1024) until it is full.
  /// After that, the OS drops new connections. On Linux each new client
  /// goes to one isolate (`SO_REUSEPORT`), so it can wait for a full
  /// isolate even when others have room. The limit is per isolate, so the
  /// whole app holds up to `maxConnections * totalIsolate`. Keep that
  /// below the file limit of the process (`ulimit -n`). Native server
  /// only. Default null: no limit.
  final int? maxConnections;

  /// IPs or CIDR ranges of reverse proxies (nginx, Caddy, load balancer)
  /// that Dox trusts. Only when the direct client is in this list does Dox
  /// read `X-Forwarded-For` for `req.ip()` and `X-Forwarded-Proto` for
  /// `req.scheme()`. Use `['*']` to trust any direct client, but only the
  /// last `X-Forwarded-For` hop (only safe when the app port is not
  /// reachable from outside). Empty by default.
  final List<String> trustedProxies;

  /// gzip responses on a Rust thread of the native server. Off by default.
  /// Streamed responses are not compressed. It costs CPU on every response.
  /// Let the proxy do it when you have one.
  final bool compress;

  /// On SIGTERM or SIGINT the server stops taking new connections, and
  /// waits this long for open requests to finish. Then it closes the rest,
  /// runs `shutdown()` of every provider and exits. Default 8 seconds. Keep it
  /// below the kill timeout of your platform (docker stop: 10 seconds).
  final Duration shutdownTimeout;

  /// Turns on the `Origin` check for every `Route.websocket` route.
  /// Off (null) by default: any site can open a socket from a browser,
  /// with the cookies of the user. Set it to only allow pages of the same
  /// host and the sites in the list, like `['https://app.example.com']`.
  /// `[]` means the same host only. Other origins get 403. The
  /// `allowedOrigins` of a route wins over this.
  final List<String>? webSocketAllowedOrigins;

  AppConfig({
    required this.appKey,
    this.previousKeys = const <String>[],
    this.serverPort = 3000,
    this.host,

    /// isolates (threads) that serve http. Default: one per CPU core.
    int? totalIsolate,
    this.providers = const <DoxProvider>[],
    this.dtos = const <DtoSchema<Object>>[],
    this.validationMessages,
    this.globalMiddleware = const <dynamic>[],
    this.routers = const <Router>[],
    this.container,
    this.cors = const CORSConfig(),
    this.logger = const LoggerConfig(),
    this.cache = const CacheConfig(
      defaultStore: 'file',
      stores: <String, Map<String, dynamic>>{
        'file': <String, dynamic>{'driver': 'file', 'path': 'storage/cache'},
        'memory': <String, dynamic>{'driver': 'memory'},
      },
    ),
    this.session = const SessionConfig(),
    this.openApi = const OpenApiConfig(),
    this.exceptionHandler = const ExceptionHandler(),
    this.responseHandler,
    this.maxBodySize = 10 * 1024 * 1024,
    this.maxMultipartSize = 100 * 1024 * 1024,
    this.bodyTimeout = const Duration(seconds: 120),
    this.idleTimeout = const Duration(seconds: 30),
    this.maxConnections,
    this.trustedProxies = const <String>[],
    this.compress = false,
    this.shutdownTimeout = const Duration(seconds: 8),
    this.webSocketAllowedOrigins,
  }) : totalIsolate = totalIsolate ?? Platform.numberOfProcessors;
}

class CORSConfig {
  final bool enabled;
  final dynamic origin;
  final dynamic methods;
  final dynamic headers;
  final dynamic exposeHeaders;

  /// `true` sends `Access-Control-Allow-Credentials: true`. Browsers do
  /// not accept it with origin `*`, so list your sites in [origin] then.
  /// Dox prints a warning at start for that mix.
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

  /// lowest level to print: `debug`, `info`, `warn` or `error`.
  /// `success` counts as `info`, `danger` as `error`.
  final String level;

  const LoggerConfig({
    this.name = '',
    this.enabled = false,
    this.prettyPrint = false,
    this.level = 'info',
  });
}

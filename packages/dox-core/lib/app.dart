import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_static_handler.dart';
import 'package:dox_core/isolate/dox_isolate.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:dox_core/server/dox_server.dart';
import 'package:dox_core/utils/log_buffer.dart';
import 'package:dox_http_native/dox_http_native.dart';

IocContainer _ioc = IocContainer();

class Dox {
  /// setup singleton
  static Dox? _singleton;

  factory Dox() {
    if (_singleton == null) {
      Env().load();
      _singleton = Dox._internal();
    }
    return _singleton!;
  }

  Dox._internal();

  /// get dox http server
  DoxServer get server => DoxServer();

  /// get app config
  late AppConfig config;

  /// global dox ioc containers
  IocContainer ioc = _ioc;

  /// isolate Id
  int isolateId = 1;

  /// The number of isolates that really run the app. It is the same in
  /// every isolate. Dox sets it when the server starts: from
  /// [totalIsolate] or `config.totalIsolate`, and 1 on Windows. It is 1
  /// before that, and in `DoxTestClient`. Do not change it.
  int isolateCount = 1;

  /// checks DTOs and schemas for `req.validate<T>()` and controller
  /// parameters.
  RequestValidator validator = const RequestValidator();

  /// the DTOs of the app, from `config.dtos`. Empty before [initialize].
  DtoRegistry get dtos {
    return _dtos ??= DtoRegistry(
      _initialized ? config.dtos : const <DtoSchema<Object>>[],
    );
  }

  DtoRegistry? _dtos;

  /// validation messages, from `config.validationMessages`.
  MessageResolver get messages {
    MessageResolver? custom = _initialized ? config.validationMessages : null;
    return custom ?? MessageResolver.global;
  }

  bool _initialized = false;

  /// The [CoreFlags] of this isolate, from `config.flags`. All off before
  /// [initialize].
  CoreFlags get flags => _initialized ? config.flags : const CoreFlags();

  /// cache stores from `config.cache`, made on first use in each isolate.
  /// `Cache()` uses it. replace it in tests.
  late CacheManager cache = CacheManager(
    Cache.withAppPrefix(config.cache, Env.get<String>('APP_NAME')),
  );

  /// total isolate to spawn
  int? _totalIsolate;

  /// providers that run in every isolate when it starts
  List<DoxProvider> doxProviders = <DoxProvider>[];

  /// initialize dox application
  /// it load env and set config
  /// ```
  /// Dox().initialize(config);
  /// ```
  void initialize(AppConfig appConfig) async {
    config = appConfig;
    _initialized = true;
    if (appConfig.flags.envExpand && !Env().expanded) {
      Logger.warn(
        'CoreFlags.envExpand is on, but .env was read without it. Set '
        'Env.flags = flags at the top of main(), before any env value is '
        'read.',
      );
    }
    _dtos = null;
    ioc.clear();
    appConfig.container?.call(ioc);
  }

  /// override total isolate from config
  /// default is one per CPU core
  void totalIsolate(int value) {
    _totalIsolate = value;
  }

  /// start dox server
  /// ```
  /// await Dox().startServer();
  /// ```
  Future<void> startServer() async {
    checkAppKey();
    addProviders(config.providers);
    _totalIsolate ??= Dox().config.totalIsolate;
    int isolatesToSpawn = _totalIsolate!;

    /// stop here, before any isolate starts, when the native server can
    /// not run. The error says why and how to fix it.
    NativeHttpServer.ensureAvailable();

    /// Windows has no SO_REUSEPORT: one isolate owns the native listener.
    if (Platform.isWindows && isolatesToSpawn > 1) {
      Logger.info('Windows: the native server runs on one isolate');
      isolatesToSpawn = 1;
    }

    isolateCount = isolatesToSpawn;
    if (isolatesToSpawn > 1) {
      await DoxIsolate().spawn(isolatesToSpawn);
    }

    await startProviders();
    warnWebSocketOrigin();
    warnCorsCredentials();
    DoxServer().setResponseHandler(config.responseHandler);
    HttpServer server = await DoxServer().listen(
      DoxServer.portFor(config.serverPort),
      address: DoxServer.hostFor(config.host),
    );

    Logger.info(
      'Server started at ${serverUrl(server)} with $isolatesToSpawn isolate '
      '(native)',
    );
    _watchSignals();
  }

  final List<StreamSubscription<ProcessSignal>> _signals =
      <StreamSubscription<ProcessSignal>>[];

  /// SIGTERM (docker stop, Kubernetes, Cloud Run) and SIGINT (Ctrl+C)
  /// stop the server gracefully. A second signal stops it at once.
  void _watchSignals() {
    if (_signals.isNotEmpty) return;
    List<ProcessSignal> signals = <ProcessSignal>[
      ProcessSignal.sigint,
      // Windows can not watch SIGTERM
      if (!Platform.isWindows) ProcessSignal.sigterm,
    ];
    for (ProcessSignal signal in signals) {
      _signals.add(signal.watch().listen(_onSignal));
    }
  }

  Future<void> _onSignal(ProcessSignal signal) async {
    // stop watching: the next signal does the default, it ends the process
    _cancelSignals();
    Logger.info('$signal: stopping, open requests can finish');
    // `stop` writes the log buffer, also when it throws
    await stop();
    // a line logged after the flush of `stop` must not be lost
    LogBuffer.flush();
    exit(0);
  }

  void _cancelSignals() {
    for (StreamSubscription<ProcessSignal> signal in _signals) {
      signal.cancel();
    }
    _signals.clear();
  }

  /// Stop the server gracefully, in every isolate:
  /// 1. stop taking new connections
  /// 2. wait for open requests, up to `config.shutdownTimeout`
  /// 3. run `shutdown()` of every provider (eg. close database connections)
  /// 4. close the cache stores (eg. Redis connections)
  ///
  /// SIGTERM and SIGINT call this, then exit the process.
  /// ```
  /// await Dox().stop();
  /// ```
  Future<void> stop() async {
    _cancelSignals();
    try {
      await Future.wait(<Future<void>>[
        DoxIsolate().stopAll(config.shutdownTimeout),
        stopIsolate(),
      ]);
      // close the bus again: `killAll` closes it while the providers of the
      // main isolate still shut down, and one of them may join it again.
      IsolateBus.instance.close();
    } finally {
      LogBuffer.flush();
    }
  }

  /// [stop] for this isolate only. Internal: each isolate runs it.
  Future<void> stopIsolate() async {
    try {
      await _stopIsolate();
    } finally {
      // write the log lines that wait in the buffer, also after an error
      LogBuffer.flush();
    }
  }

  Future<void> _stopIsolate() async {
    await DoxServer().shutdown(config.shutdownTimeout);
    for (DoxProvider provider in doxProviders) {
      try {
        await provider.shutdown();
      } catch (error, stackTrace) {
        config.exceptionHandler.report(error, stackTrace);
      }
    }
    // after the providers: they may still use the cache
    try {
      await cache.close();
    } catch (error, stackTrace) {
      config.exceptionHandler.report(error, stackTrace);
    }
    // after the providers too: they may still publish
    if (isolateId != 1) IsolateBus.instance.close();
  }

  /// the real address of [server], like `http://127.0.0.1:3000` or
  /// `http://[::]:3000` (all interfaces)
  static String serverUrl(HttpServer server) {
    InternetAddress address = server.address;
    String host = address.type == InternetAddressType.IPv6
        ? '[${address.address}]'
        : address.address;
    return 'http://$host:${server.port}';
  }

  bool _warnedWebSocketOrigin = false;

  /// the text of the warning of [warnWebSocketOrigin]
  static const String webSocketOriginWarning =
      'dox: warning: WebSocket routes do not check the Origin header. Any '
      'website can open a socket with the cookie of a logged in user. To '
      'allow only your own sites, set AppConfig(webSocketAllowedOrigins: '
      "['https://app.example.com']), or allowedOrigins: on Route.websocket. "
      '[] allows the same host only.';

  /// print one warning to stderr when a `Route.websocket` route checks
  /// no `Origin`.
  /// Any site can then open a socket with the cookies of the user.
  void warnWebSocketOrigin() {
    if (_warnedWebSocketOrigin ||
        config.webSocketAllowedOrigins != null ||
        !Route().hasWebSocketWithoutOriginCheck) {
      return;
    }
    _warnedWebSocketOrigin = true;
    // stderr, not Logger: the logger is off by default
    stderr.writeln(webSocketOriginWarning);
  }

  bool _warnedCorsCredentials = false;

  /// the text of the warning of [warnCorsCredentials]
  static const String corsCredentialsWarning =
      "dox: warning: CORSConfig has origin '*' and credentials: true. "
      'Browsers reject this, so requests with cookies from other sites '
      "fail. List your sites in origin, eg. ['https://app.example.com'].";

  /// print one warning when the CORS config allows every origin with
  /// credentials. Browsers do not accept this. It does not change the
  /// headers Dox sends.
  void warnCorsCredentials() {
    CORSConfig cors = config.cors;
    dynamic origin = cors.origin;
    bool any = origin == '*' || (origin is List && origin.contains('*'));
    if (_warnedCorsCredentials || cors.credentials != true || !any) return;
    _warnedCorsCredentials = true;
    // stderr, not Logger: the logger is off by default
    stderr.writeln(corsCredentialsWarning);
  }

  /// old sample keys from `.env.example` files. they are public on
  /// GitHub, so anyone could sign tokens and cookies with them.
  static const List<String> _publicKeys = <String>[
    'ZrNbOZJAjC2MDzqehhsGV2DzFFI4pz5R',
    'KKep5qC6uHlAgrwaQTQewgMRSIqQnoj0',
  ];

  /// stop at startup when `APP_KEY` is missing, not exactly 32
  /// characters, or a public sample key. a short or public key is easy
  /// to guess, so anyone can sign tokens and cookies.
  /// in development, local, test and testing it only logs a warning.
  void checkAppKey() {
    String key = config.appKey.trim();
    String message;
    if (key.isEmpty) {
      message =
          'APP_KEY is not set. Run `dox key:generate` and put the key in .env';
    } else if (_publicKeys.contains(key)) {
      message = 'APP_KEY is a public sample key. Run `dox key:generate` for a new one';
    } else if (utf8.encode(key).length != 32) {
      message = 'APP_KEY must be exactly 32 characters. Run `dox key:generate`';
    } else {
      return;
    }
    String env = Env.get<String>('APP_ENV').toLowerCase();
    if (!<String>['development', 'local', 'test', 'testing'].contains(env)) {
      throw StateError(message);
    }
    Logger.warn(message);
  }

  /// Add a global middleware from a package. Call it in the `setup()` of a
  /// [DoxProvider]. It runs on every route, before the app's own
  /// `globalMiddleware`. A second add of the same one is skipped. It takes
  /// the same kinds as `globalMiddleware`. Use a top-level function or a
  /// const instance, so a restart does not add it twice. The list is
  /// cleared at each start, before the providers run.
  /// Add it from a provider's `setup()`, which runs on every start.
  /// Anything added before the app starts is cleared.
  void addGlobalMiddleware(Object middleware) {
    GlobalMiddleware.add(middleware);
  }

  List<dynamic>? _allGlobalSource;
  int _allGlobalVersion = -1;
  List<dynamic> _allGlobal = const <dynamic>[];

  /// the middleware that packages added, then `config.globalMiddleware`.
  /// the same list is given until one of them changes.
  List<dynamic> get allGlobalMiddleware {
    List<Object> added = GlobalMiddleware.items;
    if (added.isEmpty) return config.globalMiddleware;
    if (!identical(_allGlobalSource, config.globalMiddleware) ||
        _allGlobalVersion != GlobalMiddleware.version) {
      _allGlobalSource = config.globalMiddleware;
      _allGlobalVersion = GlobalMiddleware.version;
      _allGlobal = <dynamic>[...added, ...config.globalMiddleware];
    }
    return _allGlobal;
  }

  /// ####### functions need to run on isolate #######

  /// add providers that run in every isolate when it starts
  void addProviders(List<DoxProvider> providers) {
    doxProviders.addAll(providers);
  }

  /// add a provider that runs in every isolate when it starts
  void addProvider(DoxProvider provider) {
    doxProviders.add(provider);
  }

  /// run `setup()` of every provider, register the routes, then run
  /// `boot()` of every provider
  /// this is internal core use only
  /// your app do not need to call this function
  Future<void> startProviders() async {
    // a restart builds the package middleware again
    GlobalMiddleware.clear();
    _addContainerProviders();
    for (DoxProvider provider in doxProviders) {
      await provider.setup();
    }
    _registerRoute();
    _resolveControllers();
    if (config.openApi.isEnabled) OpenApiDocument(config.openApi).register();
    for (DoxProvider provider in doxProviders) {
      await provider.boot();
    }
  }

  /// write `openapi.json` and `openapi.yaml` of the app routes into [dir].
  /// `bin/openapi.dart` calls this for `dox openapi:generate`.
  /// ```
  /// Dox().initialize(appConfig);
  /// await Dox().writeOpenApi('storage/openapi');
  /// ```
  Future<List<File>> writeOpenApi(String dir) async {
    addProviders(config.providers);
    _addContainerProviders();
    for (DoxProvider provider in doxProviders) {
      await provider.setup();
    }
    _registerRoute();
    return OpenApiDocument(config.openApi).write(dir);
  }

  /// register the routes of the app routers and give them, without a
  /// server and without providers. `dox route:list` uses this.
  /// When `config.openApi` is on, the docs routes are in it too.
  /// Providers do not run, because their `setup()` may connect to a
  /// database or start a worker. So a route that a provider adds in
  /// `setup()` is not in the list.
  ///
  /// It is safe to call more than once. The route list is empty before
  /// and after the call, so a later [startServer] starts clean.
  /// Call it only before [startServer], never in a running app: it
  /// empties `Route()`, so the server would lose its routes.
  /// ```
  /// Dox().initialize(appConfig);
  /// AppRoutes routes = Dox().loadRoutes();
  /// ```
  AppRoutes loadRoutes() {
    _clearRoutes();
    try {
      _registerRoute();
      // like startProviders: the docs routes, when OpenAPI is on
      if (config.openApi.isEnabled) OpenApiDocument(config.openApi).register();
      Route route = Route();
      return AppRoutes(
        routes: List<RouteData>.of(route.routes),
        fallbacks: List<RouteData>.of(route.fallbacks),
        mounts: Map<String, RawRequestHandler>.of(route.mounts),
        mountsWithMiddleware: Set<String>.of(route.mountsWithMiddleware),
      );
    } finally {
      _clearRoutes();
    }
  }

  /// empty the routes, fallbacks, mounts and static folders
  void _clearRoutes() {
    Route route = Route();
    route.setRoutes(<RouteData>[]);
    route.setFallbacks(<RouteData>[]);
    route.setStatics(<StaticFolder>[]);
    for (String prefix in route.mounts.keys.toList()) {
      Route.unmount(prefix);
    }
  }

  /// ################ end ###########

  /// read the parameter types of every controller once, at start.
  /// a type that is not known stops the server here, not on a request.
  void _resolveControllers() {
    for (RouteData route in Route().routes) {
      route.handler;
    }
    for (RouteData route in Route().fallbacks) {
      route.handler;
    }
  }

  /// add the providers of the container that are not in [doxProviders]
  /// yet. a listed provider of a container type becomes the container
  /// instance, so both are the same object.
  void _addContainerProviders() {
    Set<Type> listed = <Type>{};
    for (DoxProvider provider in doxProviders) {
      listed.add(provider.runtimeType);
      ioc.adopt(provider);
    }
    for (DoxProvider provider in ioc.providers) {
      if (listed.add(provider.runtimeType)) doxProviders.add(provider);
    }
  }

  /// the routers of the app config, then the ones of the container
  List<Router> _routers() {
    List<Router> routers = List<Router>.of(config.routers);
    Set<Type> listed = <Type>{for (Router r in routers) r.runtimeType};
    for (Router router in ioc.routers) {
      if (listed.add(router.runtimeType)) routers.add(router);
    }
    return routers;
  }

  /// register routes assign in app config
  void _registerRoute() {
    for (Router router in _routers()) {
      Route.prefix(router.prefix);
      Route.resetWithNewMiddleware(<dynamic>[
        ...allGlobalMiddleware,
        ...router.middleware,
      ]);
      router.register();
    }
    Route.prefix('');
    Route.resetWithNewMiddleware(<dynamic>[]);
  }
}

/// the routes of the app, from [Dox.loadRoutes]
class AppRoutes {
  const AppRoutes({
    required this.routes,
    required this.fallbacks,
    required this.mounts,
    required this.mountsWithMiddleware,
  });

  /// every route, in the order they were added
  final List<RouteData> routes;

  /// the routes added with `Route.fallback`
  final List<RouteData> fallbacks;

  /// prefix => handler, added with `Route.mount`
  final Map<String, RawRequestHandler> mounts;

  /// the prefixes of the mounts that run the global middleware first
  final Set<String> mountsWithMiddleware;
}

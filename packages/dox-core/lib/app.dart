import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/isolate/dox_isolate.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:dox_core/server/dox_server.dart';
import 'package:dox_core/utils/logger.dart';
import 'package:dox_http_native/dox_http_native.dart';
import 'package:dox_socketio/dox_socketio.dart';
import 'package:sprintf/sprintf.dart';

IocContainer _ioc = IocContainer();

class Dox implements IDox {
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

  /// websocket
  IDoxWebsocket? websocket;

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

  /// cache stores from `config.cache`, made on first use in each isolate.
  /// `Cache()` uses it. replace it in tests.
  late CacheManager cache = CacheManager(config.cache);

  /// storage disks from `config.storage`, made on first use in each
  /// isolate. `Storage()` uses it. replace it in tests.
  late DriveManager storage = StorageDiskFactory(appKey: config.appKey)
      .create(config.storage);

  /// Socket.IO server of this isolate, when `config.socketIo` is enabled.
  /// ```
  /// Dox().socketIo?.to('room').emit('news', data);
  /// ```
  SocketIoServer? socketIo;

  /// total isolate to spawn
  int? _totalIsolate;

  /// list of services that need to run when
  /// creating isolate
  List<DoxService> doxServices = <DoxService>[];

  /// initialize dox application
  /// it load env and set config
  /// ```
  /// Dox().initialize(config);
  /// ```
  void initialize(AppConfig appConfig) async {
    config = appConfig;
    _initialized = true;
    _dtos = null;
  }

  /// override total isolate from config
  /// default is one per CPU core
  void totalIsolate(int value) {
    _totalIsolate = value;
  }

  /// set websocket
  /// ```
  /// Dox().initialize(config)
  /// Dox().setWebsocket(DoxWebsocket())
  /// ```
  @override
  void setWebsocket(IDoxWebsocket ws) {
    websocket = ws;
  }

  /// start dox server
  /// ```
  /// await Dox().startServer();
  /// ```
  Future<void> startServer() async {
    checkAppKey();
    addServices(config.services);
    _totalIsolate ??= Dox().config.totalIsolate;
    int isolatesToSpawn = _totalIsolate!;

    /// Windows has no SO_REUSEPORT: one isolate owns the native listener.
    if (Platform.isWindows && isolatesToSpawn > 1 && DoxServer.usesNative()) {
      Logger.info('Windows: the native server runs on one isolate');
      isolatesToSpawn = 1;
    }

    if (isolatesToSpawn > 1) {
      await DoxIsolate().spawn(isolatesToSpawn);
    }

    await startServices();
    DoxServer().setResponseHandler(config.responseHandler);
    await DoxServer().listen(config.serverPort, isolateId: 1);

    String backend = DoxServer().httpServer is NativeHttpServer
        ? 'native'
        : 'dart:io';
    Logger.info(
      sprintf(
        'Server started at http://127.0.0.1:%s with $isolatesToSpawn isolate '
        '($backend)',
        <dynamic>[Dox().config.serverPort],
      ),
    );
  }

  /// stop at startup when `APP_KEY` is missing in production.
  /// without a key, cookies and other encrypted data use an empty
  /// (predictable) key. outside production it only logs a warning.
  void checkAppKey() {
    if (config.appKey.trim().isNotEmpty) return;
    String message =
        'APP_KEY is not set. Run `dox key:generate` and put the key in .env';
    if (Env.get<String>('APP_ENV').toLowerCase() == 'production') {
      throw StateError(message);
    }
    Logger.warn(message);
  }

  /// ####### functions need to run on isolate #######

  /// add services that need to run on isolate spawn
  void addServices(List<DoxService> services) {
    doxServices.addAll(services);
  }

  /// add service that need to run on isolate spawn
  void addService(DoxService service) {
    doxServices.add(service);
  }

  /// start service registered to dox
  /// this is internal core use only
  /// your app do not need to call this function
  Future<void> startServices() async {
    for (DoxService service in doxServices) {
      await service.setup();
    }
    _registerRoute();
    _resolveControllers();
    _mountSocketIo();
    if (config.openApi.isEnabled) OpenApiDocument(config.openApi).register();
  }

  /// write `openapi.json` and `openapi.yaml` of the app routes into [dir].
  /// `bin/openapi.dart` calls this for `dox openapi:generate`.
  /// ```
  /// Dox().initialize(appConfig);
  /// await Dox().writeOpenApi('storage/openapi');
  /// ```
  Future<List<File>> writeOpenApi(String dir) async {
    addServices(config.services);
    for (DoxService service in doxServices) {
      await service.setup();
    }
    _registerRoute();
    return OpenApiDocument(config.openApi).write(dir);
  }

  /// Socket.IO gets the raw requests of its path, before the router.
  void _mountSocketIo() {
    SocketIoConfig settings = config.socketIo;
    if (!settings.enabled) return;
    SocketIoServer io = SocketIoServer(
      options: settings.options,
      adapter: settings.adapter?.create(),
    );
    for (NamespaceHandler handler in settings.namespaces) {
      io.register(handler);
    }
    socketIo = io;
    Route.mount(settings.options.path, io.handle);
    if (isolateId == 1 &&
        config.totalIsolate > 1 &&
        settings.options.transports.contains('polling')) {
      Logger.info(
        'Socket.IO runs on ${config.totalIsolate} isolates: '
        "clients should use transports: ['websocket'] (long-polling needs "
        'one isolate or sticky sessions), with a Redis adapter.',
      );
    }
  }

  /// ################ end ###########

  /// read the parameter types of every controller once, at start.
  /// a type that is not known stops the server here, not on a request.
  void _resolveControllers() {
    for (RouteData route in Route().routes) {
      route.handler;
    }
  }

  /// register routes assign in app config
  void _registerRoute() {
    List<Router> routers = config.routers;
    for (Router router in routers) {
      Route.prefix(router.prefix);
      Route.resetWithNewMiddleware(<dynamic>[
        ...config.globalMiddleware,
        ...router.middleware,
      ]);
      router.register();
    }
    Route.prefix('');
    Route.resetWithNewMiddleware(<dynamic>[]);
  }
}

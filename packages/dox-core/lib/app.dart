import 'package:dox_core/dox_core.dart';
import 'package:dox_core/isolate/dox_isolate.dart';
import 'package:dox_core/server/dox_server.dart';
import 'package:dox_core/utils/logger.dart';
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
  }

  /// override total isolate from config
  /// default is 3
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
    _totalIsolate ??= Dox().config.totalIsolate;
    int isolatesToSpawn = _totalIsolate ?? 1;

    if (isolatesToSpawn > 1) {
      await DoxIsolate().spawn(isolatesToSpawn);
    }

    await startServices();
    DoxServer().setResponseHandler(config.responseHandler);
    await DoxServer().listen(config.serverPort, isolateId: 1);

    DoxLogger.info(sprintf(
      'Server started at http://127.0.0.1:%s with $isolatesToSpawn isolate',
      <dynamic>[Dox().config.serverPort],
    ));
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
    _registerFormRequests();
    _registerRoute();
  }

  /// ################ end ###########

  /// register form request assign in app config
  void _registerFormRequests() {
    config.formRequests.forEach((Type key, Function() value) {
      Dox().ioc.registerRequest(key.toString(), value);
    });
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

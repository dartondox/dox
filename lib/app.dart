import 'package:dox_core/dox_core.dart';
import 'package:dox_core/isolate/dox_isolate.dart';
import 'package:dox_core/server/dox_server.dart';

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
  late IocContainer ioc;

  /// auth guard
  Guard? authGuard;

  /// total thread
  int _totalIsolate = 1;

  /// list of services that need to run when
  /// creating isolate
  List<DoxService> doxServices = <DoxService>[];

  /// initialize dox application
  /// it load env and set config
  /// ```
  /// Dox().initialize(config);
  /// ```
  void initialize(AppConfig appConfig) async {
    ioc = IocContainer();
    config = appConfig;
  }

  /// set total thread
  /// default is 3
  void totalIsolate(int value) {
    _totalIsolate = value;
  }

  /// set authorization config
  /// and this function can only call after initialize()
  /// ```
  /// await Dox().initialize(config)
  /// Dox().setAuthConfig(AuthConfig())
  /// ```
  void setAuthConfig(AuthConfigInterface authConfig) {
    authGuard = authConfig.guards[authConfig.defaultGuard];
  }

  /// start dox server
  /// ```
  /// await Dox().startServer();
  /// ```
  Future<void> startServer() async {
    if (_totalIsolate == 1) {
      await startServices();
      DoxServer().setResponseHandler(config.responseHandler);
      await DoxServer().listen(config.serverPort, isolateId: 1);
    } else {
      await DoxIsolate().spawn(_totalIsolate);
    }
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
    _registerFormRequests();
    _registerRoute();

    for (DoxService service in doxServices) {
      await service.setup(config);
    }
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

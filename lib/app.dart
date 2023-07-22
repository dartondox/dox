import 'package:dox_core/dox_core.dart';
import 'package:dox_core/interfaces/dox_service.dart';
import 'package:dox_core/router/multi_thread.dart';
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

  /// _multi thread
  int _multiThread = 3;

  List<DoxService> multiThreadServices = <DoxService>[];

  /// initialize dox application
  /// it load env and set config
  /// ```
  /// Dox().initialize(config);
  /// ```
  void initialize(AppConfig appConfig) async {
    ioc = IocContainer();
    config = appConfig;
  }

  /// start service registered to dox
  /// this is internal core use only
  /// your app do not need to call this function
  Future<void> startServices() async {
    _registerFormRequests();
    _registerRoute();

    for (DoxService service in multiThreadServices) {
      await service.setup(config);
    }
  }

  /// add initializers
  void addServices(List<DoxService> services) {
    multiThreadServices.addAll(services);
  }

  /// add initializers
  void addService(DoxService service) {
    multiThreadServices.add(service);
  }

  /// set total thread
  /// default is 3
  void totalThread(int value) {
    _multiThread = value;
  }

  /// start dox server
  /// ```
  /// await Dox().startServer();
  /// ```
  Future<void> startServer() async {
    await startServices();
    await DoxMultiThread().create(_multiThread);
    DoxServer server = DoxServer();
    server.setResponseHandler(config.responseHandler);
    await server.listen(config.serverPort);
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

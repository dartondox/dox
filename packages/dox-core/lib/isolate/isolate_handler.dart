import 'package:dox_core/dox_core.dart';
import 'package:dox_core/isolate/isolate_interfaces.dart';
import 'package:dox_core/server/dox_server.dart';

/// process middleware and controller and sent data via sentPort
void isolateHandler(IsolateSpawnParameter param) async {
  /// send port of main isolate
  AppConfig appConfig = param.config;
  List<DoxService> services = param.services;

  /// creating dox in new isolate;
  Dox().isolateId = param.isolateId;
  Dox().initialize(appConfig);
  Dox().addServices(services);

  /// register routes
  Route().setRoutes(param.routes);

  /// starting registered services in new isolate;
  await Dox().startServices();

  /// starting server in new isolate
  DoxServer().setResponseHandler(param.config.responseHandler);

  await DoxServer().listen(
    param.config.serverPort,
    isolateId: param.isolateId,
  );
}

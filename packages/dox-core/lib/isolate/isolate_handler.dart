import 'dart:isolate';

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
  Route().setBindings(Map<String, RouteBinding>.of(param.bindings));

  /// starting registered services in new isolate;
  await Dox().startServices();

  /// starting server in new isolate
  DoxServer().setResponseHandler(param.config.responseHandler);

  await DoxServer().listen(
    DoxServer.portFor(appConfig.serverPort),
    address: DoxServer.hostFor(appConfig.host),
  );

  /// the main isolate sends a reply port here to stop this isolate
  ReceivePort commands = ReceivePort();
  commands.listen((dynamic reply) async {
    commands.close();
    await Dox().stopIsolate();
    (reply as SendPort).send(true);
  });
  param.control?.send(commands.sendPort);
}

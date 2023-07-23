import 'package:dox_core/dox_core.dart';
import 'package:dox_core/isolate/isolate_interfaces.dart';
import 'package:dox_core/server/dox_server.dart';

/// process middleware and controller and sent data via sentPort
void isolateHandler(IsolateSpawnParameter param) async {
  Dox().initialize(param.config);
  Dox().addServices(param.services);
  Dox().authGuard = param.authGuard;
  await Dox().startServices();

  DoxServer().setResponseHandler(param.config.responseHandler);
  await DoxServer().listen(param.config.serverPort, isolateId: param.isolateId);
}

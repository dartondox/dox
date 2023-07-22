import 'dart:isolate';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/router/http_mc_handler.dart';
import 'package:dox_core/router/multi_thread_interfaces.dart';

/// process middleware and controller and sent data via sentPort
void multiThreadIsolateHandler(IsolateSpawnParameter param) async {
  SendPort sendPort = param.sendPort;

  /// initialize dox for new isolate
  Dox().initialize(param.config);
  Dox().addServices(param.services);
  await Dox().startServices();

  // Send a SendPort to the main isolate so that
  // it can send request to this isolate.
  ReceivePort receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((dynamic request) {
    handleMiddlewareAndController(
      request[0],
      request[1],
    ).then((dynamic result) {
      sendPort.send(result);
    }).catchError((dynamic error) {
      sendPort.send(error);
    });
  });
}

import 'dart:isolate';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/isolate/isolate_interfaces.dart';
import 'package:dox_core/server/dox_server.dart';
import 'package:dox_core/websocket/event.dart';

/// process middleware and controller and sent data via sentPort
void isolateHandler(IsolateSpawnParameter param) async {
  Dox().isolateId = param.isolateId;
  Dox().sendPort = param.sendPort;
  Dox().initialize(param.config);
  Dox().addServices(param.services);
  Dox().authGuard = param.authGuard;
  await Dox().startServices();

  /// sending sendPort to main isolate
  ReceivePort receivePort = ReceivePort();
  param.sendPort.send(receivePort.sendPort);

  receivePort.listen((dynamic message) {
    /// listen for to emit message and
    if (message is WebSocketEmitEvent) {
      SocketEmitter emitter = SocketEmitter(
          sender: message.senderId, roomId: message.roomId, via: 'isolate');
      emitter.emit(message.event, message.message, exclude: message.exclude);
    }
  });

  DoxServer().setResponseHandler(param.config.responseHandler);
  await DoxServer().listen(
    param.config.serverPort,
    isolateId: param.isolateId,
  );
}

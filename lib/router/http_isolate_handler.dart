import 'dart:isolate';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/router/http_mc_handler.dart';
import 'package:dox_core/router/multi_thread.dart';
import 'package:dox_core/router/route_data.dart';

void httpIsolateHandler(
  DoxRequest doxRequest,
  RouteData route,
  void Function(dynamic) callback,
) {
  DoxMultiThread multiThread = DoxMultiThread();

  if (multiThread.totalThread >= Dox().getMaximumThread()) {
    handleMiddlewareAndController(route, doxRequest)
        .then(callback)
        .catchError(callback);
  } else {
    multiThread.increase();
    ReceivePort receivePort = ReceivePort();
    Isolate.spawn(_handle, <dynamic>[
      receivePort.sendPort,
      doxRequest,
      route,
    ]);

    receivePort.listen((dynamic message) {
      callback(message);
      multiThread.decrease();
      receivePort.close();
    });
  }
}

/// process middleware and controller and sent data via sentPort
void _handle(List<dynamic> args) {
  SendPort sendPort = args[0];
  DoxRequest doxRequest = args[1];
  RouteData route = args[2];
  handleMiddlewareAndController(route, doxRequest).then((dynamic result) {
    sendPort.send(result);
  }).catchError((dynamic error) {
    sendPort.send(error);
  });
}

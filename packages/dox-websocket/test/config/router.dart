import 'package:dox_core/dox_core.dart';
import 'package:dox_websocket/dox_websocket.dart';

class WsController {
  intro(WebsocketEmitter emitter, dynamic message) {
    emitter.emit('intro', message);
  }

  json(WebsocketEmitter emitter, dynamic message) {
    emitter.emit('json', message);
  }
}

class WebsocketRouter implements Router {
  @override
  List get middleware => [];

  @override
  String get prefix => '';

  @override
  void register() {
    WsController wsController = WsController();

    Route.websocket('ws', (WebsocketEvent event) {
      event.on('intro', wsController.intro);
      event.on('json', wsController.json);
    });
  }
}

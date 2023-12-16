import 'package:dox_core/dox_core.dart';
import 'package:dox_websocket/dox_websocket.dart';

class WebsocketRouter extends Router {
  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  void register() {
    Route.websocket('ws', (WebsocketEvent event) {
      event.on('intro', (WebsocketEmitter emitter, dynamic message) {
        emitter.emit('intro', message);
      });

      event.on('json', (WebsocketEmitter emitter, dynamic message) {
        emitter.emit('json_response', message);
      });
    });

    Route.websocket('chat', (WebsocketEvent event) {
      event.on('intro', (WebsocketEmitter emitter, dynamic message) {
        emitter.emit('intro', message);
      });

      event.on('json', (WebsocketEmitter emitter, dynamic message) {
        emitter.emit('json_response', message);
      });
    });
  }
}

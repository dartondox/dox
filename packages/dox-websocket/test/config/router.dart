import 'package:dox_core/dox_core.dart';
import 'package:dox_websocket/dox_websocket.dart';

class WebsocketRouter implements Router {
  @override
  List get middleware => [];

  @override
  String get prefix => '';

  @override
  void register() {
    Route.websocket('ws', (WebsocketEvent event) {
      event.on('intro', (WebsocketEmitter emitter, dynamic message) {
        emitter.room('ws').emit('intro', message);
      });

      event.on('json', (WebsocketEmitter emitter, dynamic message) {
        emitter.emitExceptSender('json', message);
      });
    });
  }
}

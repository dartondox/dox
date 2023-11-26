import 'package:dox_core/dox_core.dart';
import 'package:dox_websocket/dox_websocket.dart';

class WebsocketRouter extends Router {
  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  void register() {
    Route.websocket('ws', (WebsocketEvent event) {
      event.on('intro', (WebsocketEmitter emitter, dynamic message) {
        print(message);
        emitter.emit('intro', message);
      });
    });
  }
}

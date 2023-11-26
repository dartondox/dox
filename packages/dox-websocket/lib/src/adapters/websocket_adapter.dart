import 'package:dox_websocket/src/websocket_emit_event.dart';

abstract class WebsocketAdapterInterface {
  emit(WebsocketEmitEvent event);
}

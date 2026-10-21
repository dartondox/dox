import 'package:dox_app/app/socket/chat.namespace.dart';
import 'package:dox_app/config/redis.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox_socketio/dox_socketio.dart';

/// Socket.IO
/// -------------------------------
/// Off by default. Set `SOCKETIO_ENABLED=true` to serve `/socket.io/` on the
/// app port. With many isolates, clients must use
/// `transports: ['websocket']`, and the Redis adapter shares broadcasts.
SocketIoConfig socketIo = SocketIoConfig(
  enabled: Env.get<bool>('SOCKETIO_ENABLED', false),
  namespaces: <NamespaceHandler>[ChatNamespace()],
  adapter: const RedisSocketAdapterFactory(),
);

/// Makes the Redis adapter inside each isolate.
class RedisSocketAdapterFactory extends SocketAdapterFactory {
  const RedisSocketAdapterFactory();

  @override
  Adapter create() {
    return RedisAdapter(subscriber: redis.duplicate(), publisher: redis);
  }
}

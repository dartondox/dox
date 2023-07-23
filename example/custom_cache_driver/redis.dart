import 'package:dox_core/dox_core.dart';
import 'package:redis/redis.dart';

class Redis {
  Command? _command;

  Future<Command> get command async {
    if (_command == null) {
      RedisConnection conn = RedisConnection();
      String tls = Env.get('REDIS_TLS', 'false');
      String host = Env.get('REDIS_HOST', 'localhost');
      int port = int.parse(Env.get('REDIS_PORT', '6379'));

      if (tls == 'true') {
        _command = await conn.connectSecure(host, port);
      } else {
        _command = await conn.connect(host, port);
      }

      String username = Env.get('REDIS_USERNAME', '');
      String password = Env.get('REDIS_PASSWORD', '');

      if (username.isNotEmpty && password.isNotEmpty) {
        await _command?.send_object(
          <dynamic>['AUTH', username, password],
        );
      }
    }
    return _command!;
  }

  Future<void> close() async {
    await _command?.get_connection().close();
  }

  /// Declare as Singleton
  static final Redis _i = Redis._internal();
  factory Redis() => _i;
  Redis._internal();
}

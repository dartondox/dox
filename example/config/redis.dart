import 'package:dox_core/dox_core.dart';
import 'package:redis/redis.dart';

class Redis implements DoxService {
  /// Declare as Singleton to reuse connection
  static final Redis _i = Redis._internal();
  factory Redis() => _i;
  Redis._internal();

  late Command command;

  @override
  Future<void> setup(AppConfig appConfig) async {
    RedisConnection conn = RedisConnection();
    String tls = Env.get('REDIS_TLS', 'false');
    String host = Env.get('REDIS_HOST', 'localhost');
    int port = int.parse(Env.get('REDIS_PORT', '6379'));

    if (tls == 'true') {
      Redis().command = await conn.connectSecure(host, port);
    } else {
      Redis().command = await conn.connect(host, port);
    }

    String username = Env.get('REDIS_USERNAME', '');
    String password = Env.get('REDIS_PASSWORD', '');

    if (username.isNotEmpty && password.isNotEmpty) {
      await Redis().command.send_object(
        <dynamic>['AUTH', username, password],
      );
    }
  }

  Future<void> close() async {
    await Redis().command.get_connection().close();
  }
}

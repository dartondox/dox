import 'dart:io';

/// Redis for tests. Set REDIS_HOST and REDIS_PORT to change it.
class RedisEnv {
  static String get host {
    return Platform.environment['REDIS_HOST'] ?? '127.0.0.1';
  }

  static int get port {
    return int.tryParse(Platform.environment['REDIS_PORT'] ?? '') ?? 6379;
  }

  /// True when a TCP connection to Redis works.
  static Future<bool> isReachable() async {
    try {
      Socket socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 1),
      );
      socket.destroy();
      return true;
    } on SocketException {
      return false;
    }
  }
}

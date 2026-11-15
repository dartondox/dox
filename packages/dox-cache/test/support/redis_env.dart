import 'dart:io';

/// Redis for tests. Set REDIS_PORT (and REDIS_HOST) to run them. With no
/// REDIS_PORT the Redis tests are skipped, so a test run never touches a
/// Redis on the default port by mistake.
class RedisEnv {
  static String get host {
    return Platform.environment['REDIS_HOST'] ?? '127.0.0.1';
  }

  /// Only read when the tests are not skipped, see [skipReason].
  static int get port {
    return int.parse(Platform.environment['REDIS_PORT']!);
  }

  /// Why the Redis tests are skipped, or null to run them.
  static Future<String?> skipReason() async {
    if (Platform.environment['REDIS_PORT'] == null) {
      return 'set REDIS_PORT to run the Redis tests';
    }
    if (!await isReachable()) return 'Redis not reachable at $host:$port';
    return null;
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

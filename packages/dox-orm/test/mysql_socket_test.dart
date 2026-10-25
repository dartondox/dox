import 'dart:io';

import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

/// Connects to MySQL or MariaDB over a Unix socket. CI has no socket, so it
/// runs only when `DOX_MYSQL_SOCKET_URL` is set, eg.
/// `mysql://root@/dox?socket=/tmp/mysql.sock`.
void main() {
  String? url = Platform.environment['DOX_MYSQL_SOCKET_URL'];

  test('mysql socket', () async {
    ConnectionConfig c = ConnectionConfig.fromUrl(url!);
    expect(c.isUnixSocket, isTrue);
    DBDriver driver = c.createDriver();
    expect(driver, isA<MysqlNativeDriver>());
    List<Map<String, dynamic>> rows = await driver.query('SELECT 1 AS one');
    expect(rows.first['one'].toString(), '1');
  }, skip: url == null ? 'DOX_MYSQL_SOCKET_URL is not set' : false);
}

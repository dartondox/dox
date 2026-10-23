import 'dart:io';

import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

/// Connects to MySQL or MariaDB over a Unix socket, with the native and
/// the Dart driver. CI has no socket, so it runs only when
/// `DOX_MYSQL_SOCKET_URL` is set, eg.
/// `mysql://root@/dox?socket=/tmp/mysql.sock`.
void main() {
  String? url = Platform.environment['DOX_MYSQL_SOCKET_URL'];

  for (bool native in <bool>[true, false]) {
    test('mysql socket, native: $native', () async {
      ConnectionConfig c = ConnectionConfig.fromUrl(
        url!,
        extra: <String, dynamic>{'native': native},
      );
      expect(c.isUnixSocket, isTrue);
      DBDriver driver = c.createDriver();
      expect(driver is MysqlNativeDriver, native);
      List<Map<String, dynamic>> rows = await driver.query('SELECT 1 AS one');
      expect(rows.first['one'].toString(), '1');
    }, skip: url == null ? 'DOX_MYSQL_SOCKET_URL is not set' : false);
  }
}

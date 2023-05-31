import 'package:dox_core/db/db_driver.dart';
import 'package:test/test.dart';

void main() {
  group('DB Driver |', () {
    test('mysql', () {
      expect(DatabaseDriver.mysql, 'mysql');
    });

    test('postgres', () {
      expect(DatabaseDriver.postgres, 'postgres');
    });
  });
}

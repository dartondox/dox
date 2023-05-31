import 'package:dox_core/db/db_driver.dart';
import 'package:test/test.dart';

void main() {
  test('DB Driver', () {
    expect(DatabaseDriver.mysql, 'mysql');
    expect(DatabaseDriver.postgres, 'postgres');
  });
}

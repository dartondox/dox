import 'package:dox_mysql_native/dox_mysql_native.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:dox_postgres_native/dox_postgres_native.dart';
import 'package:test/test.dart';

/// No database needed: the pools are fakes whose rollback fails.
class _PgPool extends PgNativePool {
  _PgPool() : super.fromHandle(0);

  @override
  Future<int> begin() async => 1;

  @override
  Future<void> rollback(int transaction) async =>
      throw StateError('rollback failed');
}

class _MysqlPool extends MysqlNativePool {
  _MysqlPool() : super.fromHandle(0);

  @override
  Future<int> begin() async => 1;

  @override
  Future<void> rollback(int transaction) async =>
      throw StateError('rollback failed');
}

void main() {
  Map<String, DBDriver Function()> drivers = <String, DBDriver Function()>{
    'postgres': () => PostgresNativeDriver(_PgPool()),
    'mysql': () => MysqlNativeDriver(_MysqlPool()),
  };
  drivers.forEach((String name, DBDriver Function() make) {
    test('$name: a failed rollback keeps the first error', () async {
      DBDriver driver = make();
      Future<void> run() => driver.transaction<void>(() async {
        throw FormatException('the real error');
      });
      await expectLater(run(), throwsA(isA<FormatException>()));
    });
  });
}

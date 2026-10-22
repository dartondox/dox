// Runs the dox_orm tests on MysqlNativeDriver.
// Same env as dox_orm: DB_PORT and DB_USER (DRIVER is always mysql here).
import 'package:dox_mysql_native/dox_mysql_native.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

import '../../dox-orm/test/belongs_to_test.dart' as belongs_to;
import '../../dox-orm/test/bug_fixes_test.dart' as bug_fixes;
import '../../dox-orm/test/computed_test.dart' as computed;
import '../../dox-orm/test/connection.dart';
import '../../dox-orm/test/has_many_test.dart' as has_many;
import '../../dox-orm/test/has_one_test.dart' as has_one;
import '../../dox-orm/test/many_to_many_test.dart' as many_to_many;
import '../../dox-orm/test/model_custom_table_name_test.dart' as custom_table;
import '../../dox-orm/test/model_events_test.dart' as model_events;
import '../../dox-orm/test/model_test.dart' as model;
import '../../dox-orm/test/schema_test.dart' as schema;
import '../../dox-orm/test/sql_query_builder_test.dart' as sql_query_builder;
import '../../dox-orm/test/transaction_test.dart' as transaction;

const List<Function> _suites = <Function>[
  belongs_to.main,
  bug_fixes.main,
  computed.main,
  has_many.main,
  has_one.main,
  many_to_many.main,
  custom_table.main,
  model_events.main,
  model.main,
  schema.main,
  sql_query_builder.main,
  transaction.main,
];

void main() async {
  databaseConfig.connection = 'mysql';
  for (Function suite in _suites) {
    // each main calls initQueryBuilder() and declares its tests
    await (Function.apply(suite, <Object?>[]) as Future<void>);
  }
  // the tests run after all are declared, so this driver runs them all
  SqlQueryBuilder().dbDriver = MysqlNativeDriver.fromConfig(
    databaseConfig.getConnectionConfig(),
  );
  test('the tests ran on MysqlNativeDriver', () {
    expect(SqlQueryBuilder().dbDriver, isA<MysqlNativeDriver>());
  });
}

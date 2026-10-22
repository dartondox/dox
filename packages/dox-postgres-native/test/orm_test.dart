// Runs the Postgres tests of dox_orm on PostgresNativeDriver.
//
//   DRIVER=postgres DB_PORT=5432 dart test test/orm_test.dart
//
// Each dox_orm test file calls `initQueryBuilder()` (the Dart driver) at
// the start of its `main`, before its first `await`. Right after that, this
// file puts the native driver in its place. So every test of the file runs
// on the native driver.
import 'dart:io';

import 'package:dox_orm/dox_orm.dart';
import 'package:dox_postgres_native/dox_postgres_native.dart';
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
import '../../dox-orm/test/sql_query_builder_test.dart' as query_builder;
import '../../dox-orm/test/transaction_test.dart' as transaction;

Map<String, dynamic Function()> suites = <String, dynamic Function()>{
  'belongs_to': belongs_to.main,
  'bug_fixes': bug_fixes.main,
  'computed': computed.main,
  'has_many': has_many.main,
  'has_one': has_one.main,
  'many_to_many': many_to_many.main,
  'custom_table': custom_table.main,
  'model_events': model_events.main,
  'model': model.main,
  'schema': schema.main,
  'query_builder': query_builder.main,
  'transaction': transaction.main,
};

void main() async {
  if (Platform.environment['DRIVER'] != 'postgres') {
    test('dox_orm on the native driver', () {}, skip: 'set DRIVER=postgres');
    return;
  }
  PostgresNativeDriver native = PostgresNativeDriver.fromConfig(
    databaseConfig.getConnectionConfig('postgres'),
  );
  for (dynamic Function() suite in suites.values) {
    Object? declared = suite();
    SqlQueryBuilder().dbDriver = native;
    if (declared is Future<Object?>) await declared;
  }
  test('the suites ran on the native driver', () {
    expect(SqlQueryBuilder().dbDriver, same(native));
  });
}

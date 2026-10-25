import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_migration/dox_migration.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:my_app/app/models/user/user.model.dart';
import 'package:test/test.dart';

import '../db/migration/migrations.dart';

/// One SQLite file for this test file. No server, no Postgres.
const String dbFile = 'storage/test.sqlite';

DatabaseConfig testDatabase = DatabaseConfig(
  connection: 'sqlite',
  connections: <String, ConnectionConfig>{
    'sqlite': ConnectionConfig(
      driver: Driver.sqlite,
      database: dbFile,
      debug: false,
    ),
  },
);

Future<void> deleteDbFile() async {
  for (String suffix in <String>['', '-wal', '-shm']) {
    File file = File('$dbFile$suffix');
    if (await file.exists()) await file.delete();
  }
}

void main() {
  setUpAll(() async {
    await deleteDbFile();
    await Migrator(
      migrations: migrations,
      config: testDatabase.getConnectionConfig(),
    ).migrate();
    SqlQueryBuilder.initializeWithDatabaseConfig(testDatabase);
  });

  // every test starts with an empty table
  setUp(() async {
    await User().truncate();
  });

  tearDownAll(() async {
    await deleteDbFile();
  });

  test('saves and finds a user', () async {
    User user = User()
      ..name = 'Ann'
      ..email = 'ann@example.com'
      ..password = Hash.make('secret123');
    await user.save();

    User? found = await User().where('email', 'ann@example.com').getFirst();
    expect(found?.id, user.id);
    expect(found?.name, 'Ann');
    expect(Hash.verify('secret123', found!.password!), isTrue);
  });

  test('the table is empty again', () async {
    expect(await User().count(), 0);
  });
}

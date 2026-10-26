import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_migration/dox_migration.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:dox_orm/testing.dart';
import 'package:my_app/app/http/controllers/user.controller.dart';
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

  // every test starts with empty tables
  setUp(refreshDatabase);

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

  test('the tables are empty again', () async {
    expect(await User().count(), 0);
  });

  test('destroy deletes a user once, then gives 404', () async {
    for (String name in <String>['Ann', 'Bob']) {
      await User().create(<String, dynamic>{
        'name': name,
        'email': '$name@example.com',
        'password': 'x',
      });
    }
    User? bob = await User().where('name', 'Bob').getFirst();
    UserController controller = UserController();
    expect(await controller.destroy(bob!.id!), <String, bool>{'deleted': true});

    /// soft deleted: the user is still in the table, but not found
    expect(await User().withTrash().count(), 2);
    await expectLater(
      controller.destroy(bob.id!),
      throwsA(isA<NotFoundHttpException>()),
    );

    /// forceDelete() gives the rows it deleted: 0 when the row is gone
    expect(await bob.forceDelete(), 1);
    expect(await bob.forceDelete(), 0);
  });
}

import 'package:dox_orm/dox_orm.dart';
import 'package:dox_orm/testing.dart';
import 'package:test/test.dart';

import 'connection.dart';

Future<int> count(String table) async {
  List<Map<String, dynamic>> rows = await QueryBuilder.table(table).get();
  return rows.length;
}

void main() async {
  await initQueryBuilder();

  setUpAll(() async {
    await Schema().dropIfExists('refresh_child');
    await Schema().dropIfExists('refresh_parent');
    await Schema().dropIfExists(migrationTable);
    await Schema().create('refresh_parent', (Table table) {
      table.id();
      table.string('name');
    });
    await Schema().create('refresh_child', (Table table) {
      table.id();
      table.foreignId('parent_id').constrained('refresh_parent');
    });
    await Schema().create(migrationTable, (Table table) {
      table.id();
      table.string('migration');
    });
  });

  tearDownAll(() async {
    await Schema().dropIfExists('refresh_child');
    await Schema().dropIfExists('refresh_parent');
    await Schema().dropIfExists(migrationTable);
  });

  test('empties every table, keeps the migrations table', () async {
    await QueryBuilder.table(migrationTable)
        .insert(<String, dynamic>{'migration': 'one'});
    await QueryBuilder.table('refresh_parent')
        .insert(<String, dynamic>{'name': 'a'});
    await QueryBuilder.table('refresh_child')
        .insert(<String, dynamic>{'parent_id': 1});

    await refreshDatabase();

    expect(await count('refresh_parent'), 0);
    expect(await count('refresh_child'), 0);
    expect(await count(migrationTable), 1);
  });

  test('ids start at 1 again', () async {
    await QueryBuilder.table('refresh_parent')
        .insert(<String, dynamic>{'name': 'b'});
    await refreshDatabase();
    await QueryBuilder.table('refresh_parent')
        .insert(<String, dynamic>{'name': 'c'});
    List<Map<String, dynamic>> rows = await QueryBuilder.table('refresh_parent')
        .get();
    expect(rows.single['id'], 1);
  });
}

import 'dart:io';

import 'package:dox_migration/dox_migration.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

/// names of the seeders that ran, in order
List<String> ran = <String>[];

class UserSeeder extends Seeder {
  @override
  Future<void> run() async {
    ran.add(name);
    await QueryBuilder.table('seed_user')
        .insert(<String, dynamic>{'name': 'jane'});
  }
}

class PostSeeder extends Seeder {
  @override
  Future<void> run() async {
    ran.add(name);
  }
}

class DatabaseSeeder extends Seeder {
  @override
  Future<void> run() async {
    ran.add(name);
    await call(<Seeder>[UserSeeder(), PostSeeder()]);
  }
}

class FailSeeder extends Seeder {
  @override
  Future<void> run() async {
    await QueryBuilder.table('seed_user')
        .insert(<String, dynamic>{'name': 'lost'});
    throw StateError('stop');
  }
}

class NoTransactionFailSeeder extends FailSeeder {
  @override
  bool get withinTransaction => false;
}

void main() {
  late Directory dir;
  late DatabaseConfig config;
  late SeederRunner runner;

  Future<List<String>> names() async {
    SqlQueryBuilder.initializeWithDatabaseConfig(config);
    try {
      List<Map<String, dynamic>> rows = await QueryBuilder.table('seed_user')
          .select('name')
          .orderBy('id')
          .get();
      return rows.map((Map<String, dynamic> r) => r['name'] as String).toList();
    } finally {
      await SqlQueryBuilder.close();
    }
  }

  setUp(() async {
    ran = <String>[];
    dir = Directory.systemTemp.createTempSync('dox_seeder_');
    config = DatabaseConfig(
      connection: 'sqlite',
      url: '',
      connections: <String, ConnectionConfig>{
        'sqlite': ConnectionConfig(
          driver: Driver.sqlite,
          database: '${dir.path}/seed.db',
          debug: false,
        ),
      },
    );
    runner = SeederRunner(
      config: config,
      seeders: <Seeder>[
        DatabaseSeeder(),
        UserSeeder(),
        FailSeeder(),
        NoTransactionFailSeeder(),
      ],
    );
    SqlQueryBuilder.initializeWithDatabaseConfig(config);
    await Schema().create('seed_user', (Table table) {
      table.id();
      table.string('name');
    });
    await SqlQueryBuilder.close();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('runs DatabaseSeeder and the seeders it calls', () async {
    expect(await runner.run(<String>[]), 0);
    expect(ran, <String>['DatabaseSeeder', 'UserSeeder', 'PostSeeder']);
    expect(await names(), <String>['jane']);
  });

  test('--class runs one seeder', () async {
    expect(await runner.run(<String>['--class=UserSeeder']), 0);
    expect(await runner.run(<String>['--class', 'UserSeeder']), 0);
    expect(ran, <String>['UserSeeder', 'UserSeeder']);
  });

  test('unknown seeder or option gives exit code 1', () async {
    expect(await runner.run(<String>['--class=Nope']), 1);
    expect(await runner.run(<String>['--force']), 1);
    expect(ran, isEmpty);
  });

  test('a failed seeder saves nothing', () async {
    expect(await runner.run(<String>['--class=FailSeeder']), 1);
    expect(await names(), isEmpty);
  });

  test('withinTransaction false keeps the rows before the error', () async {
    expect(await runner.run(<String>['--class=NoTransactionFailSeeder']), 1);
    expect(await names(), <String>['lost']);
  });
}

import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

import 'connection.dart';

/// create, alter and drop on a real database (DRIVER=postgres|mysql|sqlite)
void main() async {
  await initQueryBuilder();
  Schema schema = Schema();
  Driver driver = SqlQueryBuilder().dbDriver.getName();
  DBDriver db = SqlQueryBuilder().dbDriver;

  /// type, nullable and default of a column, read from the database
  Future<Map<String, dynamic>> column(String table, String name) async {
    if (driver == Driver.sqlite) {
      List<Map<String, dynamic>> rows = await db.query(
        'SELECT type, "notnull", dflt_value FROM pragma_table_info(@t) WHERE name = @c',
        substitutionValues: <String, dynamic>{'t': table, 'c': name},
      );
      return <String, dynamic>{
        'type': rows.first['type'].toString().toLowerCase(),
        'nullable': rows.first['notnull'] == 0,
        'default': rows.first['dflt_value'],
      };
    }
    String schemaName =
        driver == Driver.mysql ? 'DATABASE()' : 'current_schema()';
    String type = driver == Driver.mysql ? 'column_type' : 'data_type';
    List<Map<String, dynamic>> rows = await db.query(
      'SELECT $type AS t, is_nullable AS n, column_default AS d, '
      'character_maximum_length AS l FROM information_schema.columns '
      'WHERE table_schema = $schemaName AND table_name = @t AND column_name = @c',
      substitutionValues: <String, dynamic>{'t': table, 'c': name},
    );
    Map<String, dynamic> row = <String, dynamic>{
      for (MapEntry<String, dynamic> e in rows.first.entries)
        e.key.toLowerCase(): e.value,
    };
    return <String, dynamic>{
      'type': row['t'].toString().toLowerCase(),
      'nullable': row['n'] == 'YES',
      'default': row['d'],
      'length': row['l'],
    };
  }

  Future<void> insert(String table, Map<String, dynamic> values) {
    return QueryBuilder.table(table).insert(values);
  }

  Future<List<Map<String, dynamic>>> rows(String table) async {
    List<dynamic> list = await QueryBuilder.table(table).orderBy('id').get();
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> clean() async {
    for (String t in <String>['sch_post', 'sch_post2', 'sch_user', 'sch_all']) {
      await schema.dropIfExists(t);
    }
  }

  group('Schema |', () {
    setUp(clean);
    tearDown(clean);

    test('create with every type, read the rows back', () async {
      await schema.create('sch_all', (Table table) {
        table.id();
        table.string('s', 20);
        table.char('c', 2);
        table.text('t');
        table.mediumText('mt');
        table.longText('lt');
        table.integer('i');
        table.bigInteger('bi');
        table.smallInteger('si');
        table.tinyInteger('ti');
        table.unsignedInteger('ui');
        table.float('f');
        table.double('d');
        table.decimal('dec', 10, 3);
        table.boolean('b');
        table.date('dt');
        table.dateTime('dtm');
        table.dateTimeTz('dtz');
        table.time('tm');
        table.timestamp('ts');
        table.timestampTz('tsz');
        table.json('j');
        table.jsonb('jb');
        table.uuid('u');
        table.binary('bin').nullable();
        table.enumeration('e', <String>['a', 'b']);
        table.rememberToken();
        table.morphs('owner');
        table.softDeletes();
        table.timestamps();
      });
      expect(await schema.hasTable('sch_all'), isTrue);
      expect(await schema.hasTable('sch_nope'), isFalse);
      expect(await schema.hasColumn('sch_all', 'owner_type'), isTrue);
      expect(await schema.hasColumn('sch_all', 'nope'), isFalse);
      List<String> columns = await schema.getColumnListing('sch_all');
      expect(columns.first, 'id');
      expect(columns.last, 'updated_at');

      DateTime now = DateTime.utc(2026, 1, 2, 3, 4, 5);
      await insert('sch_all', <String, dynamic>{
        's': 'hello',
        'c': 'ab',
        't': 'text',
        'mt': 'medium',
        'lt': 'long',
        'i': 1,
        'bi': 9007199254740991,
        'si': 2,
        'ti': 3,
        'ui': 4,
        'f': 1.5,
        'd': 2.25,
        'dec': 12.34,
        'b': true,
        'dt': now,
        'dtm': now,
        'dtz': now,
        'tm': '10:11:12',
        'ts': now,
        'tsz': now,
        'j': <String, dynamic>{'a': 1},
        'jb': <String, dynamic>{
          'k': <int>[1, 2],
        },
        'u': '6f1c8d2e-4b7a-4e3f-9c1d-2a5b6c7d8e9f',
        'e': 'b',
        'owner_id': 7,
        'owner_type': 'user',
      });
      Map<String, dynamic> row = (await rows('sch_all')).single;
      expect(row['id'], 1);
      expect(row['s'], 'hello');
      expect(row['bi'], 9007199254740991);
      expect(row['b'], true);
      expect(row['f'], 1.5);
      expect(row['d'], 2.25);
      expect(double.parse(row['dec'].toString()), 12.34);
      expect(row['j'], <String, dynamic>{'a': 1});
      expect(row['jb'], <String, dynamic>{
        'k': <int>[1, 2],
      });
      expect(row['e'], 'b');
      expect(row['u'].toString(), '6f1c8d2e-4b7a-4e3f-9c1d-2a5b6c7d8e9f');
      expect(row['remember_token'], null);
      expect(row['deleted_at'], null);
      expect(DateTime.parse(row['tsz'].toString()).toUtc(), now);
      expect((row['b'] as bool), isTrue);

      expect((await column('sch_all', 's'))['nullable'], isFalse);
      expect((await column('sch_all', 'bin'))['nullable'], isTrue);
      String ui = (await column('sch_all', 'ui'))['type'];
      expect(ui, startsWith(driver == Driver.mysql ? 'int' : 'integer'));
      if (driver == Driver.mysql) expect(ui, endsWith('unsigned'));
      expect(
        (await column('sch_all', 'jb'))['type'],
        <Driver, Matcher>{
          Driver.postgres: equals('jsonb'),

          /// mariadb json is a longtext alias
          Driver.mysql: anyOf('json', 'longtext'),
          Driver.sqlite: equals('json'),
        }[driver],
      );
    });

    test('defaults and escaping', () async {
      await schema.create('sch_all', (Table table) {
        table.id();
        table.string('s').defaultTo(r"it's \ ok");
        table.integer('i').defaultTo(5);
        table.boolean('b').defaultTo(false);
        table.json('j').defaultTo(<String, dynamic>{'x': "y'z"});
        table.text('t').defaultTo('');
        table.enumeration('e', <String>['draft', 'done']).defaultTo('draft');
        table.timestamp('at').useCurrent();
        table.string('n').nullable().defaultTo(null);
        table.integer('r').defaultRaw('(1 + 1)');
      });
      await insert('sch_all', <String, dynamic>{'id': 1});
      Map<String, dynamic> row = (await rows('sch_all')).single;
      expect(row['s'], r"it's \ ok");
      expect(row['i'], 5);
      expect(row['b'], false);
      expect(row['j'], <String, dynamic>{'x': "y'z"});
      expect(row['t'], '');
      expect(row['e'], 'draft');
      expect(row['at'], isNotNull);
      expect(row['n'], null);
      expect(row['r'], 2);
    });

    test('unique, index, enum check and nullable are enforced', () async {
      await schema.create('sch_all', (Table table) {
        table.id();
        table.string('email').unique();
        table.string('name').index();
        table.enumeration('e', <String>['a', 'b']);
        table.integer('a');
        table.integer('b');
        table.unique(<String>['a', 'b']);
      });
      await insert('sch_all', <String, dynamic>{
        'email': 'x',
        'name': 'n',
        'e': 'a',
        'a': 1,
        'b': 1,
      });
      await expectLater(
        insert('sch_all', <String, dynamic>{
          'email': 'x',
          'name': 'n',
          'e': 'a',
          'a': 2,
          'b': 2,
        }),
        throwsA(anything),
      );
      await expectLater(
        insert('sch_all', <String, dynamic>{
          'email': 'y',
          'name': 'n',
          'e': 'a',
          'a': 1,
          'b': 1,
        }),
        throwsA(anything),
      );
      await expectLater(
        insert('sch_all', <String, dynamic>{
          'email': 'z',
          'name': 'n',
          'e': 'zzz',
          'a': 3,
          'b': 3,
        }),
        throwsA(anything),
      );
      await expectLater(
        insert('sch_all', <String, dynamic>{
          'email': null,
          'name': 'n',
          'e': 'a',
          'a': 4,
          'b': 4,
        }),
        throwsA(anything),
      );

      /// the indexes exist, so they can be dropped
      await schema.table('sch_all', (Table table) {
        table.dropUnique(<String>['email']);
        table.dropIndex(<String>['name']);
        table.dropUnique(<String>['a', 'b']);
      });
      await insert('sch_all', <String, dynamic>{
        'email': 'x',
        'name': 'n',
        'e': 'b',
        'a': 1,
        'b': 1,
      });
      expect((await rows('sch_all')).length, 2);
    });

    test('foreign keys: constrained, cascade, set null', () async {
      await schema.create('sch_user', (Table table) {
        table.id();
        table.string('name');
      });
      await schema.create('sch_post', (Table table) {
        table.id();
        table.foreignId('user_id').constrained('sch_user').cascadeOnDelete();
        table
            .foreignId('editor_id')
            .nullable()
            .constrained('sch_user')
            .nullOnDelete();
      });
      await insert('sch_user', <String, dynamic>{'name': 'a'});
      await insert('sch_user', <String, dynamic>{'name': 'b'});
      await insert('sch_post', <String, dynamic>{'user_id': 1, 'editor_id': 2});
      await expectLater(
        insert('sch_post', <String, dynamic>{'user_id': 99}),
        throwsA(anything),
      );
      await QueryBuilder.table('sch_user').where('id', 2).delete();
      expect((await rows('sch_post')).single['editor_id'], null);
      await QueryBuilder.table('sch_user').where('id', 1).delete();
      expect(await rows('sch_post'), isEmpty);
    });

    test('alter: add, change, rename, drop columns, keep rows', () async {
      await schema.create('sch_post', (Table table) {
        table.id();
        table.string('title', 10);
        table.string('status').defaultTo('active');
        table.enumeration('kind', <String>['a', 'b']);
        table.text('old');
        table.text('x1').nullable();
        table.text('x2').nullable();
      });
      await insert('sch_post', <String, dynamic>{
        'title': 'hello',
        'kind': 'a',
        'old': 'o',
      });

      await schema.table('sch_post', (Table table) {
        table.string('slug').nullable().after('title');
        table.integer('views').defaultTo(0);
        table.string('title', 100).nullable().change();
        table.string('status').defaultTo("pend'ing").change();
        table.enumeration('kind', <String>['a', 'b', 'c']).change();
        table.renameColumn('old', 'body');
        table.dropColumns(<String>['x1', 'x2']);
      });

      expect(await schema.getColumnListing('sch_post'), <String>[
        'id',
        'title',
        if (driver == Driver.mysql) 'slug',
        'status',
        'kind',
        'body',
        if (driver != Driver.mysql) 'slug',
        'views',
      ]);
      Map<String, dynamic> title = await column('sch_post', 'title');
      expect(title['nullable'], isTrue);
      if (driver == Driver.sqlite) {
        expect(title['type'], 'varchar(100)');
      } else {
        expect(int.parse(title['length'].toString()), 100);
      }

      Map<String, dynamic> row = (await rows('sch_post')).single;
      expect(row['title'], 'hello');
      expect(row['views'], 0);
      expect(row['body'], 'o');
      expect(row['kind'], 'a');

      await insert('sch_post', <String, dynamic>{
        'title': null,
        'kind': 'c',
        'body': 'b',
      });
      row = (await rows('sch_post')).last;
      expect(row['status'], "pend'ing");
      expect(row['kind'], 'c');
      expect(row['id'], 2);
      await expectLater(
        insert('sch_post', <String, dynamic>{'kind': 'zzz', 'body': 'b'}),
        throwsA(anything),
      );
    });

    test('alter: add and drop a foreign key on an existing table', () async {
      await schema.create('sch_user', (Table table) {
        table.id();
      });
      await schema.create('sch_post', (Table table) {
        table.id();
        table.unsignedBigInteger('user_id');
        table.string('code').unique();
      });
      await insert('sch_user', <String, dynamic>{'id': 1});
      await insert('sch_post', <String, dynamic>{'user_id': 1, 'code': 'a'});

      await schema.table('sch_post', (Table table) {
        table.foreign('user_id').references('id').on('sch_user');
      });
      await expectLater(
        insert('sch_post', <String, dynamic>{'user_id': 9, 'code': 'b'}),
        throwsA(anything),
      );

      await schema.table('sch_post', (Table table) {
        table.dropForeign(<String>['user_id']);
      });
      await insert('sch_post', <String, dynamic>{'user_id': 9, 'code': 'b'});

      /// the unique index is still there after a sqlite rebuild
      await expectLater(
        insert('sch_post', <String, dynamic>{'user_id': 1, 'code': 'b'}),
        throwsA(anything),
      );
      expect((await rows('sch_post')).length, 2);
    });

    test('change with unique and index', () async {
      await schema.create('sch_post', (Table table) {
        table.id();
        table.string('slug').nullable();
      });
      await schema.table('sch_post', (Table table) {
        table.string('slug').nullable().unique().change();
      });
      await insert('sch_post', <String, dynamic>{'slug': 'a'});
      await expectLater(
        insert('sch_post', <String, dynamic>{'slug': 'a'}),
        throwsA(anything),
      );
    });

    test('primary key on two columns', () async {
      await schema.create('sch_post', (Table table) {
        table.integer('a');
        table.integer('b');
        table.primary(<String>['a', 'b']);
      });

      /// raw sql, the query builder insert asks for an `id` back
      Future<void> add(int a, int b) {
        return db.execute('INSERT INTO sch_post (a, b) VALUES ($a, $b)');
      }

      await add(1, 1);
      await add(1, 2);
      await expectLater(
        add(1, 1),
        throwsA(anything),
      );
    });

    test('rename, drop, dropIfExists', () async {
      await schema.create('sch_post', (Table table) {
        table.id();
      });
      await schema.rename('sch_post', 'sch_post2');
      expect(await schema.hasTable('sch_post'), isFalse);
      expect(await schema.hasTable('sch_post2'), isTrue);
      await schema.drop('sch_post2');
      expect(await schema.hasTable('sch_post2'), isFalse);
      await expectLater(schema.drop('sch_post2'), throwsA(anything));
      await schema.dropIfExists('sch_post2');
    });

    test('create fails when the table exists', () async {
      await schema.create('sch_post', (Table table) => table.id());
      await expectLater(
        schema.create('sch_post', (Table table) => table.id()),
        throwsA(anything),
      );
    });
  });
}

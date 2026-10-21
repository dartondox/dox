import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

/// sql of each schema method per driver, no database needed
void main() {
  const SchemaGrammar pg = PostgresGrammar();
  const SchemaGrammar my = MysqlGrammar();
  const SchemaGrammar lite = SqliteGrammar();

  /// sql of one new column on [g]
  String col(SchemaGrammar g, void Function(Table t) build) {
    Table t = Table('t', creating: true);
    build(t);
    String sql = g.compile(t).first;
    return sql.substring(
      'CREATE TABLE ${g.wrap('t')} ('.length,
      sql.length - 1,
    );
  }

  /// all sql of `Schema.table('t', build)` on [g]
  List<String> alter(SchemaGrammar g, void Function(Table t) build) {
    Table t = Table('t');
    build(t);
    return g.compile(t);
  }

  /// all sql of `Schema.create('t', build)` on [g]
  List<String> create(SchemaGrammar g, void Function(Table t) build) {
    Table t = Table('t', creating: true);
    build(t);
    return g.compile(t);
  }

  /// [expected] per driver: postgres, mysql, sqlite
  void types(void Function(Table t) build, List<String> expected) {
    expect(<String>[
      col(pg, build),
      col(my, build),
      col(lite, build),
    ], expected);
  }

  test('grammar for driver', () {
    expect(SchemaGrammar.of(Driver.postgres), isA<PostgresGrammar>());
    expect(SchemaGrammar.of(Driver.mysql), isA<MysqlGrammar>());
    expect(SchemaGrammar.of(Driver.sqlite), isA<SqliteGrammar>());
  });

  group('column types |', () {
    test('id, bigIncrements, increments', () {
      types((Table t) => t.id(), <String>[
        '"id" BIGSERIAL NOT NULL PRIMARY KEY',
        '`id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY',
        '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT',
      ]);
      types((Table t) => t.bigIncrements('n'), <String>[
        '"n" BIGSERIAL NOT NULL PRIMARY KEY',
        '`n` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY',
        '"n" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT',
      ]);
      types((Table t) => t.increments('n'), <String>[
        '"n" SERIAL NOT NULL PRIMARY KEY',
        '`n` INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY',
        '"n" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT',
      ]);
    });

    test('string and char', () {
      types((Table t) => t.string('n'), <String>[
        '"n" VARCHAR(255) NOT NULL',
        '`n` VARCHAR(255) NOT NULL',
        '"n" VARCHAR(255) NOT NULL',
      ]);
      types((Table t) => t.string('n', 50), <String>[
        '"n" VARCHAR(50) NOT NULL',
        '`n` VARCHAR(50) NOT NULL',
        '"n" VARCHAR(50) NOT NULL',
      ]);
      types((Table t) => t.char('n', 2), <String>[
        '"n" CHAR(2) NOT NULL',
        '`n` CHAR(2) NOT NULL',
        '"n" CHAR(2) NOT NULL',
      ]);
    });

    test('text, mediumText, longText', () {
      types((Table t) => t.text('n'), <String>[
        '"n" TEXT NOT NULL',
        '`n` TEXT NOT NULL',
        '"n" TEXT NOT NULL',
      ]);
      types((Table t) => t.mediumText('n'), <String>[
        '"n" TEXT NOT NULL',
        '`n` MEDIUMTEXT NOT NULL',
        '"n" TEXT NOT NULL',
      ]);
      types((Table t) => t.longText('n'), <String>[
        '"n" TEXT NOT NULL',
        '`n` LONGTEXT NOT NULL',
        '"n" TEXT NOT NULL',
      ]);
    });

    test('integers', () {
      types((Table t) => t.integer('n'), <String>[
        '"n" INTEGER NOT NULL',
        '`n` INT NOT NULL',
        '"n" INTEGER NOT NULL',
      ]);
      types((Table t) => t.bigInteger('n'), <String>[
        '"n" BIGINT NOT NULL',
        '`n` BIGINT NOT NULL',
        '"n" INTEGER NOT NULL',
      ]);
      types((Table t) => t.smallInteger('n'), <String>[
        '"n" SMALLINT NOT NULL',
        '`n` SMALLINT NOT NULL',
        '"n" INTEGER NOT NULL',
      ]);
      types((Table t) => t.tinyInteger('n'), <String>[
        '"n" SMALLINT NOT NULL',
        '`n` TINYINT NOT NULL',
        '"n" INTEGER NOT NULL',
      ]);
    });

    test('unsigned integers', () {
      types((Table t) => t.unsignedInteger('n'), <String>[
        '"n" INTEGER NOT NULL',
        '`n` INT UNSIGNED NOT NULL',
        '"n" INTEGER NOT NULL',
      ]);
      types((Table t) => t.unsignedBigInteger('n'), <String>[
        '"n" BIGINT NOT NULL',
        '`n` BIGINT UNSIGNED NOT NULL',
        '"n" INTEGER NOT NULL',
      ]);
      types((Table t) => t.unsignedSmallInteger('n'), <String>[
        '"n" SMALLINT NOT NULL',
        '`n` SMALLINT UNSIGNED NOT NULL',
        '"n" INTEGER NOT NULL',
      ]);
      types((Table t) => t.unsignedTinyInteger('n'), <String>[
        '"n" SMALLINT NOT NULL',
        '`n` TINYINT UNSIGNED NOT NULL',
        '"n" INTEGER NOT NULL',
      ]);
      types((Table t) => t.integer('n').unsigned(), <String>[
        '"n" INTEGER NOT NULL',
        '`n` INT UNSIGNED NOT NULL',
        '"n" INTEGER NOT NULL',
      ]);
    });

    test('float, double, decimal', () {
      types((Table t) => t.float('n'), <String>[
        '"n" REAL NOT NULL',
        '`n` FLOAT NOT NULL',
        '"n" FLOAT NOT NULL',
      ]);
      types((Table t) => t.double('n'), <String>[
        '"n" DOUBLE PRECISION NOT NULL',
        '`n` DOUBLE NOT NULL',
        '"n" DOUBLE NOT NULL',
      ]);
      types((Table t) => t.decimal('n'), <String>[
        '"n" DECIMAL(8, 2) NOT NULL',
        '`n` DECIMAL(8, 2) NOT NULL',
        '"n" DECIMAL(8, 2) NOT NULL',
      ]);
      types((Table t) => t.decimal('n', 10, 4), <String>[
        '"n" DECIMAL(10, 4) NOT NULL',
        '`n` DECIMAL(10, 4) NOT NULL',
        '"n" DECIMAL(10, 4) NOT NULL',
      ]);
    });

    test('boolean', () {
      types((Table t) => t.boolean('n'), <String>[
        '"n" BOOLEAN NOT NULL',
        '`n` TINYINT(1) NOT NULL',
        '"n" BOOLEAN NOT NULL',
      ]);
    });

    test('dates and times', () {
      types((Table t) => t.date('n'), <String>[
        '"n" DATE NOT NULL',
        '`n` DATE NOT NULL',
        '"n" DATE NOT NULL',
      ]);
      types((Table t) => t.dateTime('n'), <String>[
        '"n" TIMESTAMP NOT NULL',
        '`n` DATETIME NOT NULL',
        '"n" DATETIME NOT NULL',
      ]);
      types((Table t) => t.dateTimeTz('n'), <String>[
        '"n" TIMESTAMPTZ NOT NULL',
        '`n` DATETIME NOT NULL',
        '"n" DATETIME NOT NULL',
      ]);
      types((Table t) => t.time('n'), <String>[
        '"n" TIME NOT NULL',
        '`n` TIME NOT NULL',
        '"n" TIME NOT NULL',
      ]);
      types((Table t) => t.timestamp('n'), <String>[
        '"n" TIMESTAMP NOT NULL',
        '`n` TIMESTAMP NOT NULL',
        '"n" TIMESTAMP NOT NULL',
      ]);
      types((Table t) => t.timestampTz('n'), <String>[
        '"n" TIMESTAMPTZ NOT NULL',
        '`n` TIMESTAMP NOT NULL',
        '"n" TIMESTAMP NOT NULL',
      ]);
    });

    test('json, jsonb', () {
      types((Table t) => t.json('n'), <String>[
        '"n" JSONB NOT NULL',
        '`n` JSON NOT NULL',
        '"n" JSON NOT NULL',
      ]);
      types((Table t) => t.jsonb('n'), <String>[
        '"n" JSONB NOT NULL',
        '`n` JSON NOT NULL',
        '"n" JSON NOT NULL',
      ]);
    });

    test('uuid, binary', () {
      types((Table t) => t.uuid(), <String>[
        '"uuid" UUID NOT NULL',
        '`uuid` CHAR(36) NOT NULL',
        '"uuid" TEXT NOT NULL',
      ]);
      types((Table t) => t.binary('n'), <String>[
        '"n" BYTEA NOT NULL',
        '`n` BLOB NOT NULL',
        '"n" BLOB NOT NULL',
      ]);
    });

    test('enumeration', () {
      types((Table t) => t.enumeration('n', <String>['a', "b'c"]), <String>[
        '"n" VARCHAR(255) NOT NULL CHECK ("n" IN (\'a\', \'b\'\'c\'))',
        "`n` ENUM('a', 'b''c') NOT NULL",
        '"n" VARCHAR(255) NOT NULL CHECK ("n" IN (\'a\', \'b\'\'c\'))',
      ]);
    });

    test('foreignId and foreignUuid', () {
      types((Table t) => t.foreignId('user_id'), <String>[
        '"user_id" BIGINT NOT NULL',
        '`user_id` BIGINT UNSIGNED NOT NULL',
        '"user_id" INTEGER NOT NULL',
      ]);
      types((Table t) => t.foreignUuid('user_id'), <String>[
        '"user_id" UUID NOT NULL',
        '`user_id` CHAR(36) NOT NULL',
        '"user_id" TEXT NOT NULL',
      ]);
    });

    test('timestamps, softDeletes, rememberToken', () {
      types((Table t) => t.timestamps(), <String>[
        '"created_at" TIMESTAMPTZ, "updated_at" TIMESTAMPTZ',
        '`created_at` TIMESTAMP NULL, `updated_at` TIMESTAMP NULL',
        '"created_at" TIMESTAMP, "updated_at" TIMESTAMP',
      ]);
      types((Table t) => t.softDeletes(), <String>[
        '"deleted_at" TIMESTAMPTZ',
        '`deleted_at` TIMESTAMP NULL',
        '"deleted_at" TIMESTAMP',
      ]);
      types((Table t) => t.rememberToken(), <String>[
        '"remember_token" VARCHAR(100)',
        '`remember_token` VARCHAR(100) NULL',
        '"remember_token" VARCHAR(100)',
      ]);
    });

    test('morphs', () {
      void build(Table t) => t.morphs('owner');
      expect(create(pg, build), <String>[
        'CREATE TABLE "t" ("owner_id" BIGINT NOT NULL, "owner_type" VARCHAR(255) NOT NULL)',
        'CREATE INDEX "t_owner_type_owner_id_index" ON "t" ("owner_type", "owner_id")',
      ]);
      expect(create(my, build), <String>[
        'CREATE TABLE `t` (`owner_id` BIGINT UNSIGNED NOT NULL, `owner_type` VARCHAR(255) NOT NULL)',
        'CREATE INDEX `t_owner_type_owner_id_index` ON `t` (`owner_type`, `owner_id`)',
      ]);
      expect(create(lite, build), <String>[
        'CREATE TABLE "t" ("owner_id" INTEGER NOT NULL, "owner_type" VARCHAR(255) NOT NULL)',
        'CREATE INDEX "t_owner_type_owner_id_index" ON "t" ("owner_type", "owner_id")',
      ]);
    });
  });

  group('modifiers |', () {
    test('nullable', () {
      types((Table t) => t.string('n').nullable(), <String>[
        '"n" VARCHAR(255)',
        '`n` VARCHAR(255) NULL',
        '"n" VARCHAR(255)',
      ]);
      types((Table t) => t.string('n').nullable().nullable(false), <String>[
        '"n" VARCHAR(255) NOT NULL',
        '`n` VARCHAR(255) NOT NULL',
        '"n" VARCHAR(255) NOT NULL',
      ]);
    });

    test('defaultTo escapes strings', () {
      types((Table t) => t.string('n').defaultTo(r"it's \ ok"), <String>[
        '"n" VARCHAR(255) NOT NULL DEFAULT \'it\'\'s \\ ok\'',
        '`n` VARCHAR(255) NOT NULL DEFAULT \'it\'\'s \\\\ ok\'',
        '"n" VARCHAR(255) NOT NULL DEFAULT \'it\'\'s \\ ok\'',
      ]);
      types((Table t) => t.string('n').withDefault('a'), <String>[
        '"n" VARCHAR(255) NOT NULL DEFAULT \'a\'',
        '`n` VARCHAR(255) NOT NULL DEFAULT \'a\'',
        '"n" VARCHAR(255) NOT NULL DEFAULT \'a\'',
      ]);
    });

    test('defaultTo numbers, bool, null, json', () {
      types((Table t) => t.integer('n').defaultTo(5), <String>[
        '"n" INTEGER NOT NULL DEFAULT 5',
        '`n` INT NOT NULL DEFAULT 5',
        '"n" INTEGER NOT NULL DEFAULT 5',
      ]);
      types((Table t) => t.decimal('n').defaultTo(1.5), <String>[
        '"n" DECIMAL(8, 2) NOT NULL DEFAULT 1.5',
        '`n` DECIMAL(8, 2) NOT NULL DEFAULT 1.5',
        '"n" DECIMAL(8, 2) NOT NULL DEFAULT 1.5',
      ]);
      types((Table t) => t.boolean('n').defaultTo(false), <String>[
        '"n" BOOLEAN NOT NULL DEFAULT FALSE',
        '`n` TINYINT(1) NOT NULL DEFAULT 0',
        '"n" BOOLEAN NOT NULL DEFAULT FALSE',
      ]);
      types((Table t) => t.string('n').nullable().defaultTo(null), <String>[
        '"n" VARCHAR(255) DEFAULT NULL',
        '`n` VARCHAR(255) NULL DEFAULT NULL',
        '"n" VARCHAR(255) DEFAULT NULL',
      ]);
      types(
        (Table t) => t.json('n').defaultTo(<String, Object>{
          'a': <int>[1],
        }),
        <String>[
          '"n" JSONB NOT NULL DEFAULT \'{"a":[1]}\'',
          '`n` JSON NOT NULL DEFAULT (\'{"a":[1]}\')',
          '"n" JSON NOT NULL DEFAULT \'{"a":[1]}\'',
        ],
      );
      types((Table t) => t.text('n').defaultTo(''), <String>[
        '"n" TEXT NOT NULL DEFAULT \'\'',
        '`n` TEXT NOT NULL DEFAULT (\'\')',
        '"n" TEXT NOT NULL DEFAULT \'\'',
      ]);
    });

    test('defaultRaw, useCurrent, useCurrentOnUpdate', () {
      types((Table t) => t.integer('n').defaultRaw('1 + 1'), <String>[
        '"n" INTEGER NOT NULL DEFAULT 1 + 1',
        '`n` INT NOT NULL DEFAULT 1 + 1',
        '"n" INTEGER NOT NULL DEFAULT 1 + 1',
      ]);
      types((Table t) => t.timestamp('n').useCurrent(), <String>[
        '"n" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP',
        '`n` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP',
        '"n" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP',
      ]);
      types(
        (Table t) => t.timestamp('n').useCurrent().useCurrentOnUpdate(),
        <String>[
          '"n" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP',
          '`n` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP',
          '"n" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP',
        ],
      );
    });

    test('primary', () {
      types((Table t) => t.string('code').primary(), <String>[
        '"code" VARCHAR(255) NOT NULL PRIMARY KEY',
        '`code` VARCHAR(255) NOT NULL PRIMARY KEY',
        '"code" VARCHAR(255) NOT NULL PRIMARY KEY',
      ]);
    });

    test('unique and index make an index', () {
      void build(Table t) {
        t.string('email').unique();
        t.string('name').index();
      }

      expect(create(pg, build).sublist(1), <String>[
        'CREATE UNIQUE INDEX "t_email_unique" ON "t" ("email")',
        'CREATE INDEX "t_name_index" ON "t" ("name")',
      ]);
      expect(create(my, build).sublist(1), <String>[
        'CREATE UNIQUE INDEX `t_email_unique` ON `t` (`email`)',
        'CREATE INDEX `t_name_index` ON `t` (`name`)',
      ]);
      expect(create(lite, build).sublist(1), <String>[
        'CREATE UNIQUE INDEX "t_email_unique" ON "t" ("email")',
        'CREATE INDEX "t_name_index" ON "t" ("name")',
      ]);
    });

    test('comment', () {
      void build(Table t) => t.string('n').comment("it's");
      expect(create(pg, build), <String>[
        'CREATE TABLE "t" ("n" VARCHAR(255) NOT NULL)',
        'COMMENT ON COLUMN "t"."n" IS \'it\'\'s\'',
      ]);
      expect(create(my, build), <String>[
        "CREATE TABLE `t` (`n` VARCHAR(255) NOT NULL COMMENT 'it''s')",
      ]);
      expect(create(lite, build), <String>[
        'CREATE TABLE "t" ("n" VARCHAR(255) NOT NULL)',
      ]);
    });

    test('after is mysql only and only in alter', () {
      void build(Table t) => t.string('n').nullable().after('id');
      expect(alter(pg, build), <String>[
        'ALTER TABLE "t" ADD COLUMN "n" VARCHAR(255)',
      ]);
      expect(alter(my, build), <String>[
        'ALTER TABLE `t` ADD COLUMN `n` VARCHAR(255) NULL AFTER `id`',
      ]);
      expect(alter(lite, build), <String>[
        'ALTER TABLE "t" ADD COLUMN "n" VARCHAR(255)',
      ]);
      expect(col(my, build), '`n` VARCHAR(255) NULL');
    });

    test('names are quoted', () {
      types((Table t) => t.string('a"b`c'), <String>[
        '"a""b`c" VARCHAR(255) NOT NULL',
        '`a"b``c` VARCHAR(255) NOT NULL',
        '"a""b`c" VARCHAR(255) NOT NULL',
      ]);
    });
  });

  group('create |', () {
    test('composite primary key', () {
      void build(Table t) {
        t.integer('a');
        t.integer('b');
        t.primary(<String>['a', 'b']);
      }

      expect(create(pg, build), <String>[
        'CREATE TABLE "t" ("a" INTEGER NOT NULL, "b" INTEGER NOT NULL, PRIMARY KEY ("a", "b"))',
      ]);
      expect(create(my, build), <String>[
        'CREATE TABLE `t` (`a` INT NOT NULL, `b` INT NOT NULL, PRIMARY KEY (`a`, `b`))',
      ]);
      expect(create(lite, build), <String>[
        'CREATE TABLE "t" ("a" INTEGER NOT NULL, "b" INTEGER NOT NULL, PRIMARY KEY ("a", "b"))',
      ]);
    });

    test('foreign keys are inline', () {
      void build(Table t) {
        t.foreignId('user_id').constrained().cascadeOnDelete();
        t
            .foreignId('category_id')
            .nullable()
            .constrained('cats')
            .nullOnDelete();
        t.integer('a');
        t.foreign('a', 'my_fk').references('x').on('other').onUpdate('cascade');
      }

      expect(create(pg, build), <String>[
        'CREATE TABLE "t" ("user_id" BIGINT NOT NULL, "category_id" BIGINT, "a" INTEGER NOT NULL, '
            'CONSTRAINT "t_user_id_foreign" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE CASCADE, '
            'CONSTRAINT "t_category_id_foreign" FOREIGN KEY ("category_id") REFERENCES "cats" ("id") ON DELETE SET NULL, '
            'CONSTRAINT "my_fk" FOREIGN KEY ("a") REFERENCES "other" ("x") ON UPDATE CASCADE)',
      ]);
      expect(create(my, build), <String>[
        'CREATE TABLE `t` (`user_id` BIGINT UNSIGNED NOT NULL, `category_id` BIGINT UNSIGNED NULL, `a` INT NOT NULL, '
            'CONSTRAINT `t_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE, '
            'CONSTRAINT `t_category_id_foreign` FOREIGN KEY (`category_id`) REFERENCES `cats` (`id`) ON DELETE SET NULL, '
            'CONSTRAINT `my_fk` FOREIGN KEY (`a`) REFERENCES `other` (`x`) ON UPDATE CASCADE)',
      ]);
      expect(create(lite, build), <String>[
        'CREATE TABLE "t" ("user_id" INTEGER NOT NULL, "category_id" INTEGER, "a" INTEGER NOT NULL, '
            'FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE CASCADE, '
            'FOREIGN KEY ("category_id") REFERENCES "cats" ("id") ON DELETE SET NULL, '
            'FOREIGN KEY ("a") REFERENCES "other" ("x") ON UPDATE CASCADE)',
      ]);
    });

    test('foreignId references().on()', () {
      void build(Table t) {
        t.foreignId('owner').references('uid').on('people').restrictOnDelete();
      }

      expect(
        create(pg, build).first,
        endsWith(
          'CONSTRAINT "t_owner_foreign" FOREIGN KEY ("owner") REFERENCES "people" ("uid") ON DELETE RESTRICT)',
        ),
      );
    });

    test('foreign without on() throws', () {
      expect(() => create(pg, (Table t) => t.foreign('a')), throwsStateError);
    });

    test('constrained guesses the table', () {
      expect(ForeignIdColumnDefinition.guessTable('user_id'), 'users');
      expect(ForeignIdColumnDefinition.guessTable('category_id'), 'categories');
      expect(ForeignIdColumnDefinition.guessTable('box_id'), 'boxes');
      expect(ForeignIdColumnDefinition.guessTable('day_id'), 'days');
      expect(ForeignIdColumnDefinition.guessTable('author'), 'authors');
    });

    test('index commands', () {
      void build(Table t) {
        t.string('a');
        t.string('b');
        t.index(<String>['a', 'b']);
        t.unique('a', 'a_uq');
      }

      expect(create(pg, build).sublist(1), <String>[
        'CREATE INDEX "t_a_b_index" ON "t" ("a", "b")',
        'CREATE UNIQUE INDEX "a_uq" ON "t" ("a")',
      ]);
      expect(create(my, build).sublist(1), <String>[
        'CREATE INDEX `t_a_b_index` ON `t` (`a`, `b`)',
        'CREATE UNIQUE INDEX `a_uq` ON `t` (`a`)',
      ]);
      expect(create(lite, build).sublist(1), <String>[
        'CREATE INDEX "t_a_b_index" ON "t" ("a", "b")',
        'CREATE UNIQUE INDEX "a_uq" ON "t" ("a")',
      ]);
    });
  });

  group('alter |', () {
    test('add columns: one statement on postgres and mysql', () {
      void build(Table t) {
        t.string('a').nullable();
        t.integer('b').defaultTo(0);
      }

      expect(alter(pg, build), <String>[
        'ALTER TABLE "t" ADD COLUMN "a" VARCHAR(255), ADD COLUMN "b" INTEGER NOT NULL DEFAULT 0',
      ]);
      expect(alter(my, build), <String>[
        'ALTER TABLE `t` ADD COLUMN `a` VARCHAR(255) NULL, ADD COLUMN `b` INT NOT NULL DEFAULT 0',
      ]);
      expect(alter(lite, build), <String>[
        'ALTER TABLE "t" ADD COLUMN "a" VARCHAR(255)',
        'ALTER TABLE "t" ADD COLUMN "b" INTEGER NOT NULL DEFAULT 0',
      ]);
    });

    test('add a unique column adds a unique index', () {
      void build(Table t) => t.string('a').nullable().unique();
      expect(alter(lite, build), <String>[
        'ALTER TABLE "t" ADD COLUMN "a" VARCHAR(255)',
        'CREATE UNIQUE INDEX "t_a_unique" ON "t" ("a")',
      ]);
    });

    test('change', () {
      void build(Table t) {
        t.string('a', 100).nullable().defaultTo('x').change();
      }

      expect(alter(pg, build), <String>[
        'ALTER TABLE "t" ALTER COLUMN "a" TYPE VARCHAR(100) USING "a"::VARCHAR(100), '
            'ALTER COLUMN "a" DROP NOT NULL, '
            'ALTER COLUMN "a" SET DEFAULT \'x\', '
            'DROP CONSTRAINT IF EXISTS "t_a_check"',
      ]);
      expect(alter(my, build), <String>[
        "ALTER TABLE `t` MODIFY COLUMN `a` VARCHAR(100) NULL DEFAULT 'x'",
      ]);
      expect(() => alter(lite, build), throwsUnsupportedError);
    });

    test('change: not null, no default, unique, comment', () {
      void build(Table t) => t.integer('a').unique().comment('c').change();
      expect(alter(pg, build), <String>[
        'ALTER TABLE "t" ALTER COLUMN "a" TYPE INTEGER USING "a"::INTEGER, '
            'ALTER COLUMN "a" SET NOT NULL, '
            'ALTER COLUMN "a" DROP DEFAULT, '
            'DROP CONSTRAINT IF EXISTS "t_a_check"',
        'CREATE UNIQUE INDEX "t_a_unique" ON "t" ("a")',
        'COMMENT ON COLUMN "t"."a" IS \'c\'',
      ]);
      expect(alter(my, build), <String>[
        "ALTER TABLE `t` MODIFY COLUMN `a` INT NOT NULL COMMENT 'c'",
        'CREATE UNIQUE INDEX `t_a_unique` ON `t` (`a`)',
      ]);
    });

    test('change an enumeration', () {
      void build(Table t) {
        t.enumeration('s', <String>['a', 'b']).defaultTo('a').change();
      }

      expect(alter(pg, build), <String>[
        'ALTER TABLE "t" ALTER COLUMN "s" TYPE VARCHAR(255) USING "s"::VARCHAR(255), '
            'ALTER COLUMN "s" SET NOT NULL, '
            'ALTER COLUMN "s" SET DEFAULT \'a\', '
            'DROP CONSTRAINT IF EXISTS "t_s_check", '
            'ADD CONSTRAINT "t_s_check" CHECK ("s" IN (\'a\', \'b\'))',
      ]);
      expect(alter(my, build), <String>[
        "ALTER TABLE `t` MODIFY COLUMN `s` ENUM('a', 'b') NOT NULL DEFAULT 'a'",
      ]);
    });

    test('change an auto increment column', () {
      expect(
        () => alter(pg, (Table t) => t.id().change()),
        throwsUnsupportedError,
      );
      expect(alter(my, (Table t) => t.id().change()), <String>[
        'ALTER TABLE `t` MODIFY COLUMN `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT',
      ]);
    });

    test('dropColumn, dropColumns, renameColumn', () {
      void build(Table t) {
        t.dropColumn('a');
        t.dropColumns(<String>['b', 'c']);
        t.renameColumn('d', 'e');
      }

      for (SchemaGrammar g in <SchemaGrammar>[pg, my, lite]) {
        String t = g.wrap('t');
        expect(alter(g, build), <String>[
          'ALTER TABLE $t DROP COLUMN ${g.wrap('a')}',
          'ALTER TABLE $t DROP COLUMN ${g.wrap('b')}',
          'ALTER TABLE $t DROP COLUMN ${g.wrap('c')}',
          'ALTER TABLE $t RENAME COLUMN ${g.wrap('d')} TO ${g.wrap('e')}',
        ]);
      }
    });

    test('index, unique, dropIndex, dropUnique', () {
      void build(Table t) {
        t.index('a');
        t.unique(<String>['a', 'b']);
        t.dropIndex(<String>['a']);
        t.dropUnique('named');
      }

      expect(alter(pg, build), <String>[
        'CREATE INDEX "t_a_index" ON "t" ("a")',
        'CREATE UNIQUE INDEX "t_a_b_unique" ON "t" ("a", "b")',
        'DROP INDEX "t_a_index"',
        'DROP INDEX "named"',
      ]);
      expect(alter(my, build), <String>[
        'CREATE INDEX `t_a_index` ON `t` (`a`)',
        'CREATE UNIQUE INDEX `t_a_b_unique` ON `t` (`a`, `b`)',
        'DROP INDEX `t_a_index` ON `t`',
        'DROP INDEX `named` ON `t`',
      ]);
      expect(alter(lite, build), <String>[
        'CREATE INDEX "t_a_index" ON "t" ("a")',
        'CREATE UNIQUE INDEX "t_a_b_unique" ON "t" ("a", "b")',
        'DROP INDEX "t_a_index"',
        'DROP INDEX "named"',
      ]);
    });

    test('primary on an existing table', () {
      void build(Table t) => t.primary(<String>['a', 'b']);
      expect(alter(pg, build), <String>[
        'ALTER TABLE "t" ADD PRIMARY KEY ("a", "b")',
      ]);
      expect(alter(my, build), <String>[
        'ALTER TABLE `t` ADD PRIMARY KEY (`a`, `b`)',
      ]);
      expect(() => alter(lite, build), throwsUnsupportedError);
    });

    test('foreign and dropForeign', () {
      void build(Table t) {
        t.foreign('user_id').references('id').on('users').cascadeOnDelete();
        t.dropForeign(<String>['user_id']);
        t.dropForeign('named_fk');
      }

      expect(alter(pg, build), <String>[
        'ALTER TABLE "t" ADD CONSTRAINT "t_user_id_foreign" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE CASCADE',
        'ALTER TABLE "t" DROP CONSTRAINT "t_user_id_foreign"',
        'ALTER TABLE "t" DROP CONSTRAINT "named_fk"',
      ]);
      expect(alter(my, build), <String>[
        'ALTER TABLE `t` ADD CONSTRAINT `t_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE',
        'ALTER TABLE `t` DROP FOREIGN KEY `t_user_id_foreign`',
        'ALTER TABLE `t` DROP FOREIGN KEY `named_fk`',
      ]);
      expect(() => alter(lite, build), throwsUnsupportedError);
    });

    test('sqlite rebuild split', () {
      Table t = Table('t');
      t.string('a').nullable();
      t.string('b').change();
      t.dropForeign(<String>['x']);
      t.dropColumn('c');
      expect(t.needsSqliteRebuild, isTrue);
      expect(lite.compile(t.withoutSqliteRebuild()), <String>[
        'ALTER TABLE "t" ADD COLUMN "a" VARCHAR(255)',
        'ALTER TABLE "t" DROP COLUMN "c"',
      ]);
      expect(Table('t', creating: true).needsSqliteRebuild, isFalse);
    });
  });

  group('table |', () {
    test('drop, dropIfExists, rename', () {
      expect(pg.compile(Table('t')..drop()), <String>['DROP TABLE "t"']);
      expect(my.compile(Table('t')..dropIfExists()), <String>[
        'DROP TABLE IF EXISTS `t`',
      ]);
      expect(lite.compile(Table('t')..rename('u')), <String>[
        'ALTER TABLE "t" RENAME TO "u"',
      ]);
      expect(my.compile(Table('t')..rename('u')), <String>[
        'ALTER TABLE `t` RENAME TO `u`',
      ]);
    });

    test('toSql', () {
      Table t = Table('t', creating: true)..id();
      expect(t.toSql(lite), <String>[
        'CREATE TABLE "t" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT)',
      ]);
    });

    test('hasTable and column listing sql', () {
      expect(pg.compileTableExists(), contains('current_schema()'));
      expect(my.compileTableExists(), contains('DATABASE()'));
      expect(lite.compileTableExists(), contains('sqlite_schema'));
      expect(pg.compileColumnListing(), contains('information_schema.columns'));
      expect(my.compileColumnListing(), contains('DATABASE()'));
      expect(lite.compileColumnListing(), contains('pragma_table_info'));
    });
  });
}

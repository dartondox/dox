import 'dart:io';

import 'package:dox_annotation/command.dart';
import 'package:dox_annotation/install.dart';

/// `dox cache:install [--store=file|redis|memory|database]`. `dox add cache`
/// runs it. It sets up the cache config, the `.env` keys and the AppEnv
/// getters. With `--store=database` it also adds `dox_cache_database`, its
/// provider and the cache table migration.
/// It never overwrites a file, so it is safe to run twice.
class CacheInstallCommand extends Command {
  /// [root] is the app folder (the current folder by default). [runner]
  /// runs `dart`, tests pass a fake one.
  CacheInstallCommand({this.root, this.runner});

  final Directory? root;
  final ProcessRunner? runner;

  static const List<String> stores = <String>[
    'file',
    'redis',
    'memory',
    'database',
  ];

  @override
  String get name => 'cache:install';

  @override
  String get description => 'Set up the cache config in this app';

  @override
  String get usage => 'cache:install [--store=file|redis|memory|database]';

  @override
  Future<void> run(List<String> args) async {
    String? store = _store(args);
    if (store == null) {
      print(
        'Unknown option. Use --store=file, --store=redis, --store=memory '
        'or --store=database (file when not given).',
      );
      exitCode = 1;
      return;
    }
    Installer installer = Installer(root: root, runner: runner);
    String app = installer.appName;

    /// first, so an app without the AppEnv class gets the hint and
    /// nothing else is changed
    for (String getter in envGetters(store)) {
      installer.addEnvGetter(getter);
    }
    if (!installer.ok) {
      installer.printSummary(<String>[
        'lib/config/env.dart has no `abstract class AppEnv`. Run '
            '`dox env:generate` to make it, then run this again.',
      ]);
      return;
    }

    await installer.addDependency('dox_cache');
    if (store == 'database') {
      await installer.addDependency('dox_cache_database');
    }

    installer.writeFile('lib/config/cache.dart', cacheConfig(app, store));
    if (store == 'database') {
      installer.writeFile('lib/providers/cache_provider.dart', cacheProvider);
    }
    bool wired = _addToAppConfig(installer, app);

    Map<String, String> keys = envKeys(store);
    for (String key in keys.keys) {
      installer.addEnv(key, keys[key]!);
    }

    bool hasOrm =
        installer.hasDependency('dox_orm') &&
        installer.hasDependency('dox_migration');
    if (store == 'database' && hasOrm) _addMigration(installer);

    await installer.buildRunner();
    String config = File('${installer.root.path}/lib/config/cache.dart')
        .readAsStringSync();
    installer.printSummary(<String>[
      if (!wired)
        'Add `cache: cache` to AppConfig in lib/config/app.dart '
            '(import lib/config/cache.dart).',
      if (!config.contains("'$store'"))
        "lib/config/cache.dart has no '$store' store. Add one, see the "
            'cache docs.',
      if (store != 'file')
        'Check CACHE_STORE=$store in .env. A key that was already there is '
            'not changed.',
      if (store == 'database' && !hasOrm)
        'The database store needs the ORM. Run `dox add orm` first, then '
            '`dox cache:table`.',
      if (store == 'database' && hasOrm) 'Make the cache table: `dox migrate`.',
    ]);
  }

  /// the value of `--store=x` or `--store x`, file when not given. Null for
  /// an unknown option, a missing value or an unknown store.
  String? _store(List<String> args) {
    String store = 'file';
    for (int i = 0; i < args.length; i++) {
      if (args[i].startsWith('--store=')) {
        store = args[i].substring('--store='.length);
      } else if (args[i] == '--store' && i + 1 < args.length) {
        store = args[++i];
      } else {
        return null;
      }
    }
    return stores.contains(store) ? store : null;
  }

  /// add `cache: cache` and the import of `lib/config/cache.dart` to the
  /// `AppConfig(...)` call of `lib/config/app.dart`. Nothing changes when
  /// the file already has a `cache:` argument. Returns false when the
  /// file or the call is not found, so the caller prints a hint.
  bool _addToAppConfig(Installer installer, String app) {
    File file = File('${installer.root.path}/lib/config/app.dart');
    if (!file.existsSync()) return false;
    String text = file.readAsStringSync();
    if (RegExp(r'\bcache\s*:').hasMatch(text)) {
      installer.note('skipped  cache in lib/config/app.dart (already there)');
      return true;
    }
    RegExpMatch? call = RegExp(r'\bAppConfig\(').firstMatch(text);
    if (call == null) return false;
    text =
        '${text.substring(0, call.end)}\n'
        '  /// Cache stores (config/cache.dart)\n'
        '  cache: cache,\n'
        '${text.substring(call.end)}';
    String import = "import 'package:$app/config/cache.dart';";
    if (!text.contains(import)) {
      Iterable<RegExpMatch> imports = RegExp(
        r'^import .*;$',
        multiLine: true,
      ).allMatches(text);
      text = imports.isEmpty
          ? '$import\n\n$text'
          : '${text.substring(0, imports.first.start)}$import\n'
                '${text.substring(imports.first.start)}';
    }
    file.writeAsStringSync(text);
    installer.note('added    cache to lib/config/app.dart');
    return true;
  }

  /// write the cache table migration, unless a `create_cache_table`
  /// migration is already there
  void _addMigration(Installer installer) {
    String? path = MigrationFile(
      folder: Directory('${installer.root.path}/db/migration'),
    ).create('create_cache_table', cacheTableMigration);
    if (path == null) {
      installer.note('skipped  create_cache_table migration (already there)');
      return;
    }
    installer.note('created  db/migration/${File(path).uri.pathSegments.last}');
  }

  /// the getters of `AppEnv` that `lib/config/cache.dart` reads
  static List<String> envGetters(String store) {
    return <String>[
      '/// memory, file, redis or database\n'
          "  String get cacheStore => 'file';",
      if (store == 'redis') ...<String>[
        "String get redisHost => '127.0.0.1';",
        'int get redisPort => 6379;',
      ],
    ];
  }

  /// the `.env` keys of [store]
  static Map<String, String> envKeys(String store) {
    return <String, String>{
      'CACHE_STORE': store,
      if (store == 'redis') ...<String, String>{
        'REDIS_HOST': '127.0.0.1',
        'REDIS_PORT': '6379',
      },
    };
  }

  /// `lib/config/cache.dart`, the same as the app template. The `redis` and
  /// `database` stores are added when [store] is one of them.
  static String cacheConfig(String app, String store) {
    return '''
import 'package:dox_core/dox_core.dart';
import 'package:$app/config/env.dart';

/// Cache stores
/// -------------------------------
/// `Cache()` uses the default store. `Cache().store('memory')` picks one.
/// Drivers: file, memory, redis, null. Values must be JSON types.
CacheConfig cache = CacheConfig(
  defaultStore: env.cacheStore,
  stores: <String, Map<String, dynamic>>{
    'file': <String, dynamic>{'driver': 'file', 'path': 'storage/cache'},

    /// one map per isolate, fast, not shared
    'memory': <String, dynamic>{'driver': 'memory', 'max_size': 10000},
${_extraStore(store)}  },
);
''';
  }

  static String _extraStore(String store) {
    return switch (store) {
      'redis' =>
        '''

    /// a Redis server, shared by all isolates and servers
    'redis': <String, dynamic>{
      'driver': 'redis',
      'host': env.redisHost,
      'port': env.redisPort,
      'prefix': 'app_cache:',
    },
''',
      'database' =>
        '''

    /// a table of the database, shared by all isolates and servers.
    /// The driver is turned on in lib/providers/cache_provider.dart.
    'database': <String, dynamic>{'driver': 'database', 'table': 'cache'},
''',
      _ => '',
    };
  }

  /// `lib/providers/cache_provider.dart`, turns on the database driver
  static const String cacheProvider = '''
import 'package:dox_cache_database/dox_cache_database.dart';
import 'package:dox_core/dox_core.dart';

/// Cache provider
/// --------------------------
/// Turns on the `database` cache driver, so a store with
/// `'driver': 'database'` (lib/config/cache.dart) works.
/// If this project does not use the database store, delete this file
/// (Dox finds every DoxProvider class, see lib/generated/container.g.dart).
class AppCacheProvider extends DoxProvider {
  @override
  Future<void> setup() async {
    Dox().cache.extend(
      'database',
      DatabaseCacheDriverFactory(Dox().cache.config.encrypter),
    );
  }
}
''';

  /// the migration of the cache table, the same as `dox cache:table` makes
  static const String cacheTableMigration = '''
// ignore_for_file: file_names
import 'package:dox_cache_database/dox_cache_database.dart';
import 'package:dox_migration/dox_migration.dart';

/// The cache table of dox_cache_database.
class CreateCacheTable extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await CacheTables.up(schema);
  }

  @override
  Future<void> down(Schema schema) async {
    await CacheTables.down(schema);
  }
}
''';
}

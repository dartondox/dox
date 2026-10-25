import 'package:dox_orm/dox_orm.dart';

import 'utils/db_connection.dart';
import 'utils/env.dart';
import 'utils/logger.dart';

/// puts data in the database. `dox make:seeder` makes one in
/// `db/seeders`.
///
/// ```
/// class DatabaseSeeder extends Seeder {
///   @override
///   Future<void> run() async {
///     await call(<Seeder>[UserSeeder(), PostSeeder()]);
///   }
/// }
/// ```
abstract class Seeder {
  const Seeder();

  Future<void> run();

  /// run other seeders, one after another
  Future<void> call(List<Seeder> seeders) async {
    for (Seeder seeder in seeders) {
      Logger.info('Seeding: ${seeder.name}');
      await seeder.run();
    }
  }

  /// the class name. `--class=<name>` finds a seeder by it.
  String get name => runtimeType.toString();

  /// [SeederRunner] runs the seeder in one transaction, so a failed seed
  /// saves nothing. set it to false for a very large seed.
  bool get withinTransaction => true;
}

/// runs a seeder of [seeders], from a script like `bin/seed.dart`:
///
/// ```
/// Future<void> main(List<String> args) async {
///   exitCode = await SeederRunner(seeders: seeders).run(args);
/// }
/// ```
///
/// it sets up the ORM, runs the seeder and closes the ORM.
class SeederRunner {
  /// every seeder of the app, eg. from `db/seeders/seeders.dart`
  final List<Seeder> seeders;

  /// the database. null: the config from `.env` (or the environment
  /// variables), the same as the migrations.
  final DatabaseConfig? config;

  const SeederRunner({required this.seeders, this.config});

  /// run the seeder named [name], default `DatabaseSeeder`
  Future<void> seed([String name = 'DatabaseSeeder']) async {
    Seeder seeder = seeders.firstWhere(
      (Seeder s) => s.name == name,
      orElse: () => throw StateError(
        'Seeder $name not found. Seeders: '
        '${seeders.map((Seeder s) => s.name).join(', ')}',
      ),
    );
    SqlQueryBuilder.initializeWithDatabaseConfig(config ?? _envConfig());
    try {
      Logger.info('Seeding: $name');
      seeder.withinTransaction
          ? await QueryBuilder.transaction(seeder.run)
          : await seeder.run();
      Logger.success('Database seeding completed.');
    } finally {
      await SqlQueryBuilder.close();
    }
  }

  /// run from the command line and give the exit code:
  /// no option runs `DatabaseSeeder`, `--class=<name>` runs another one.
  Future<int> run(List<String> args) async {
    try {
      String name = 'DatabaseSeeder';
      for (int i = 0; i < args.length; i++) {
        if (args[i].startsWith('--class=')) {
          name = args[i].substring('--class='.length);
        } else if (args[i] == '--class' && i + 1 < args.length) {
          name = args[++i];
        } else {
          throw ArgumentError('Unknown option ${args[i]}, use --class=<name>');
        }
      }
      await seed(name);
      return 0;
    } catch (error) {
      Logger.danger(error);
      return 1;
    }
  }

  static DatabaseConfig _envConfig() {
    return DatabaseConfig(
      connection: 'default',
      connections: <String, ConnectionConfig>{
        'default': DbConnection.config(loadEnv()),
      },

      /// DbConnection.config already reads DATABASE_URL
      url: '',
    );
  }
}

import 'package:dox_orm/dox_orm.dart';

/// a Dart migration. `dox make:migration` makes one in `db/migration`.
///
/// ```
/// class CreateUsersTable extends Migration {
///   @override
///   Future<void> up(Schema schema) async {
///     await schema.create('users', (Table table) {
///       table.id();
///       table.string('email').unique();
///       table.timestamps();
///     });
///   }
///
///   @override
///   Future<void> down(Schema schema) async {
///     await schema.dropIfExists('users');
///   }
/// }
/// ```
///
/// [schema] runs on the migration connection. use `schema.driver` for
/// raw sql or data changes, so they run in the same transaction.
abstract class Migration {
  const Migration();

  Future<void> up(Schema schema);

  Future<void> down(Schema schema);

  /// run [up] and [down] in a transaction. postgres and sqlite undo all
  /// changes when it fails. mysql saves schema changes (create, alter,
  /// drop) right away, so only data changes are undone there.
  bool get withinTransaction => true;
}

/// one Dart migration in the registry (`db/migration/migrations.dart`).
/// [name] is the file name without `.dart`, it orders the migrations.
class MigrationEntry {
  final String name;
  final Migration migration;

  const MigrationEntry(this.name, this.migration);
}

/// a migration failed, [migration] is its name
class MigrationException implements Exception {
  final String migration;
  final Object error;

  const MigrationException(this.migration, this.error);

  @override
  String toString() => 'Migration failed: $migration\n$error';
}

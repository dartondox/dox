import 'package:dox_migration/src/create_migration/create_migration.dart';
import 'package:dox_migration/src/dox_migration_base.dart';

void main(List<String> args) async {
  if (args.length == 2 && args[0] == 'migrate') {
    await Migration(from: 'cli').migrate();
  }

  if (args.length == 2 && args[0] == 'rollback') {
    await Migration(from: 'cli').rollback();
  }

  if (args.length == 2 && args[0] == 'create') {
    MigrationFile(args[1], 'sql');
    return;
  }

  if (args.length == 3 && args[0] == 'create') {
    MigrationFile(args[1], args[2]);
    return;
  }

  print(
      'Could not find a command named "${args[0]}". Run `dox help` for more information.');
}

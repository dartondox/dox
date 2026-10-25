import 'package:dox/src/tools/server_serve.dart';
import 'package:test/test.dart';

void main() {
  test('build_runner runs without removed flags', () {
    expect(buildRunnerBuildArgs, <String>['run', 'build_runner', 'build']);
  });

  test('dox build leaves SQLite files out of the bundle', () {
    expect(isSqliteFile('db/dox.sqlite'), isTrue);
    expect(isSqliteFile('db/dox.sqlite-wal'), isTrue);
    expect(isSqliteFile('db/dox.sqlite-shm'), isTrue);
    expect(isSqliteFile('db/app.db'), isTrue);
    expect(isSqliteFile('db/test.sqlite3'), isTrue);
    expect(isSqliteFile('db/migration/2026_create_users_table.dart'), isFalse);
    expect(isSqliteFile('db/migration/create_users.sql'), isFalse);
  });
}

import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

import 'connection.dart';
import 'models/user/user.model.dart';

/// a user that only takes `name` from a map
class FillableUser extends User {
  @override
  List<String> get fillable => <String>['name'];
}

/// a user that never takes `is_admin` from a map
class GuardedUser extends User {
  @override
  List<String> get guarded => <String>['is_admin'];
}

void main() async {
  await initQueryBuilder();

  group('Security', () {
    setUp(() async {
      await Schema().create('users', (Table table) {
        table.id();
        table.string('name');
        table.integer('is_admin').withDefault(0);
        table.softDeletes();
        table.timestamps();
      });
    });

    tearDown(() async {
      await Schema().dropIfExists('users');
    });

    test('column names with sql are refused', () {
      DBDriver driver = SqlQueryBuilder().dbDriver;
      expect(driver.wrap('users.name as n'), isNotEmpty);
      expect(driver.wrap(' users.* '), isNotEmpty);
      for (String bad in <String>[
        'count(*)',
        'name = (SELECT 1), is_admin = (1), name',
        'CASE WHEN (1=1) THEN id ELSE name END',
        'name; DROP TABLE users',
        'name"',
      ]) {
        expect(() => driver.wrap(bad), throwsArgumentError, reason: bad);
      }
      expect(
        () => QueryBuilder.table('users').update(<String, dynamic>{
          'name = (SELECT 1), is_admin = (1), name': 'x',
        }),
        throwsArgumentError,
      );
      expect(
        QueryBuilder.table('users').orderByRaw('count(*) desc').toSql(),
        contains('ORDER BY count(*) desc'),
      );
    });

    test('where and join operators are checked', () {
      expect(
        () => QueryBuilder.table('users').where('id', '= 0 OR 1=1 OR id =', 1),
        throwsArgumentError,
      );
      expect(
        () => QueryBuilder.table('users').join('x', 'x.id', 'OR 1=1 --', 'id'),
        throwsArgumentError,
      );
      expect(
        QueryBuilder.table('users').where('name', 'NOT LIKE', 'a%').toSql(),
        contains('NOT LIKE'),
      );
    });

    test('fillable and guarded stop mass assignment', () async {
      Map<String, dynamic> body = <String, dynamic>{'name': 'a', 'is_admin': 1};
      await FillableUser().create(body);
      await GuardedUser().create(body);
      await FillableUser().where('id', 1).update(body);
      await GuardedUser().where('id', 2).update(body);

      List<Map<String, dynamic>> rows = await QueryBuilder.table('users')
          .orderBy('id')
          .get();
      expect(rows.map((Map<String, dynamic> r) => r['is_admin']), <int>[0, 0]);

      /// a query soft delete still works when fillable is set
      await FillableUser().where('id', 1).delete();
      expect(await User().count(), 1);
    });

    test('insertMultiple on a model drops keys that are not allowed', () async {
      Map<String, dynamic> body = <String, dynamic>{'name': 'a', 'is_admin': 1};
      await FillableUser().insertMultiple(<Map<String, dynamic>>[body, body]);
      await GuardedUser().insertMultiple(<Map<String, dynamic>>[body]);

      List<Map<String, dynamic>> rows = await QueryBuilder.table('users').get();
      expect(rows.map((Map<String, dynamic> r) => r['is_admin']), <int>[
        0,
        0,
        0,
      ]);
    });

    test('tls modes', () {
      ConnectionConfig pg = ConnectionConfig.fromUrl(
        'postgres://u:p@db.example.com/app?sslmode=verify-full',
      );
      expect(pg.postgresSslMode, 'verify-full');
      expect(
        ConnectionConfig.fromUrl(
          'postgres://u:p@db.example.com/app?sslmode=verify-ca',
        ).postgresSslMode,
        'verify-ca',
      );

      /// like libpq: require encrypts but does not check the certificate,
      /// so Heroku style urls keep working
      expect(
        ConnectionConfig.fromUrl(
          'postgres://u:p@db.example.com/app?sslmode=require',
        ).postgresSslMode,
        'require',
      );
      expect(
        ConnectionConfig(
          driver: Driver.postgres,
          database: 'app',
          useSSL: true,
          debug: false,
        ).postgresSslMode,
        'require',
      );
      expect(
        ConnectionConfig(
          driver: Driver.postgres,
          database: 'app',
          useSSL: true,
          extra: <String, dynamic>{'sslMode': 'verify-full'},
          debug: false,
        ).postgresSslMode,
        'verify-full',
      );
      expect(
        ConnectionConfig.fromUrl('postgres://u:p@h/app').postgresSslMode,
        'disable',
      );

      /// mysql checks the certificate unless verifyCertificate=false
      ConnectionConfig dev = ConnectionConfig.fromUrl(
        'mysql://u:p@db.example.com/app?ssl=true&verifyCertificate=false',
      );
      expect(dev.useSSL, true);
      expect(dev.verifyCertificate, false);
      expect(pg.verifyCertificate, true);
    });

    test('postgres ca file', () {
      ConnectionConfig url = ConnectionConfig.fromUrl(
        'postgres://u:p@db.example.com/app?sslmode=verify-full'
        '&sslrootcert=%2Fetc%2Fssl%2Frds-ca.pem',
      );
      expect(url.postgresSslRootCert, '/etc/ssl/rds-ca.pem');
      expect(url.extra.containsKey('sslrootcert'), false);
      expect(
        ConnectionConfig(
          driver: Driver.postgres,
          database: 'app',
          extra: <String, dynamic>{'sslRootCert': 'certs/ca.pem'},
          debug: false,
        ).postgresSslRootCert,
        'certs/ca.pem',
      );
      expect(
        ConnectionConfig.fromUrl('postgres://u:p@h/app').postgresSslRootCert,
        null,
      );
    });
  });
}

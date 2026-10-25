import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

void main() {
  group('ConnectionConfig.fromUrl', () {
    test('postgres with decoded user and password', () {
      ConnectionConfig c = ConnectionConfig.fromUrl(
        'postgresql://my%40user:p%3Ass%2Fw@db.example.com:6543/my%20db',
      );
      expect(c.driver, Driver.postgres);
      expect(c.user, 'my@user');
      expect(c.password, 'p:ss/w');
      expect(c.host, 'db.example.com');
      expect(c.port, 6543);
      expect(c.database, 'my db');
      expect(c.useSSL, isFalse);
    });

    test('default ports and host', () {
      expect(ConnectionConfig.fromUrl('postgres://u@/d').port, 5432);
      expect(ConnectionConfig.fromUrl('postgres://u@/d').host, 'localhost');
      expect(ConnectionConfig.fromUrl('mysql://u:p@h/d').port, 3306);
      ConnectionConfig maria = ConnectionConfig.fromUrl('mariadb://u:p@h/d');
      expect(maria.driver, Driver.mysql);
      expect(maria.password, 'p');
    });

    test('sslmode', () {
      expect(
        ConnectionConfig.fromUrl('postgres://u@h/d?sslmode=require').useSSL,
        isTrue,
      );
      expect(
        ConnectionConfig.fromUrl('postgres://u@h/d?sslmode=disable').useSSL,
        isFalse,
      );
      ConnectionConfig full = ConnectionConfig.fromUrl(
        'postgres://u@h/d?sslmode=verify-full',
      );
      expect(full.useSSL, isTrue);
      expect(full.extra['sslMode'], 'verify-full');
      ConnectionConfig prefer = ConnectionConfig.fromUrl(
        'postgres://u@h/d?sslmode=prefer',
      );
      expect(prefer.useSSL, isFalse);
      expect(prefer.postgresSslMode, 'prefer');
      expect(
        ConnectionConfig.fromUrl('mysql://u@h/d?sslmode=require').extra,
        isEmpty,
      );
      expect(ConnectionConfig.fromUrl('mysql://u@h/d?ssl=true').useSSL, isTrue);
    });

    test('other options go to extra, base extra is kept', () {
      ConnectionConfig c = ConnectionConfig.fromUrl(
        'postgres://u@h/d?maxConnectionCount=20&threads=2&applicationName=x',
        extra: <String, dynamic>{'timeZone': 'UTC', 'maxConnectionCount': 5},
      );
      expect(c.extra, <String, dynamic>{
        'timeZone': 'UTC',
        'maxConnectionCount': 20,
        'threads': 2,
        'applicationName': 'x',
      });
    });

    test('Cloud SQL Unix socket from ?host=', () {
      ConnectionConfig c = ConnectionConfig.fromUrl(
        'postgres://app:secret@/blog?host=/cloudsql/proj:us-central1:db',
      );
      expect(c.host, '/cloudsql/proj:us-central1:db');
      expect(c.isUnixSocket, isTrue);
      expect(c.database, 'blog');
    });

    test('tcp host is not a socket', () {
      ConnectionConfig c = ConnectionConfig.fromUrl('postgres://u@h/d');
      expect(c.isUnixSocket, isFalse);
    });

    test('mysql Unix socket from ?socket= and ?host=', () {
      for (String key in <String>['socket', 'host']) {
        ConnectionConfig c = ConnectionConfig.fromUrl(
          'mariadb://app:secret@/blog?$key=/var/run/mysqld/mysqld.sock',
        );
        expect(c.driver, Driver.mysql);
        expect(c.host, '/var/run/mysqld/mysqld.sock');
        expect(c.isUnixSocket, isTrue);
        expect(c.database, 'blog');
      }
    });

    test('mysql tcp host is a plain host name', () {
      ConnectionConfig c = ConnectionConfig.fromUrl('mysql://u@db/d');
      expect(c.isUnixSocket, isFalse);
      expect(c.host, 'db');
      expect(c.port, 3306);
    });

    test('sqlite forms', () {
      expect(
        ConnectionConfig.fromUrl('sqlite:///tmp/a.db').database,
        '/tmp/a.db',
      );
      expect(
        ConnectionConfig.fromUrl('sqlite://db/dox.sqlite').database,
        'db/dox.sqlite',
      );
      expect(ConnectionConfig.fromUrl('sqlite::memory:').database, ':memory:');
      expect(
        ConnectionConfig.fromUrl('file:db/dox.sqlite').database,
        'db/dox.sqlite',
      );
      expect(
        ConnectionConfig.fromUrl('sqlite:///tmp/a.db').driver,
        Driver.sqlite,
      );
    });

    test('unknown scheme throws', () {
      expect(
        () => ConnectionConfig.fromUrl('redis://h'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('DatabaseConfig url', () {
    Map<String, ConnectionConfig> connections() => <String, ConnectionConfig>{
      'sqlite': ConnectionConfig(
        driver: Driver.sqlite,
        database: ':memory:',
        debug: true,
        extra: <String, dynamic>{'busyTimeout': 100},
      ),
      'mysql': ConnectionConfig(
        driver: Driver.mysql,
        database: 'm',
        debug: false,
      ),
    };

    test('url wins for the default connection', () {
      DatabaseConfig config = DatabaseConfig(
        connection: 'sqlite',
        connections: connections(),
        url: 'postgres://u:p@h:1/d',
      );
      ConnectionConfig c = config.getConnectionConfig();
      expect(c.driver, Driver.postgres);
      expect(c.debug, isTrue);
      expect(c.extra['busyTimeout'], 100);
      expect(config.getConnectionConfig('sqlite'), same(c));
      // other names do not change
      expect(config.getConnectionConfig('mysql').driver, Driver.mysql);
    });

    test('empty url means no url', () {
      DatabaseConfig config = DatabaseConfig(
        connection: 'sqlite',
        connections: connections(),
        url: '',
      );
      expect(config.getConnectionConfig().driver, Driver.sqlite);
    });

    test('url works without a matching connection', () {
      DatabaseConfig config = DatabaseConfig(
        connection: 'missing',
        connections: connections(),
        url: 'sqlite::memory:',
      );
      expect(config.getConnectionConfig().database, ':memory:');
    });
  });
}

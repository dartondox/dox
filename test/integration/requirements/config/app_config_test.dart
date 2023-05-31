import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import 'app.dart';

void main() {
  group('AppConfig |', () {
    test('DB', () {
      AppConfig config = Config();
      DBConfig dbConfig = config.dbConfig;
      expect(dbConfig.dbDriver, DatabaseDriver.postgres);
      expect(dbConfig.dbHost, 'localhost');
      expect(dbConfig.dbName, 'postgres');
      expect(dbConfig.dbPassword, 'postgres');
      expect(dbConfig.dbPort, 5432);
      expect(dbConfig.dbUsername, 'postgres');
      expect(dbConfig.enableQueryLog, false);
    });
  });
}

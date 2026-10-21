import 'package:dox_migration/src/utils/utils.dart';
import 'package:test/test.dart';

void main() {
  group('parseMigrationSql', () {
    test('only real markers start a section', () {
      Map<String, String> sections = parseMigrationSql('''
-- up
CREATE TABLE a (n INT DEFAULT -1, s VARCHAR(10) DEFAULT 'x-y');
-- just a note
SELECT 1 - 1

--down
DROP TABLE a
''');
      expect(sections['up'], contains("DEFAULT 'x-y'"));
      expect(sections['up'], contains('SELECT 1 - 1'));
      expect(sections['down'], 'DROP TABLE a');
    });
  });

  group('splitSqlStatements', () {
    test('split on ; outside quotes and comments', () {
      expect(
        splitSqlStatements('''
SELECT 'a;b'; SELECT "c;d"; SELECT `e;f`;
-- skip; this
SELECT 1 /* and; this */;
SELECT 'it''s; ok'
'''),
        <String>[
          "SELECT 'a;b'",
          'SELECT "c;d"',
          'SELECT `e;f`',
          'SELECT 1',
          "SELECT 'it''s; ok'",
        ],
      );
    });

    test('keep postgres dollar quoted body', () {
      String fn =
          r'''CREATE FUNCTION f() RETURNS int AS $$ BEGIN RETURN 1; END; $$ LANGUAGE plpgsql''';
      String tagged = r'''DO $body$ BEGIN PERFORM 1; END $body$''';
      expect(splitSqlStatements('$fn;\n$tagged;'), <String>[fn, tagged]);
    });

    test('backslash escape for mysql', () {
      expect(
        splitSqlStatements(r"SELECT 'a\';b'; SELECT 2", backslashEscape: true),
        <String>[r"SELECT 'a\';b'", 'SELECT 2'],
      );
    });
  });
}

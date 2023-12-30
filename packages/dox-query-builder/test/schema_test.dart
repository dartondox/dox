import 'package:dox_query_builder/dox_query_builder.dart';
import 'package:test/test.dart';

import 'connection.dart';

void main() async {
  await initQueryBuilder();

  group('Schema |', () {
    setUp(() async {
      await Schema.create('schema_test_table', (Table table) {
        table.id();
        table.uuid('uuid');
        table.bigInteger('user_id');
        table.money('price');
        table.jsonb('tags');
        table.decimal('views');
        table.float4('shares');
        table.float8('likes');
        table.timestamp('approved_at');
        table.date('published_date');
        table.time('published_time');
        table.timestampTz('expired_at');
        table.string('title');
        table.string('status').withDefault('active');
        table.text('body');
        table.text('column_to_drop');
        table.string('slug').nullable();
        table.softDeletes();
        table.timestamps();
      });
    });

    tearDown(() async {
      await Schema.drop('schema_test_table');
    });

    test('schema update', () async {
      await Schema.table('schema_test_table', (Table table) {
        table.renameColumn('title', 'new_title_column');
        table.string('blog_title').nullable();
        table.string('status').withDefault('pending');
        table.string('body');
        table.string('slug').unique().nullable();
        table.string('column1').nullable();
        table.string('column2').nullable();
        table.dropColumn('column_to_drop');
      });
      Table table = Table().table('schema_test_table');
      List<String> columns = await table.getTableColumns();
      expect(true, columns.contains('id'));
      expect(true, columns.contains('column1'));
      expect(true, columns.contains('column2'));
      expect(true, columns.contains('new_title_column'));
      expect(true, columns.contains('slug'));
      expect(false, columns.contains('column_to_drop'));
    });
  });
}

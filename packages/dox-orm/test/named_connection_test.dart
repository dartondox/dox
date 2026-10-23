import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

import 'models/blog/blog.model.dart';
import 'models/blog_info/blog_info.model.dart';

/// two in memory SQLite databases. A row saved on 'other' must not be
/// in 'main'. This test always uses SQLite, it only checks which
/// connection a query goes to.
void main() {
  SqlQueryBuilder.initializeWithDatabaseConfig(
    DatabaseConfig(
      connection: 'main',
      connections: <String, ConnectionConfig>{
        'main': ConnectionConfig(
          driver: Driver.sqlite,
          database: ':memory:',
          debug: false,
        ),
        'other': ConnectionConfig(
          driver: Driver.sqlite,
          database: ':memory:',
          debug: false,
        ),
      },
    ),
  );

  Future<void> createTables(DBDriver driver) async {
    await Schema(driver).create('blog', (Table table) {
      table.id('uid');
      table.string('title');
      table.string('status').withDefault('active');
      table.text('body');
      table.string('slug').nullable();
      table.softDeletes();
      table.timestamps();
    });
    await Schema(driver).create('blog_info', (Table table) {
      table.id();
      table.json('info');
      table.integer('blog_id');
      table.timestamps();
    });
  }

  setUpAll(() async {
    await createTables(SqlQueryBuilder().getDBDriver('main'));
    await createTables(SqlQueryBuilder().getDBDriver('other'));
  });

  Future<int> countOn(String connection) async {
    return await QueryBuilder.table('blog').withConnection(connection).count();
  }

  test('save(), update and delete() use withConnection()', () async {
    Blog blog = Blog()..withConnection('other');
    blog.title = 'title';
    blog.description = 'body';
    await blog.save();
    expect(await countOn('other'), 1);
    expect(await countOn('main'), 0);

    blog.title = 'new title';
    await blog.save();
    Blog? saved = await Blog().withConnection('other').find(blog.uid);
    expect(saved?.title, 'new title');

    await blog.forceDelete();
    expect(await countOn('other'), 0);
  });

  test('a model loaded from a connection saves to it', () async {
    await Blog().withConnection('other').create(<String, dynamic>{
      'title': 'a',
      'body': 'b',
    });
    expect(await countOn('main'), 0);

    Blog? blog = await Blog().withConnection('other').getFirst();
    blog?.title = 'changed';
    await blog?.save();
    List<Blog> blogs = await Blog().withConnection('other').get();
    expect(blogs.first.title, 'changed');

    await blogs.first.delete();
    expect(await Blog().withConnection('other').count(), 0);
    expect(await countOn('main'), 0);
    await QueryBuilder.table('blog').withConnection('other').truncate();
  });

  test('relations use the connection of the parent model', () async {
    Blog blog = Blog()..withConnection('other');
    blog.title = 'title';
    blog.description = 'body';
    await blog.save();
    BlogInfo info = BlogInfo()..withConnection('other');
    info.info = <String, dynamic>{'a': 1};
    info.blogId = blog.uid;
    await info.save();

    Blog? found = await Blog().withConnection('other').find(blog.uid);
    expect(found?.blogInfo?.info?['a'], 1);
    await QueryBuilder.table('blog').withConnection('other').truncate();
    await QueryBuilder.table('blog_info').withConnection('other').truncate();
  });
}

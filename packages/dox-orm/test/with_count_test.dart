import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

import 'connection.dart';
import 'models/artist/artist.model.dart';
import 'models/artist_song/artist_song.model.dart';
import 'models/blog/blog.model.dart';
import 'models/blog_info/blog_info.model.dart';
import 'models/song/song.model.dart';

void main() async {
  await initQueryBuilder();

  group('withCount |', () {
    setUp(() async {
      for (String t in <String>[
        'blog',
        'blog_info',
        'artist',
        'song',
        'artist_song',
      ]) {
        await Schema().dropIfExists(t);
      }
      await Schema().create('blog', (Table table) {
        table.id('uid');
        table.string('title');
        table.string('status').withDefault('active');
        table.text('body');
        table.string('slug').nullable();
        table.softDeletes();
        table.timestamps();
      });
      await Schema().create('blog_info', (Table table) {
        table.id();
        table.json('info');
        table.integer('blog_id');
        table.timestamps();
      });
      await Schema().create('artist', (Table table) {
        table.id();
        table.string('name');
        table.timestamps();
      });
      await Schema().create('song', (Table table) {
        table.id();
        table.string('title');
        table.timestamps();
      });
      await Schema().create('artist_song', (Table table) {
        table.id();
        table.integer('song_id');
        table.integer('artist_id');
        table.timestamps();
      });

      await Blog().insertMultiple(<Map<String, dynamic>>[
        <String, dynamic>{'title': 'one', 'body': 'x'},
        <String, dynamic>{'title': 'two', 'body': 'x'},
      ]);
      await BlogInfo().insertMultiple(<Map<String, dynamic>>[
        <String, dynamic>{
          'blog_id': 1,
          'info': <String, dynamic>{'n': 'a'},
        },
        <String, dynamic>{
          'blog_id': 1,
          'info': <String, dynamic>{'n': 'b'},
        },
        <String, dynamic>{
          'blog_id': 1,
          'info': <String, dynamic>{'n': 'c'},
        },
      ]);

      await Artist().insertMultiple(<Map<String, String>>[
        <String, String>{'name': 'x'},
        <String, String>{'name': 'y'},
      ]);
      await Song().insertMultiple(<Map<String, String>>[
        <String, String>{'title': 's1'},
        <String, String>{'title': 's2'},
        <String, String>{'title': 's3'},
      ]);
      await ArtistSong().insertMultiple(<Map<String, int>>[
        <String, int>{'song_id': 1, 'artist_id': 1},
        <String, int>{'song_id': 2, 'artist_id': 1},
        <String, int>{'song_id': 3, 'artist_id': 2},
      ]);
    });

    tearDown(() async {
      for (String t in <String>[
        'blog',
        'blog_info',
        'artist',
        'song',
        'artist_song',
      ]) {
        await Schema().dropIfExists(t);
      }
    });

    test('hasMany count with eager loading', () async {
      List<Blog> blogs = await Blog()
          .withCount('blogInfos')
          .orderBy('uid')
          .get();
      expect(blogs.first.countOf('blogInfos'), 3);
      expect(blogs.first.blogInfos.length, 3);
      expect(blogs.last.countOf('blogInfos'), 0);
      expect(blogs.first.toJson()['blog_infos_count'], 3);
    });

    test('count with a where and an alias', () async {
      Blog? blog = await Blog()
          .withCount('blogInfos')
          .withCount('blogInfos as small_count', (QueryBuilder<dynamic> q) {
            q.where('id', '<', 3);
          })
          .where('title', 'one')
          .getFirst();
      expect(blog?.countOf('blogInfos'), 3);
      expect(blog?.aggregate('small_count'), 2);
    });

    test('find, paginate and count work with withCount', () async {
      Blog? blog = await Blog().withCount('blogInfos').find(1);
      expect(blog?.countOf('blogInfos'), 3);

      Pagination<Blog> page = await Blog()
          .withCount('blogInfos')
          .paginate(currentPage: 1, perPage: 1);
      expect(page.total, 2);
      expect(page.data.first.countOf('blogInfos'), 3);
    });

    test('manyToMany count, sum and max', () async {
      List<Artist> artists = await Artist()
          .withCount('songs')
          .withSum('songs', 'id')
          .withMax('songs', 'id')
          .orderBy('id')
          .get();
      expect(artists.first.countOf('songs'), 2);
      expect(artists.last.countOf('songs'), 1);
      expect(artists.first.aggregate('songs_sum_id'), 3);
      expect(artists.first.aggregate('songs_max_id'), 2);
      expect(artists.last.aggregate('songs_max_id'), 3);
    });

    test('belongsTo is not supported', () async {
      expect(
        () => BlogInfo().withCount('blog').get(),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}

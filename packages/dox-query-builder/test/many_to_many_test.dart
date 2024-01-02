import 'package:dox_query_builder/dox_query_builder.dart';
import 'package:test/test.dart';

import 'connection.dart';
import 'models/artist/artist.model.dart';
import 'models/artist_song/artist_song.model.dart';
import 'models/song/song.model.dart';

void main() async {
  await initQueryBuilder();

  group('Many To Many |', () {
    setUp(() async {
      await Schema.drop('artist');
      await Schema.drop('song');
      await Schema.drop('artist_song');
      await Schema.create('artist', (Table table) {
        table.id();
        table.string('name');
        table.timestamps();
      });

      await Schema.create('song', (Table table) {
        table.id();
        table.string('title');
        table.timestamps();
      });

      await Schema.create('artist_song', (Table table) {
        table.id('id');
        table.integer('song_id');
        table.integer('artist_id');
        table.timestamps();
      });
    });

    test('Many to Many', () async {
      await Artist().insertMultiple(<Map<String, String>>[
        <String, String>{'name': "Arijit Singh"},
        <String, String>{'name': "Naw Naw"},
        <String, String>{'name': "Lay Phy"},
      ]);

      await Song().insertMultiple(<Map<String, String>>[
        <String, String>{'title': "Tum hi ho"},
        <String, String>{'title': "Di Lo Nya Tine"},
        <String, String>{'title': "Aein Mat"},
      ]);

      await ArtistSong().insertMultiple(<Map<String, String>>[
        <String, String>{'song_id': '1', 'artist_id': '1'},
        <String, String>{'song_id': '2', 'artist_id': '1'},
        <String, String>{'song_id': '2', 'artist_id': '2'},
        <String, String>{'song_id': '3', 'artist_id': '2'},
        <String, String>{'song_id': '2', 'artist_id': '3'},
        <String, String>{'song_id': '1', 'artist_id': '3'},
      ]);

      Artist? artist = await Artist().preload('songs').find(1);

      expect(artist?.songs.length, 2);
      expect(artist?.songs.map((Song e) => e.id).toList(), <int>[1, 2]);

      Song? song = await Song().preload('artists').find(2);

      expect(song?.artists.length, 3);
      expect(song?.artists.map((Artist e) => e.id).toList(), <int>[1, 2, 3]);
    });
  });
}

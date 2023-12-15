import 'package:dox_query_builder/dox_query_builder.dart';

import '../song/song.model.dart';

part 'artist.model.g.dart';

@DoxModel()
class Artist extends ArtistGenerator {
  @Column()
  String? name;

  @ManyToMany(
    Song,
    localKey: 'id',
    relatedKey: 'id',
    pivotForeignKey: 'artist_id',
    pivotRelatedForeignKey: 'song_id',
    pivotTable: 'artist_song',
    onQuery: onQuery,
  )
  List<Song> songs = <Song>[];

  static Model<Song> onQuery(Song q) {
    return q.debug(false);
  }
}

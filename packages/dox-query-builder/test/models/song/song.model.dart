import 'package:dox_query_builder/dox_query_builder.dart';

import '../artist/artist.model.dart';

part 'song.model.g.dart';

@DoxModel()
class Song extends SongGenerator {
  @Column()
  String? title;

  @ManyToMany(Artist)
  List<Artist> artists = <Artist>[];
}

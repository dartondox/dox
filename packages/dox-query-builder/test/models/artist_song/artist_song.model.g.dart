// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'artist_song.model.dart';

// **************************************************************************
// Generator: DoxModelBuilder
// **************************************************************************

// ignore_for_file: always_specify_types

class ArtistSongGenerator extends Model<ArtistSong> {
  @override
  String get primaryKey => 'id';

  @override
  Map<String, dynamic> get timestampsColumn => <String, dynamic>{
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      };

  int? get id => tempIdValue;

  set id(dynamic val) => tempIdValue = val;

  ArtistSong get newQuery => ArtistSong();

  @override
  List<String> get preloadList => <String>[];

  @override
  Map<String, Function> get relationsResultMatcher => <String, Function>{};

  @override
  Map<String, Function> get relationsQueryMatcher => <String, Function>{};

  @override
  ArtistSong fromMap(Map<String, dynamic> m) => ArtistSong()
    ..id = m['id'] as int?
    ..songId = m['blog_id'] as int?
    ..artistId = m['artist_id'] as int?
    ..createdAt = m['created_at'] == null
        ? null
        : DateTime.parse(m['created_at'] as String)
    ..updatedAt = m['updated_at'] == null
        ? null
        : DateTime.parse(m['updated_at'] as String);

  @override
  Map<String, dynamic> convertToMap(dynamic i) {
    ArtistSong instance = i as ArtistSong;
    Map<String, dynamic> map = <String, dynamic>{
      'id': instance.id,
      'blog_id': instance.songId,
      'artist_id': instance.artistId,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

    return map;
  }
}

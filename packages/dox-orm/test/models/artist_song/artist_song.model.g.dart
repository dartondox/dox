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
  Map<String, dynamic> get timestampsColumn => const <String, dynamic>{
    'created_at': 'created_at',
    'updated_at': 'updated_at',
  };

  int? get id => tempIdValue as int?;

  set id(int? val) => tempIdValue = val;

  ArtistSong query() => ArtistSong();

  @override
  bool get readsRowDates => true;

  @override
  List<String> get tableColumns => const <String>[
    'id',
    'blog_id',
    'artist_id',
    'created_at',
    'updated_at',
  ];

  @override
  List<String> get preloadList => const <String>[];

  @override
  Map<String, Function> get relationsResultMatcher =>
      const <String, Function>{};

  @override
  Map<String, Function> get relationsQueryMatcher => const <String, Function>{};

  @override
  ArtistSong fromMap(Map<String, dynamic> m) => ArtistSong()
    ..id = m['id'] as int?
    ..songId = m['blog_id'] as int?
    ..artistId = m['artist_id'] as int?
    ..createdAt = m['created_at'] is DateTime?
        ? m['created_at'] as DateTime?
        : DateTime.parse(m['created_at'] as String)
    ..updatedAt = m['updated_at'] is DateTime?
        ? m['updated_at'] as DateTime?
        : DateTime.parse(m['updated_at'] as String);
  @override
  Map<String, dynamic> columnsToMap() {
    ArtistSong instance = this as ArtistSong;
    Map<String, dynamic> map = <String, dynamic>{
      'id': instance.id,
      'blog_id': instance.songId,
      'artist_id': instance.artistId,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

    return map;
  }

  @override
  Map<String, dynamic> convertToMap(dynamic i) {
    ArtistSong instance = i as ArtistSong;
    Map<String, dynamic> map = instance.columnsToMap();

    return map;
  }
}

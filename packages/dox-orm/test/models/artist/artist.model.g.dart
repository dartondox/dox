// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'artist.model.dart';

// **************************************************************************
// Generator: DoxModelBuilder
// **************************************************************************

// ignore_for_file: always_specify_types

class ArtistGenerator extends Model<Artist> {
  @override
  String get primaryKey => 'id';

  @override
  Map<String, dynamic> get timestampsColumn => const <String, dynamic>{
    'created_at': 'created_at',
    'updated_at': 'updated_at',
  };

  int? get id => tempIdValue as int?;

  set id(int? val) => tempIdValue = val;

  Artist query() => Artist();

  @override
  bool get readsRowDates => true;

  @override
  List<String> get tableColumns => const <String>[
    'id',
    'name',
    'created_at',
    'updated_at',
  ];

  @override
  List<String> get preloadList => const <String>[];

  @override
  Map<String, Function> get relationsResultMatcher => const <String, Function>{
    'songs': getSongs,
  };

  @override
  Map<String, Function> get relationsQueryMatcher => const <String, Function>{
    'songs': querySongs,
  };

  static Future<void> getSongs(List<Model<Artist>> list) async {
    var result = await getManyToMany<Artist, Song>(querySongs(list), list);
    for (dynamic i in list) {
      if (result[i.tempIdValue.toString()] != null) {
        i.songs = result[i.tempIdValue.toString()]!;
      }
    }
  }

  static Song? querySongs(List<Model<Artist>> list) {
    return manyToMany<Artist, Song>(
      list,
      () => Song(),
      localKey: 'id',
      relatedKey: 'id',
      pivotForeignKey: 'artist_id',
      pivotRelatedForeignKey: 'song_id',
      pivotTable: 'artist_song',
      onQuery: Artist.onQuery,
    );
  }

  @override
  Artist fromMap(Map<String, dynamic> m) => Artist()
    ..id = m['id'] as int?
    ..name = m['name'] as String?
    ..createdAt = m['created_at'] is DateTime?
        ? m['created_at'] as DateTime?
        : DateTime.parse(m['created_at'] as String)
    ..updatedAt = m['updated_at'] is DateTime?
        ? m['updated_at'] as DateTime?
        : DateTime.parse(m['updated_at'] as String);
  @override
  Map<String, dynamic> columnsToMap() {
    Artist instance = this as Artist;
    Map<String, dynamic> map = <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

    return map;
  }

  @override
  Map<String, dynamic> convertToMap(dynamic i) {
    Artist instance = i as Artist;
    Map<String, dynamic> map = instance.columnsToMap();

    List<String> preload = getPreload();
    if (preload.contains('songs')) {
      map['songs'] = toMap(instance.songs);
    }

    return map;
  }
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song.model.dart';

// **************************************************************************
// Generator: DoxModelBuilder
// **************************************************************************

// ignore_for_file: always_specify_types

class SongGenerator extends Model<Song> {
  @override
  String get primaryKey => 'id';

  @override
  Map<String, dynamic> get timestampsColumn => const <String, dynamic>{
    'created_at': 'created_at',
    'updated_at': 'updated_at',
  };

  int? get id => tempIdValue as int?;

  set id(int? val) => tempIdValue = val;

  Song query() => Song();

  @override
  bool get readsRowDates => true;

  @override
  List<String> get tableColumns => const <String>[
    'id',
    'title',
    'created_at',
    'updated_at',
  ];

  @override
  List<String> get preloadList => const <String>[];

  @override
  Map<String, Function> get relationsResultMatcher => const <String, Function>{
    'artists': getArtists,
  };

  @override
  Map<String, Function> get relationsQueryMatcher => const <String, Function>{
    'artists': queryArtists,
  };

  static Future<void> getArtists(List<Model<Song>> list) async {
    var result = await getManyToMany<Song, Artist>(queryArtists(list), list);
    for (dynamic i in list) {
      if (result[i.tempIdValue.toString()] != null) {
        i.artists = result[i.tempIdValue.toString()]!;
      }
    }
  }

  static Artist? queryArtists(List<Model<Song>> list) {
    return manyToMany<Song, Artist>(list, () => Artist());
  }

  @override
  Song fromMap(Map<String, dynamic> m) => Song()
    ..id = m['id'] as int?
    ..title = m['title'] as String?
    ..createdAt = m['created_at'] is DateTime?
        ? m['created_at'] as DateTime?
        : DateTime.parse(m['created_at'] as String)
    ..updatedAt = m['updated_at'] is DateTime?
        ? m['updated_at'] as DateTime?
        : DateTime.parse(m['updated_at'] as String);
  @override
  Map<String, dynamic> columnsToMap() {
    Song instance = this as Song;
    Map<String, dynamic> map = <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

    return map;
  }

  @override
  Map<String, dynamic> convertToMap(dynamic i) {
    Song instance = i as Song;
    Map<String, dynamic> map = instance.columnsToMap();

    List<String> preload = getPreload();
    if (preload.contains('artists')) {
      map['artists'] = toMap(instance.artists);
    }

    return map;
  }
}

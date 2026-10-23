// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag.model.dart';

// **************************************************************************
// Generator: DoxModelBuilder
// **************************************************************************

// ignore_for_file: always_specify_types

class TagGenerator extends Model<Tag> {
  @override
  String get primaryKey => 'id';

  @override
  Map<String, dynamic> get timestampsColumn => <String, dynamic>{
    'created_at': 'created_at',
    'updated_at': 'updated_at',
  };

  int? get id => tempIdValue as int?;

  set id(int? val) => tempIdValue = val;

  Tag query() => Tag();

  @override
  List<String> get tableColumns => <String>[
    'id',
    'title',
    'created_at',
    'updated_at',
  ];

  @override
  List<String> get preloadList => <String>[];

  @override
  Map<String, Function> get relationsResultMatcher => <String, Function>{};

  @override
  Map<String, Function> get relationsQueryMatcher => <String, Function>{};

  @override
  Tag fromMap(Map<String, dynamic> m) => Tag()
    ..id = m['id'] as int?
    ..title = m['title'] as String?
    ..createdAt = m['created_at'] == null
        ? null
        : DateTime.parse(m['created_at'] as String)
    ..updatedAt = m['updated_at'] == null
        ? null
        : DateTime.parse(m['updated_at'] as String);

  @override
  Map<String, dynamic> convertToMap(dynamic i) {
    Tag instance = i as Tag;
    Map<String, dynamic> map = <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

    return map;
  }
}

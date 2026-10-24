// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_post.model.dart';

// **************************************************************************
// Generator: DoxModelBuilder
// **************************************************************************

// ignore_for_file: always_specify_types

class EventPostGenerator extends Model<EventPost> with SoftDeletes<EventPost> {
  @override
  String get primaryKey => 'id';

  @override
  Map<String, dynamic> get timestampsColumn => const <String, dynamic>{
    'created_at': 'created_at',
    'updated_at': 'updated_at',
  };

  @override
  String get tableName => 'event_posts';

  int? get id => tempIdValue as int?;

  set id(int? val) => tempIdValue = val;

  EventPost query() => EventPost();

  @override
  bool get readsRowDates => true;

  @override
  List<String> get tableColumns => const <String>[
    'id',
    'title',
    'deleted_at',
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
  EventPost fromMap(Map<String, dynamic> m) => EventPost()
    ..id = m['id'] as int?
    ..title = m['title'] as String?
    ..deletedAt = m['deleted_at'] is DateTime?
        ? m['deleted_at'] as DateTime?
        : DateTime.parse(m['deleted_at'] as String)
    ..createdAt = m['created_at'] is DateTime?
        ? m['created_at'] as DateTime?
        : DateTime.parse(m['created_at'] as String)
    ..updatedAt = m['updated_at'] is DateTime?
        ? m['updated_at'] as DateTime?
        : DateTime.parse(m['updated_at'] as String);
  @override
  Map<String, dynamic> columnsToMap() {
    EventPost instance = this as EventPost;
    Map<String, dynamic> map = <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'deleted_at': instance.deletedAt?.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

    return map;
  }

  @override
  Map<String, dynamic> convertToMap(dynamic i) {
    EventPost instance = i as EventPost;
    Map<String, dynamic> map = instance.columnsToMap();

    return map;
  }

  @override
  bool get hasModelHooks => true;
}

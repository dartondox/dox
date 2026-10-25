// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scoped_post.model.dart';

// **************************************************************************
// Generator: DoxModelBuilder
// **************************************************************************

// ignore_for_file: always_specify_types

class ScopedPostGenerator extends Model<ScopedPost> {
  @override
  String get primaryKey => 'id';

  @override
  Map<String, dynamic> get timestampsColumn => const <String, dynamic>{
    'created_at': null,
    'updated_at': null,
  };

  int? get id => tempIdValue as int?;

  set id(int? val) => tempIdValue = val;

  ScopedPost query() => ScopedPost();

  @override
  bool get readsRowDates => true;

  @override
  List<String> get tableColumns => const <String>[
    'id',
    'title',
    'published',
    'archived',
    'views',
  ];

  @override
  List<String> get preloadList => const <String>[];

  @override
  Map<String, Function> get relationsResultMatcher =>
      const <String, Function>{};

  @override
  Map<String, Function> get relationsQueryMatcher => const <String, Function>{};

  static const _publishedCast = BoolCast();
  static const _archivedCast = BoolCast();

  @override
  Map<String, QueryBuilder<ScopedPost> Function(QueryBuilder<ScopedPost>)>
  get globalScopes => const {'visible': ScopedPost.visible};

  @override
  ScopedPost fromMap(Map<String, dynamic> m) => ScopedPost()
    ..id = m['id'] as int?
    ..title = m['title'] as String?
    ..published = _publishedCast.get(m['published'])
    ..archived = _archivedCast.get(m['archived'])
    ..views = m['views'] as int?;
  @override
  Map<String, dynamic> columnsToMap() {
    ScopedPost instance = this as ScopedPost;
    Map<String, dynamic> map = <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'published': _publishedCast.set(instance.published),
      'archived': _archivedCast.set(instance.archived),
      'views': instance.views,
    };

    return map;
  }

  @override
  Map<String, dynamic> convertToMap(dynamic i) {
    ScopedPost instance = i as ScopedPost;
    Map<String, dynamic> map = instance.columnsToMap();

    return map;
  }
}

extension ScopedPostScopes on QueryBuilder<ScopedPost> {
  QueryBuilder<ScopedPost> isPublished() => ScopedPost.isPublished(this);
  QueryBuilder<ScopedPost> minViews(int views, [String op = '>=']) =>
      ScopedPost.minViews(this, views, op);
  QueryBuilder<ScopedPost> titled({required String title, bool exact = true}) =>
      ScopedPost.titled(this, title: title, exact: exact);
}

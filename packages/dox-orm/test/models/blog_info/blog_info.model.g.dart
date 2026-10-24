// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blog_info.model.dart';

// **************************************************************************
// Generator: DoxModelBuilder
// **************************************************************************

// ignore_for_file: always_specify_types

class BlogInfoGenerator extends Model<BlogInfo> {
  @override
  String get primaryKey => 'id';

  @override
  Map<String, dynamic> get timestampsColumn => const <String, dynamic>{
    'created_at': 'created_at',
    'updated_at': 'updated_at',
  };

  int? get id => tempIdValue as int?;

  set id(int? val) => tempIdValue = val;

  BlogInfo query() => BlogInfo();

  @override
  bool get readsRowDates => true;

  @override
  List<String> get tableColumns => const <String>[
    'id',
    'info',
    'blog_id',
    'created_at',
    'updated_at',
  ];

  @override
  List<String> get preloadList => const <String>[];

  @override
  Map<String, Function> get relationsResultMatcher => const <String, Function>{
    'blog': getBlog,
  };

  @override
  Map<String, Function> get relationsQueryMatcher => const <String, Function>{
    'blog': queryBlog,
  };

  static Future<void> getBlog(List<Model<BlogInfo>> list) async {
    var result = await getBelongsTo<BlogInfo, Blog>(queryBlog(list), list);
    for (dynamic i in list) {
      if (result[i.tempIdValue.toString()] != null) {
        i.blog = result[i.tempIdValue.toString()]!;
      }
    }
  }

  static Blog? queryBlog(List<Model<BlogInfo>> list) {
    return belongsTo<BlogInfo, Blog>(
      list,
      () => Blog(),
      onQuery: BlogInfo.onQuery,
    );
  }

  @override
  BlogInfo fromMap(Map<String, dynamic> m) => BlogInfo()
    ..id = m['id'] as int?
    ..info = m['info'] as Map<String, dynamic>?
    ..blogId = m['blog_id'] as int?
    ..createdAt = m['created_at'] is DateTime?
        ? m['created_at'] as DateTime?
        : DateTime.parse(m['created_at'] as String)
    ..updatedAt = m['updated_at'] is DateTime?
        ? m['updated_at'] as DateTime?
        : DateTime.parse(m['updated_at'] as String);
  @override
  Map<String, dynamic> columnsToMap() {
    BlogInfo instance = this as BlogInfo;
    Map<String, dynamic> map = <String, dynamic>{
      'id': instance.id,
      'info': instance.info,
      'blog_id': instance.blogId,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

    return map;
  }

  @override
  Map<String, dynamic> convertToMap(dynamic i) {
    BlogInfo instance = i as BlogInfo;
    Map<String, dynamic> map = instance.columnsToMap();

    List<String> preload = getPreload();
    if (preload.contains('blog')) {
      map['blog'] = toMap(instance.blog);
    }

    return map;
  }

  @override
  void setComputedValues(Map<String, dynamic> map) {
    BlogInfo instance = this as BlogInfo;
    map['has_info'] = instance.hasInfo;
  }
}

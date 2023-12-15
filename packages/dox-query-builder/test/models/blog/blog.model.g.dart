// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blog.model.dart';

// **************************************************************************
// Generator: DoxModelBuilder
// **************************************************************************

// ignore_for_file: always_specify_types

class BlogGenerator extends Model<Blog> with SoftDeletes<Blog> {
  @override
  String get primaryKey => 'uid';

  @override
  Map<String, dynamic> get timestampsColumn => <String, dynamic>{
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      };

  int? get uid => tempIdValue;

  set uid(dynamic val) => tempIdValue = val;

  Blog query() => Blog();

  @override
  List<String> get tableColumns => <String>[
        'uid',
        'title',
        'status',
        'body',
        'deleted_at',
        'created_at',
        'updated_at'
      ];

  @override
  List<String> get preloadList => <String>[
        'blogInfo',
        'blogInfos',
      ];

  @override
  Map<String, Function> get relationsResultMatcher => <String, Function>{
        'blogInfo': getBlogInfo,
        'blogInfos': getBlogInfos,
      };

  @override
  Map<String, Function> get relationsQueryMatcher => <String, Function>{
        'blogInfo': queryBlogInfo,
        'blogInfos': queryBlogInfos,
      };

  static Future<void> getBlogInfo(List<Model<Blog>> list) async {
    var result = await getHasOne<Blog, BlogInfo>(queryBlogInfo(list), list);
    for (dynamic i in list) {
      if (result[i.tempIdValue.toString()] != null) {
        i.blogInfo = result[i.tempIdValue.toString()]!;
      }
    }
  }

  static BlogInfo? queryBlogInfo(List<Model<Blog>> list) {
    return hasOne<Blog, BlogInfo>(
      list,
      () => BlogInfo(),
      onQuery: Blog.onQuery,
    );
  }

  static Future<void> getBlogInfos(List<Model<Blog>> list) async {
    var result = await getHasMany<Blog, BlogInfo>(queryBlogInfos(list), list);
    for (dynamic i in list) {
      if (result[i.tempIdValue.toString()] != null) {
        i.blogInfos = result[i.tempIdValue.toString()]!;
      }
    }
  }

  static BlogInfo? queryBlogInfos(List<Model<Blog>> list) {
    return hasMany<Blog, BlogInfo>(
      list,
      () => BlogInfo(),
      onQuery: Blog.onQuery,
    );
  }

  @override
  Blog fromMap(Map<String, dynamic> m) => Blog()
    ..uid = m['uid'] as int?
    ..title = Blog.beforeGet(m)
    ..status = m['status'] as String?
    ..description = m['body'] as String?
    ..deletedAt = m['deleted_at'] == null
        ? null
        : DateTime.parse(m['deleted_at'] as String)
    ..createdAt = m['created_at'] == null
        ? null
        : DateTime.parse(m['created_at'] as String)
    ..updatedAt = m['updated_at'] == null
        ? null
        : DateTime.parse(m['updated_at'] as String);

  @override
  Map<String, dynamic> convertToMap(dynamic i) {
    Blog instance = i as Blog;
    Map<String, dynamic> map = <String, dynamic>{
      'uid': instance.uid,
      'title': instance.title,
      'status': instance.status,
      'body': instance.description,
      'deleted_at': instance.deletedAt?.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'blog_info': toMap(instance.blogInfo),
      'blog_infos': toMap(instance.blogInfos),
    };
    map['title'] = Blog.slugTitle(map);

    List<String> preload = getPreload();

    return map;
  }
}

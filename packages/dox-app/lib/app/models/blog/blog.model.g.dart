// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blog.model.dart';

// **************************************************************************
// Generator: DoxModelBuilder
// **************************************************************************

// ignore_for_file: always_specify_types

class BlogGenerator extends Model<Blog> with SoftDeletes<Blog> {
  @override
  String get primaryKey => 'id';

  @override
  Map<String, dynamic> get timestampsColumn => <String, dynamic>{
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      };

  int? get id => tempIdValue;

  set id(dynamic val) => tempIdValue = val;

  Blog query() => Blog();

  @override
  List<String> get tableColumns => <String>[
        'id',
        'user_id',
        'title',
        'slug',
        'description',
        'created_at',
        'updated_at'
      ];

  @override
  List<String> get preloadList => <String>[];

  @override
  Map<String, Function> get relationsResultMatcher => <String, Function>{
        'user': getUser,
        'categories': getCategories,
      };

  @override
  Map<String, Function> get relationsQueryMatcher => <String, Function>{
        'user': queryUser,
        'categories': queryCategories,
      };

  static Future<void> getUser(List<Model<Blog>> list) async {
    var result = await getBelongsTo<Blog, User>(queryUser(list), list);
    for (dynamic i in list) {
      if (result[i.tempIdValue.toString()] != null) {
        i.user = result[i.tempIdValue.toString()]!;
      }
    }
  }

  static User? queryUser(List<Model<Blog>> list) {
    return belongsTo<Blog, User>(
      list,
      () => User(),
      foreignKey: 'user_id',
      localKey: 'id',
    );
  }

  static Future<void> getCategories(List<Model<Blog>> list) async {
    var result =
        await getManyToMany<Blog, Category>(queryCategories(list), list);
    for (dynamic i in list) {
      if (result[i.tempIdValue.toString()] != null) {
        i.categories = result[i.tempIdValue.toString()]!;
      }
    }
  }

  static Category? queryCategories(List<Model<Blog>> list) {
    return manyToMany<Blog, Category>(
      list,
      () => Category(),
      localKey: 'id',
      relatedKey: 'id',
      pivotForeignKey: 'blog_id',
      pivotRelatedForeignKey: 'category_id',
      onQuery: Blog.onQueryActiveUser,
    );
  }

  @override
  Blog fromMap(Map<String, dynamic> m) => Blog()
    ..id = m['id'] as int?
    ..userId = m['user_id'] as int?
    ..title = m['title'] as String?
    ..slug = m['slug'] as String?
    ..description = m['description'] as String?
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
      'id': instance.id,
      'user_id': instance.userId,
      'title': instance.title,
      'slug': instance.slug,
      'description': instance.description,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
    map['slug'] = Blog.makeSlug(map);

    List<String> preload = getPreload();
    if (preload.contains('user')) {
      map['user'] = toMap(instance.user);
    }
    if (preload.contains('categories')) {
      map['categories'] = toMap(instance.categories);
    }

    return map;
  }
}

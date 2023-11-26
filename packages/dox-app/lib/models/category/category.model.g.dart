// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.model.dart';

// **************************************************************************
// Generator: DoxModelBuilder
// **************************************************************************

// ignore_for_file: always_specify_types

class CategoryGenerator extends Model<Category> {
  @override
  String get primaryKey => 'id';

  @override
  Map<String, dynamic> get timestampsColumn => <String, dynamic>{
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      };

  int? get id => tempIdValue;

  set id(dynamic val) => tempIdValue = val;

  Category get newQuery => Category();

  @override
  List<String> get preloadList => <String>[];

  @override
  Map<String, Function> get relationsResultMatcher => <String, Function>{
        'blogs': getBlogs,
      };

  @override
  Map<String, Function> get relationsQueryMatcher => <String, Function>{
        'blogs': queryBlogs,
      };

  static Future<void> getBlogs(List<Model<Category>> list) async {
    var result = await getManyToMany<Category, Blog>(queryBlogs(list), list);
    for (dynamic i in list) {
      if (result[i.tempIdValue.toString()] != null) {
        i.blogs = result[i.tempIdValue.toString()]!;
      }
    }
  }

  static Blog? queryBlogs(List<Model<Category>> list) {
    return manyToMany<Category, Blog>(
      list,
      () => Blog(),
      localKey: 'id',
      relatedKey: 'id',
      pivotForeignKey: 'category_id',
      pivotRelatedForeignKey: 'blog_id',
      onQuery: Category.onQueryActiveUser,
    );
  }

  @override
  Category fromMap(Map<String, dynamic> m) => Category()
    ..id = m['id'] as int?
    ..name = m['name'] as String?
    ..createdAt = m['created_at'] == null
        ? null
        : DateTime.parse(m['created_at'] as String)
    ..updatedAt = m['updated_at'] == null
        ? null
        : DateTime.parse(m['updated_at'] as String);

  @override
  Map<String, dynamic> convertToMap(dynamic i) {
    Category instance = i as Category;
    Map<String, dynamic> map = <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

    List<String> preload = getPreload();
    if (preload.contains('blogs')) {
      map['blogs'] = toMap(instance.blogs);
    }

    return map;
  }
}

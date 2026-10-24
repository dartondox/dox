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
  Map<String, dynamic> get timestampsColumn => const <String, dynamic>{
    'created_at': 'created_at',
    'updated_at': 'updated_at',
  };

  int? get id => tempIdValue as int?;

  set id(int? val) => tempIdValue = val;

  Category query() => Category();

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
    'blogs': getBlogs,
  };

  @override
  Map<String, Function> get relationsQueryMatcher => const <String, Function>{
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
    ..createdAt = m['created_at'] is DateTime?
        ? m['created_at'] as DateTime?
        : DateTime.parse(m['created_at'] as String)
    ..updatedAt = m['updated_at'] is DateTime?
        ? m['updated_at'] as DateTime?
        : DateTime.parse(m['updated_at'] as String);
  @override
  Map<String, dynamic> columnsToMap() {
    Category instance = this as Category;
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
    Category instance = i as Category;
    Map<String, dynamic> map = instance.columnsToMap();

    List<String> preload = getPreload();
    if (preload.contains('blogs')) {
      map['blogs'] = toMap(instance.blogs);
    }

    return map;
  }
}

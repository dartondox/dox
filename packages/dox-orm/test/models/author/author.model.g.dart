// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'author.model.dart';

// **************************************************************************
// Generator: DoxModelBuilder
// **************************************************************************

// ignore_for_file: always_specify_types

class AuthorGenerator extends Model<Author> {
  @override
  String get primaryKey => 'id';

  @override
  Map<String, dynamic> get timestampsColumn => <String, dynamic>{
    'created_at': 'created_at',
    'updated_at': 'updated_at',
  };

  int? get id => tempIdValue as int?;

  set id(int? val) => tempIdValue = val;

  Author query() => Author();

  @override
  List<String> get tableColumns => <String>[
    'id',
    'code',
    'created_at',
    'updated_at',
  ];

  @override
  List<String> get preloadList => <String>[];

  @override
  Map<String, Function> get relationsResultMatcher => <String, Function>{
    'books': getBooks,
    'firstBook': getFirstBook,
    'tags': getTags,
  };

  @override
  Map<String, Function> get relationsQueryMatcher => <String, Function>{
    'books': queryBooks,
    'firstBook': queryFirstBook,
    'tags': queryTags,
  };

  static Future<void> getBooks(List<Model<Author>> list) async {
    var result = await getHasMany<Author, Book>(queryBooks(list), list);
    for (dynamic i in list) {
      if (result[i.tempIdValue.toString()] != null) {
        i.books = result[i.tempIdValue.toString()]!;
      }
    }
  }

  static Book? queryBooks(List<Model<Author>> list) {
    return hasMany<Author, Book>(
      list,
      () => Book(),
      foreignKey: 'author_code',
      localKey: 'code',
    );
  }

  static Future<void> getFirstBook(List<Model<Author>> list) async {
    var result = await getHasOne<Author, Book>(queryFirstBook(list), list);
    for (dynamic i in list) {
      if (result[i.tempIdValue.toString()] != null) {
        i.firstBook = result[i.tempIdValue.toString()]!;
      }
    }
  }

  static Book? queryFirstBook(List<Model<Author>> list) {
    return hasOne<Author, Book>(
      list,
      () => Book(),
      foreignKey: 'author_code',
      localKey: 'code',
    );
  }

  static Future<void> getTags(List<Model<Author>> list) async {
    var result = await getManyToMany<Author, Tag>(queryTags(list), list);
    for (dynamic i in list) {
      if (result[i.tempIdValue.toString()] != null) {
        i.tags = result[i.tempIdValue.toString()]!;
      }
    }
  }

  static Tag? queryTags(List<Model<Author>> list) {
    return manyToMany<Author, Tag>(
      list,
      () => Tag(),
      localKey: 'code',
      pivotForeignKey: 'author_code',
      pivotTable: 'author_tag',
    );
  }

  @override
  Author fromMap(Map<String, dynamic> m) => Author()
    ..id = m['id'] as int?
    ..code = m['code'] as String?
    ..createdAt = m['created_at'] == null
        ? null
        : DateTime.parse(m['created_at'] as String)
    ..updatedAt = m['updated_at'] == null
        ? null
        : DateTime.parse(m['updated_at'] as String);

  @override
  Map<String, dynamic> convertToMap(dynamic i) {
    Author instance = i as Author;
    Map<String, dynamic> map = <String, dynamic>{
      'id': instance.id,
      'code': instance.code,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

    List<String> preload = getPreload();
    if (preload.contains('books')) {
      map['books'] = toMap(instance.books);
    }
    if (preload.contains('firstBook')) {
      map['first_book'] = toMap(instance.firstBook);
    }
    if (preload.contains('tags')) {
      map['tags'] = toMap(instance.tags);
    }

    return map;
  }
}

import '../dox_query_builder.dart';

class Model<T> extends QueryBuilder<T> {
  int? tempIdValue;
  DateTime? createdAt;
  DateTime? updatedAt;

  List<String> hidden = <String>[];

  bool _debug = SqlQueryBuilder().debug;

  @override
  String get tableName => helper.toSnakeCase(runtimeType.toString());

  @override
  dynamic get self => this;

  // coverage:ignore-start
  Map<String, dynamic> get timestampsColumn => <String, dynamic>{
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      };
  // coverage:ignore-end

  @override
  Model<T> debug([bool? debug]) {
    _debug = debug ?? true;
    super.debug(debug);
    return this;
  }

  /// create new record in table
  ///
  /// ```
  /// Blog blog = new Blog();
  /// blog.title = 'blog title';
  /// await blog.save()
  /// ```
  Future<void> save() async {
    String? createdAtColumn = timestampsColumn['created_at'];
    String? updatedAtColumn = timestampsColumn['updated_at'];

    Map<String, dynamic> values = toMap();
    if (values[primaryKey] == null) {
      values.removeWhere((String key, dynamic value) => value == null);

      if (createdAtColumn != null) {
        values[createdAtColumn] = now();
        createdAt = values[createdAtColumn];
      }

      if (updatedAtColumn != null) {
        values[updatedAtColumn] = now();
        updatedAt = values[updatedAtColumn];
      }

      Map<String, dynamic> res = await QueryBuilder.table(tableName)
          .setPrimaryKey(primaryKey)
          .debug(_debug)
          .insert(values);

      tempIdValue = res[primaryKey];
    } else {
      dynamic id = values[primaryKey];
      values.remove(primaryKey);
      values.remove(createdAtColumn);
      values.removeWhere((String key, dynamic value) => value == null);
      if (updatedAtColumn != null) {
        values[updatedAtColumn] = now();
        updatedAt = values[updatedAtColumn];
      }

      await QueryBuilder.table(tableName, this)
          .setPrimaryKey(primaryKey)
          .debug(_debug)
          .where(primaryKey, id)
          .update(values);
    }
  }

  /// Reload eager relationship after new record created/updated.
  /// await Blog().reload()
  Future<void> reload() async {
    await initPreload(<Model<T>>[this]);
  }

  /// support jsonEncode()
  ///
  /// ```
  /// Blog? blog = Blog().find(1);
  /// Map<String, dynamic> m = blog?.toJson();
  /// ```
  Map<String, dynamic> toJson() {
    Map<String, dynamic> data = toMap(removeHiddenField: true);
    for (String h in hidden) {
      data.remove(h);
    }
    return data;
  }

  /// convert model to map
  /// if you have custom select query, use original option with true value
  ///
  /// ```
  /// Blog? blog = Blog().find(1);
  /// Map<String, dynamic> m = blog?.toMap();
  /// Map<String, dynamic> m = blog?.toMap(original: true);
  /// ```
  Map<String, dynamic> toMap(
      {bool original = false, bool removeHiddenField = false}) {
    if (original == true && originalMap.isNotEmpty) {
      return originalMap;
    }
    Map<String, dynamic> data = convertToMap(this);
    if (removeHiddenField) {
      for (String h in hidden) {
        data.remove(h);
      }
    }
    return data;
  }

  /// start ********** preload

  List<String> get preloadList => <String>[]; // coverage:ignore-line
  List<String> get customPreloadList => _preloadList; // coverage:ignore-line
  final List<String> _preloadList = <String>[];

  Map<String, Function> relationsResultMatcher = <String, Function>{};
  Map<String, Function> relationsQueryMatcher = <String, Function>{};

  /// preload relationship
  /// ```
  /// Blog blog = await Blog().preload('comments').find(1);
  /// print(blog.comments);
  /// ```
  Model<T> preload(String key) {
    _preloadList.add(key);
    return this;
  }

  /// Get relation result
  /// ```
  /// Blog blog = await Blog()find(1);
  /// await blog.$getRelation('comments');
  /// print(blog.comments);
  /// `
  Future<M?> $getRelation<M>(String name) async {
    return await _getRelation(<Model<T>>[this], name) as M;
  }

  /// Get relation query
  /// ```
  /// Blog blog = await Blog()find(1);
  /// Comment comment = blog.related<Comment>('comments');
  /// await comment.get();
  /// `
  M? related<M>(String name) {
    if (relationsQueryMatcher[name] != null) {
      Function funcName = relationsQueryMatcher[name]!;
      return Function.apply(funcName, <dynamic>[
        <Model<T>>[this]
      ]);
    }
    return null;
  }

  Future<void> _getRelation(List<Model<T>> i, String name) async {
    if (relationsResultMatcher[name] != null) {
      Function funcName = relationsResultMatcher[name]!;
      return await Function.apply(funcName, <dynamic>[i]);
    }
  }

  @override
  List<String> getPreload() {
    return <String>{...preloadList, ..._preloadList}.toList();
  }

  @override
  Future<void> initPreload(List<Model<T>> list) async {
    List<String> pList = <String>{...preloadList, ..._preloadList}.toList();
    for (String key in pList) {
      await _getRelation(list, key);
    }
  }

  /// get all records
  /// ```
  /// List<Blog> blogs = await Blog().all();
  /// ```
  @override
  Future<List<T>> all() async {
    return await super.all();
  }

  /// find the record
  /// ```
  /// Blog? blog = await Blog().find(1);
  /// Blog? blog = await Blog().find('name', 'John');
  /// ```
  @override
  Future<T?> find(dynamic arg1, [dynamic arg2]) async {
    return await super.find(arg1, arg2);
  }

  /// create a record
  /// ```
  /// Blog blog = await Blog().create({
  ///   "title" : "Blog title",
  ///   "body" : "Lorem",
  /// });
  /// ````
  @override
  Future<T> create(Map<String, dynamic> data) async {
    return await super.create(data);
  }

  /// create a record
  /// ```
  /// Blog blog = await Blog().insert({
  ///   "title" : "Blog title",
  ///   "body" : "Lorem",
  /// });
  /// ````
  @override
  Future<T> insert(Map<String, dynamic> data) async {
    return await super.insert(data);
  }
}

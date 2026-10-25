import 'package:dox_orm/dox_orm.dart';

import 'count.dart';
import 'delete.dart';
import 'get.dart';
import 'group_by.dart';
import 'insert.dart';
import 'join.dart';
import 'limit.dart';
import 'order_by.dart';
import 'raw.dart';
import 'select.dart';
import 'truncate.dart';
import 'update.dart';
import 'utils/helper.dart';
import 'utils/logger.dart';
import 'where.dart';
import 'with_count.dart';

class QueryBuilder<T>
    with
        Limit<T>,
        Where<T>,
        OrderBy<T>,
        GroupBy<T>,
        Insert<T>,
        Join<T>,
        Raw<T>,
        Get<T>,
        Update<T>,
        Select<T>,
        Truncate<T>,
        Delete<T>,
        Count<T>,
        WithCount<T> {
  /// made on the first use, a find() with a cached sql makes it once
  Map<String, dynamic>? _substitutionValues;

  dynamic self;

  @override
  QueryBuilder<T> get queryBuilder => this;

  @override
  String primaryKey = 'id';

  @override
  String? connection;

  @override
  DBDriver get dbDriver {
    if (connection != null) {
      return SqlQueryBuilder().getDBDriver(connection);
    }
    return SqlQueryBuilder().dbDriver;
  }

  @override
  late final QueryBuilderHelper<T> helper = QueryBuilderHelper<T>(this);

  // coverage:ignore-start
  @override
  Logger get logger => Logger();
  // coverage:ignore-end

  @override
  bool shouldDebug = SqlQueryBuilder().debug;

  @override
  Map<String, dynamic> get substitutionValues =>
      _substitutionValues ??= <String, dynamic>{};

  @override
  String get selectQueryString => getSelectQuery() + aggregateSelects();

  List<String> getPreload() => <String>[];

  @override
  bool isSoftDeletes = false;

  @override
  bool withTrashed = false;

  @override
  String tableName = '';

  @override
  void addSubstitutionValues(String key, dynamic value) {
    String index = key.replaceFirst('@', '');
    substitutionValues[index] = value;
  }

  @override
  Map<String, dynamic> resetSubstitutionValues() {
    return _substitutionValues = <String, dynamic>{};
  }

  /// set table and continue query
  ///
  /// ```
  /// QueryBuilder.table('blog');
  /// ```
  /// the rows are maps, so get() gives `List<Map<String, dynamic>>`
  /// and getFirst() gives `Map<String, dynamic>?`.
  static QueryBuilder<Map<String, dynamic>> table(String tableName) {
    return QueryBuilder<Map<String, dynamic>>()..tableName = tableName;
  }

  /// set debug on or of
  ///
  /// ```
  /// QueryBuilder().debug(true)
  /// ```
  QueryBuilder<T> debug([bool? debug]) {
    shouldDebug = debug ?? true;
    return this;
  }

  /// use different connection to query
  ///
  /// ```
  /// QueryBuilder().withConnection('mysql')
  /// ```
  QueryBuilder<T> withConnection(String connectionName) {
    connection = connectionName;
    return this;
  }

  /// set debug on or of
  ///
  /// ```
  /// QueryBuilder.table('blog').setPrimaryKey('uid')
  /// ```
  QueryBuilder<T> setPrimaryKey(String id) {
    primaryKey = id;
    return this;
  }

  /// With trash (this function can be used with SoftDeletes only)
  ///
  /// ```
  /// List blogs = await Blog().withTrash().all();
  /// ```
  QueryBuilder<T> withTrash([bool withTrashed = true]) {
    this.withTrashed = withTrashed;
    return queryBuilder;
  }

  /// **** global scopes

  /// the global scopes of the model: name => scope method.
  /// the generator overrides it for models with `@Scope(global: true)`.
  /// an empty `Never` map fits every model type.
  Map<String, QueryBuilder<T> Function(QueryBuilder<T>)> get globalScopes =>
      const <String, Never>{};

  /// true when the model has global scopes
  bool get hasGlobalScopes => globalScopes.isNotEmpty;

  bool _globalScopesDone = false;
  bool _noGlobalScopes = false;
  Set<String>? _skippedScopes;

  /// leave out the global scope [name] in this query
  ///
  /// ```
  /// await User().withoutGlobalScope('active').get();
  /// ```
  QueryBuilder<T> withoutGlobalScope(String name) {
    (_skippedScopes ??= <String>{}).add(name);
    return this;
  }

  /// leave out every global scope in this query
  QueryBuilder<T> withoutGlobalScopes() {
    _noGlobalScopes = true;
    return this;
  }

  /// adds the global scopes to the where conditions, once, when the sql
  /// is made. the conditions so far go in brackets, and each scope too,
  /// so an OR in one part can not skip another part.
  void applyGlobalScopes() {
    if (_globalScopesDone) return;
    _globalScopesDone = true;
    Map<String, QueryBuilder<T> Function(QueryBuilder<T>)> scopes =
        globalScopes;
    if (_noGlobalScopes || scopes.isEmpty) return;
    groupWheres(0);
    for (MapEntry<String, QueryBuilder<T> Function(QueryBuilder<T>)> e
        in scopes.entries) {
      if (_skippedScopes?.contains(e.key) == true) continue;
      int from = whereCount;
      e.value(this);
      groupWheres(from);
    }
  }

  /// **** map

  /// the row this model was made from
  Map<String, dynamic> get originalMap => _originalMap ??= <String, dynamic>{};
  set originalMap(Map<String, dynamic> value) => _originalMap = value;
  Map<String, dynamic>? _originalMap;

  // coverage:ignore-start
  Map<String, dynamic> convertToMap(dynamic i) {
    return <String, dynamic>{};
  }

  Future<void> initPreload(List<Model<T>> list) async {}

  dynamic fromMap(Map<String, dynamic> m) {}
  // coverage:ignore-end

  /// **** map

  /// run [callback] in one database transaction.
  /// it commits when [callback] ends, and rolls back when it throws
  /// (the error is thrown again). queries and models inside use the
  /// transaction. a nested call joins the outer transaction.
  ///
  /// ```
  /// await QueryBuilder.transaction(() async {
  ///   await Blog().create({'title': 'a', 'body': 'b'});
  ///   await QueryBuilder.table('blog_info').insert({'blog_id': 1});
  /// });
  /// ```
  static Future<R> transaction<R>(
    Future<R> Function() callback, {
    String? connection,
  }) {
    return SqlQueryBuilder().getDBDriver(connection).transaction(callback);
  }

  /// run a raw query. [connection] is a connection name, the default
  /// connection is used when it is null.
  ///
  /// ```
  /// var rows = await QueryBuilder.query(
  ///   'select * from blog where id = @id',
  ///   substitutionValues: {'id': 1},
  ///   connection: 'mysql',
  /// );
  /// ```
  static Future<List<Map<String, dynamic>>> query(
    String query, {
    Map<String, dynamic>? substitutionValues = const <String, dynamic>{},
    String? connection,
  }) {
    return SqlQueryBuilder()
        .getDBDriver(connection)
        .query(query, substitutionValues: substitutionValues);
  }
}

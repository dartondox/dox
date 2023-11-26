import 'package:dox_query_builder/dox_query_builder.dart';

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
        Count<T> {
  Map<String, dynamic> _substitutionValues = <String, dynamic>{};

  dynamic self;

  @override
  QueryBuilder<T> get queryBuilder => this;

  @override
  String primaryKey = 'id';

  @override
  DBDriver get db => SqlQueryBuilder().db;

  @override
  QueryBuilderHelper<T> get helper => QueryBuilderHelper<T>(this);

  // coverage:ignore-start
  @override
  Logger get logger => Logger();
  // coverage:ignore-end

  @override
  bool shouldDebug = SqlQueryBuilder().debug;

  @override
  Map<String, dynamic> get substitutionValues => _substitutionValues;

  @override
  String get selectQueryString => getSelectQuery();

  List<String> getPreload() => <String>[];

  @override
  bool isSoftDeletes = false;

  @override
  String tableName = '';

  @override
  dynamic addSubstitutionValues(String key, dynamic value) {
    return _substitutionValues[key] = value;
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
  /// set table name [tableName] as first parameter
  /// and model instance [type] in second parameter [type] is optional
  /// this return QueryBuilder
  static QueryBuilder<T> table<T>(String tableName, [dynamic type]) {
    QueryBuilder<T> builder = QueryBuilder<T>();
    builder.tableName = tableName;
    builder.self = type;
    return builder;
  }

  /// set debug on or of
  ///
  /// ```
  /// QueryBuilder.table('blog').debug(true)
  /// ```
  QueryBuilder<T> debug([bool? debug]) {
    shouldDebug = debug ?? true;
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
    isSoftDeletes = !withTrashed;
    return queryBuilder;
  }

  /// **** map

  Map<String, dynamic> originalMap = <String, dynamic>{};

  // coverage:ignore-start
  Map<String, dynamic> convertToMap(dynamic i) {
    return <String, dynamic>{};
  }

  Future<void> initPreload(List<Model<T>> list) async {}

  dynamic fromMap(Map<String, dynamic> m) {}
  // coverage:ignore-end

  /// **** map

  /// /// Direct raw query to database
  /// ```
  /// var result = await QueryBuilder.query('select * from blog where id =  @id', {'id' : 1});
  ///
  static Future<List<Map<String, Map<String, dynamic>>>> query(
    String query, {
    Map<String, dynamic>? substitutionValues = const <String, dynamic>{},
  }) {
    return SqlQueryBuilder().db.mappedResultsQuery(
          query,
          substitutionValues: substitutionValues,
        );
  }
}

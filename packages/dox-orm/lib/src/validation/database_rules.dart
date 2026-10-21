import 'package:dox_validation/dox_validation.dart';

import '../query_builder.dart';

/// Reads rows for [Unique] and [Exists]. Soft-deleted rows count too,
/// because it reads the table, not the model.
class RowFinder {
  const RowFinder();

  /// The values of [values] that are in [column] of [table], as text.
  /// When [exceptColumn] is set, rows where it equals [exceptValue] are
  /// left out. One `WHERE IN` query.
  Future<Set<String>> found(
    String table,
    String column,
    List<Object?> values, {
    String? exceptColumn,
    Object? exceptValue,
    String? connection,
  }) async {
    QueryBuilder<dynamic> query = QueryBuilder.table(table)
        .select(column)
        .whereIn(column, values);
    if (exceptColumn != null) {
      query = query.where(exceptColumn, '!=', exceptValue);
    }
    if (connection != null) query = query.withConnection(connection);
    List<dynamic> rows = await query.get();
    Set<String> found = <String>{};
    for (dynamic row in rows) {
      if (row is Map) found.add('${row[column]}');
    }
    return found;
  }
}

/// No row in [table] has this value.
///
/// ```dart
/// @Unique('users', column: 'email')
/// final String email;
///
/// // PUT /users/{id}: skip the row being updated
/// @Unique('users', column: 'email', ignoreParam: 'id')
/// final String email;
/// ```
/// [column] defaults to the input key. On a `List` field each item is
/// checked, all in one query.
class Unique extends AsyncRule<Object?> {
  const Unique(
    this.table, {
    this.column,
    this.ignoreParam,
    this.ignoreColumn = 'id',
    this.connection,
    this.finder = const RowFinder(),
    super.message,
  });

  final String table;
  final String? column;

  /// A path param name. The row where [ignoreColumn] equals it is skipped.
  final String? ignoreParam;
  final String ignoreColumn;

  /// A `dox_orm` connection name. Default: the default connection.
  final String? connection;
  final RowFinder finder;

  @override
  String get name => 'unique';

  @override
  String get defaultMessage => 'The {field} has already been taken';

  @override
  Future<bool> checkAsync(Object? value, RuleContext context) async {
    return (await failedItems(<Object?>[value], context)).isEmpty;
  }

  @override
  Future<List<int>> failedItems(
    List<Object?> values,
    RuleContext context,
  ) async {
    String? param = ignoreParam;
    String? skip = param == null ? null : context.state.params[param];
    Set<String> taken = await finder.found(
      table,
      column ?? context.field,
      values,
      exceptColumn: skip == null ? null : ignoreColumn,
      exceptValue: skip == null ? null : (int.tryParse(skip) ?? skip),
      connection: connection,
    );
    return <int>[
      for (int i = 0; i < values.length; i++)
        if (taken.contains('${values[i]}')) i,
    ];
  }
}

/// A row in [table] has this value: `@Exists('teams')`.
/// [column] defaults to `id`.
/// On a `List` field each item is checked, all in one query.
class Exists extends AsyncRule<Object?> {
  const Exists(
    this.table, {
    this.column = 'id',
    this.connection,
    this.finder = const RowFinder(),
    super.message,
  });

  final String table;
  final String column;

  /// A `dox_orm` connection name. Default: the default connection.
  final String? connection;
  final RowFinder finder;

  @override
  String get name => 'exists';

  @override
  String get defaultMessage => 'The selected {field} is invalid';

  @override
  Future<bool> checkAsync(Object? value, RuleContext context) async {
    return (await failedItems(<Object?>[value], context)).isEmpty;
  }

  @override
  Future<List<int>> failedItems(
    List<Object?> values,
    RuleContext context,
  ) async {
    Set<String> found = await finder.found(
      table,
      column,
      values,
      connection: connection,
    );
    return <int>[
      for (int i = 0; i < values.length; i++)
        if (!found.contains('${values[i]}')) i,
    ];
  }
}

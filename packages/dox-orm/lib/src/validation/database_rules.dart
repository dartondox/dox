import 'package:dox_validation/dox_validation.dart';

import '../query_builder.dart';

/// Counts rows where `column = value`. The default uses the default
/// connection of the query builder. Swap it in tests.
class RowCounter {
  const RowCounter();

  /// Number of rows in [table] where [column] is [value].
  /// When [exceptColumn] is set, rows where it equals [exceptValue] are
  /// not counted.
  Future<int> count(
    String table,
    String column,
    Object? value, {
    String? exceptColumn,
    Object? exceptValue,
  }) {
    QueryBuilder<dynamic> query = QueryBuilder.table(table)
        .where(column, value);
    if (exceptColumn != null) {
      query = query.where(exceptColumn, '!=', exceptValue);
    }
    return query.count();
  }
}

/// `unique:table,column,except,idColumn`: no other row has this value.
///
/// - `unique:users` checks the column with the field name.
/// - `unique:users,email,5` ignores the row with `id = 5` (for updates).
/// - `unique:users,email,5,user_id` uses `user_id` instead of `id`.
class UniqueRule extends AsyncRule<Object?> {
  UniqueRule({
    required this.table,
    required this.column,
    this.except,
    this.idColumn = 'id',
    this.counter = const RowCounter(),
    super.message,
  });

  final String table;
  final String column;
  final String? except;
  final String idColumn;
  final RowCounter counter;

  @override
  String get name => 'unique';

  @override
  String get defaultMessage => 'The {field} has already been taken';

  @override
  Future<bool> checkAsync(Object? value, RuleContext context) async {
    String? skip = except;
    bool hasExcept = skip != null && skip.isNotEmpty && skip != 'NULL';
    int total = await counter.count(
      table,
      column,
      value,
      exceptColumn: hasExcept ? idColumn : null,
      exceptValue: hasExcept ? (int.tryParse(skip) ?? skip) : null,
    );
    return total == 0;
  }
}

/// `exists:table,column`: a row with this value must exist.
class ExistsRule extends AsyncRule<Object?> {
  ExistsRule({
    required this.table,
    required this.column,
    this.counter = const RowCounter(),
    super.message,
  });

  final String table;
  final String column;
  final RowCounter counter;

  @override
  String get name => 'exists';

  @override
  String get defaultMessage => 'The selected {field} is invalid';

  @override
  Future<bool> checkAsync(Object? value, RuleContext context) async {
    return await counter.count(table, column, value) > 0;
  }
}

/// Adds the database rules `unique` and `exists` to a [Validator].
/// `SqlQueryBuilder.initialize()` adds them to the global `v`, so dox
/// apps get them when the database is set up.
///
/// ```dart
/// await req.validateAsync({'email': 'required|email|unique:users,email'});
/// ```
class DatabaseRules {
  const DatabaseRules({this.counter = const RowCounter()});

  final RowCounter counter;

  /// Register `unique` and `exists` on [validator].
  void registerOn(Validator validator) {
    validator.registerRule('unique', _unique);
    validator.registerRule('exists', _exists);
  }

  Rule<Object?> _unique(RuleDefinition d) {
    return UniqueRule(
      table: _table(d),
      column: d.arg(1, _fieldName(d)),
      except: d.args.length > 2 ? d.arg(2) : null,
      idColumn: d.arg(3, 'id'),
      counter: counter,
    );
  }

  Rule<Object?> _exists(RuleDefinition d) {
    return ExistsRule(
      table: _table(d),
      column: d.arg(1, _fieldName(d)),
      counter: counter,
    );
  }

  String _table(RuleDefinition d) {
    String table = d.arg(0);
    if (table.isEmpty) {
      throw ArgumentError('Rule "${d.name}" on "${d.field}" needs a table');
    }
    return table;
  }

  String _fieldName(RuleDefinition d) => d.field.split('.').last;
}

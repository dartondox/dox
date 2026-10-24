import 'query_builder.dart';
import 'shared_mixin.dart';

mixin OrderBy<T> implements SharedMixin<T> {
  final List<String> _orderBy = <String>[];

  String getOrderByQuery() {
    if (_orderBy.isNotEmpty) {
      return " ORDER BY ${_orderBy.join(',')}";
    }
    return "";
  }

  /// order by query
  ///
  /// ```
  /// List blogs = await Blog().orderBy('id').get()
  /// List blogs = await Blog().orderBy('id', 'desc').get()
  /// ```
  QueryBuilder<T> orderBy(dynamic column, [dynamic type]) {
    /// only allow asc or desc, to block sql injection from user input
    if (type != null &&
        !<String>['asc', 'desc'].contains(type.toString().toLowerCase())) {
      throw ArgumentError.value(type, 'type', 'must be asc or desc');
    }
    _orderBy.add(
      '${helper.wrap(column.toString())} ${type == null ? '' : type.toString()}',
    );
    return queryBuilder;
  }

  /// order by raw query, nothing is quoted. never put user input in it.
  ///
  /// ```
  /// List blogs = await Blog().orderByRaw('count(*) desc').get()
  /// ```
  QueryBuilder<T> orderByRaw(String query) {
    _orderBy.add(query);
    return queryBuilder;
  }
}

import 'query_builder.dart';
import 'shared_mixin.dart';

mixin Select<T> implements SharedMixin<T> {
  String _select = '*';

  String getSelectQuery() {
    return _select;
  }

  /// Select query
  ///
  /// ```
  /// await Blog().select('title, body').get();
  /// await Blog().select('title').select('body').get();
  /// await Blog().select(['title', 'body']).get();
  /// await Blog().select(['title', 'body']).get();
  /// ```
  /// [selection] can be string or array
  QueryBuilder<T> select(dynamic selection) {
    if (selection is List<String>) {
      _select = selection.join(',');
    }
    if (selection is String) {
      _select = selection;
    }
    return queryBuilder;
  }
}

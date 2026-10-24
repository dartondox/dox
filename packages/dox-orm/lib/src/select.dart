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
  /// await Blog().select(['title', 'body as content']).get();
  /// ```
  /// [selection] can be string or array.
  /// column names are quoted. it throws an [ArgumentError] when a part is
  /// not a plain name. use selectRaw() for expressions like `count(*)`.
  QueryBuilder<T> select(dynamic selection) {
    if (selection is List<String>) {
      _select = selection.map(helper.wrap).join(',');
    }
    if (selection is String) {
      _select = selection.split(',').map(helper.wrap).join(',');
    }
    return queryBuilder;
  }

  /// Select raw query, nothing is quoted
  ///
  /// ```
  /// await Blog().selectRaw('DISTINCT title').get();
  /// ```
  QueryBuilder<T> selectRaw(String query) {
    _select = query;
    return queryBuilder;
  }
}

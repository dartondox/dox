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
  /// await Blog().select(['title', 'count(*) as total']).get();
  /// ```
  /// [selection] can be string or array.
  /// column names are quoted. a part with `(` is kept as it is.
  /// use selectRaw() for anything else.
  QueryBuilder<T> select(dynamic selection) {
    if (selection is List<String>) {
      _select = selection.map(helper.wrap).join(',');
    }
    if (selection is String) {
      _select = _splitColumns(selection).map(helper.wrap).join(',');
    }
    return queryBuilder;
  }

  /// split 'a, count(x, y) as b' into ['a', 'count(x, y) as b'].
  /// commas inside brackets do not split.
  List<String> _splitColumns(String selection) {
    List<String> parts = <String>[];
    int depth = 0;
    int start = 0;
    for (int i = 0; i < selection.length; i++) {
      String char = selection[i];
      if (char == '(') depth++;
      if (char == ')') depth--;
      if (char == ',' && depth == 0) {
        parts.add(selection.substring(start, i));
        start = i + 1;
      }
    }
    parts.add(selection.substring(start));
    return parts;
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

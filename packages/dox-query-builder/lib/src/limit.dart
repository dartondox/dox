import 'query_builder.dart';
import 'shared_mixin.dart';

mixin Limit<T> implements SharedMixin<T> {
  String _limit = '';
  String _offset = '0';

  String getLimitQuery() {
    if (_limit.isNotEmpty) {
      return " LIMIT $_limit OFFSET $_offset";
    }
    return "";
  }

  /// limit query
  ///
  /// ```
  /// List blogs = await Blog().take(10).get()
  /// ```
  QueryBuilder<T> take(int value) {
    _limit = value.toString();
    return queryBuilder;
  }

  /// limit query
  ///
  /// ```
  /// List blogs = await Blog().limit(10).get()
  /// ```
  QueryBuilder<T> limit(int value) {
    _limit = value.toString();
    return queryBuilder;
  }

  /// offset limit
  ///
  /// ```
  /// List blogs = await Blog().limit(10).offset(10).get()
  /// ```
  QueryBuilder<T> offset(int value) {
    _offset = value.toString();
    return queryBuilder;
  }
}

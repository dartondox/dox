import 'package:dox_orm/dox_orm.dart';

import 'shared_mixin.dart';

mixin Limit<T> implements SharedMixin<T> {
  int? _limit;
  int? _offset;

  /// only the parts that were set. `OFFSET 0` is left out.
  String getLimitQuery() {
    int? offset = _offset == 0 ? null : _offset;
    if (_limit != null) {
      return offset == null
          ? " LIMIT $_limit"
          : " LIMIT $_limit OFFSET $offset";
    }
    if (offset == null) {
      return "";
    }

    /// OFFSET without LIMIT: mysql and sqlite need a LIMIT
    switch (dbDriver.getName()) {
      case Driver.mysql:
        return " LIMIT 18446744073709551615 OFFSET $offset";
      case Driver.sqlite:
        return " LIMIT -1 OFFSET $offset";
      case Driver.postgres:
        return " OFFSET $offset";
    }
  }

  /// limit query
  ///
  /// ```
  /// List blogs = await Blog().take(10).get()
  /// ```
  QueryBuilder<T> take(int value) {
    _limit = value;
    return queryBuilder;
  }

  /// limit query
  ///
  /// ```
  /// List blogs = await Blog().limit(10).get()
  /// ```
  QueryBuilder<T> limit(int value) {
    _limit = value;
    return queryBuilder;
  }

  /// offset limit
  ///
  /// ```
  /// List blogs = await Blog().limit(10).offset(10).get()
  /// ```
  QueryBuilder<T> offset(int value) {
    _offset = value;
    return queryBuilder;
  }
}

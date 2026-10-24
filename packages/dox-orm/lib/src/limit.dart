import 'package:dox_orm/dox_orm.dart';

import 'shared_mixin.dart';

mixin Limit<T> implements SharedMixin<T> {
  int? _limit;
  int? _offset;

  /// param names of the LIMIT and OFFSET values. they are params, so
  /// every page gives the same sql and the drivers reuse one statement.
  static const String limitKey = 'dox_limit';
  static const String offsetKey = 'dox_offset';

  /// only the parts that were set. `OFFSET 0` is left out.
  String getLimitQuery() {
    int? offset = _offset == 0 ? null : _offset;
    if (_limit == null && _offset == null) return "";
    Map<String, dynamic> values = substitutionValues;
    if (_limit != null) {
      values[limitKey] = _limit;
    } else {
      values.remove(limitKey);
    }
    if (offset != null) {
      values[offsetKey] = offset;
    } else {
      values.remove(offsetKey);
    }
    if (_limit != null) {
      return offset == null
          ? " LIMIT @$limitKey"
          : " LIMIT @$limitKey OFFSET @$offsetKey";
    }
    if (offset == null) {
      return "";
    }

    /// OFFSET without LIMIT: mysql and sqlite need a LIMIT
    switch (dbDriver.getName()) {
      case Driver.mysql:
        return " LIMIT 18446744073709551615 OFFSET @$offsetKey";
      case Driver.sqlite:
        return " LIMIT -1 OFFSET @$offsetKey";
      case Driver.postgres:
        return " OFFSET @$offsetKey";
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

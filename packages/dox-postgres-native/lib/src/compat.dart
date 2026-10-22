// The parts of the `postgres` package that make this driver act the same:
// the `@name` parser and the server exceptions. They are not public API,
// so they all live in this one file.
// ponytail: pinned to postgres ^3.5.20. Check this file when it moves to 4.x.
// ignore_for_file: implementation_imports
import 'dart:convert';
import 'dart:typed_data';

import 'package:postgres/postgres.dart';
import 'package:postgres/src/exceptions.dart' as pg;
import 'package:postgres/src/messages/server_messages.dart' as pg;
import 'package:postgres/src/v3/query_description.dart' as pg;

/// SQL with `@name` (or `$1`) parameters, parsed once and cached.
class ParsedSql {
  ParsedSql._(this._description, String sql) : sql = utf8.encode(sql);

  final pg.InternalQueryDescription _description;

  /// the SQL with `$1, $2...` as the server wants it, in UTF-8
  final Uint8List sql;

  static final Map<String, ParsedSql> _named = <String, ParsedSql>{};
  static final Map<String, ParsedSql> _direct = <String, ParsedSql>{};

  /// Parses [sql] with `@name` parameters, like `Sql.named`.
  static ParsedSql named(String sql) {
    ParsedSql? hit = _named[sql];
    if (hit != null) return hit;
    // ponytail: a simple clear, an LRU if apps send many different queries
    if (_named.length > 1024) _named.clear();
    pg.InternalQueryDescription d = pg.InternalQueryDescription.named(sql);
    return _named[sql] = ParsedSql._(d, d.transformedSql);
  }

  /// [sql] as it is, with `$1, $2...` parameters.
  static ParsedSql direct(String sql) {
    ParsedSql? hit = _direct[sql];
    if (hit != null) return hit;
    if (_direct.length > 1024) _direct.clear();
    return _direct[sql] = ParsedSql._(
      pg.InternalQueryDescription.direct(sql),
      sql,
    );
  }

  /// The values in the order of `$1, $2...`. Throws [ArgumentError] for a
  /// missing or an unknown name, like the `postgres` package.
  List<TypedValue<Object>> bind(Object? parameters) {
    Map<String, int>? names = _description.namedVariables;
    // the common case without the Set of `bindParameters`: a map with
    // exactly the names of the SQL. The rest (and errors) go there.
    if (parameters is Map && names != null) {
      if (parameters.length == names.length) {
        List<Type<Object>?> types = _description.parameterTypes!;
        List<TypedValue<Object>> out = <TypedValue<Object>>[];
        int i = 0;
        for (String name in names.keys) {
          if (!parameters.containsKey(name)) break;
          out.add(_value(parameters[name], types[i++]));
        }
        if (out.length == names.length) return out;
      }
    }
    return _description.bindParameters(parameters);
  }

  /// Same as `_toParameter` of the `postgres` package.
  static TypedValue<Object> _value(Object? value, Type<Object>? known) {
    if (value is TypedValue) {
      if (value.type != Type.unspecified) return value;
      value = value.value;
    }
    if (known != null && known != Type.unspecified) {
      return TypedValue<Object>(known, value);
    }
    if (value is TsVector) return TypedValue<Object>(Type.tsvector, value);
    if (value is TsQuery) return TypedValue<Object>(Type.tsquery, value);
    return TypedValue<Object>(Type.unspecified, value);
  }
}

/// The exception the `postgres` package throws for these server error
/// fields (eg. `UniqueViolationException` for code 23505).
PgException serverException(List<(int, String)> fields) {
  return pg.transformServerException(
    pg.buildExceptionFromErrorFields(<pg.ErrorField>[
      for ((int, String) f in fields) pg.ErrorField(f.$1, f.$2),
    ]),
  );
}

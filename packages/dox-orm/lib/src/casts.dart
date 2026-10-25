import 'dart:convert';

/// Changes a column value between the database and Dart.
/// Use it with `@Column(cast: ...)`. The class needs a const constructor.
///
/// ```
/// class MoneyCast extends Cast<Money> {
///   const MoneyCast();
///
///   @override
///   Money? get(dynamic value) => value == null ? null : Money(value as int);
///
///   @override
///   dynamic set(Money? value) => value?.cents;
/// }
///
/// @Column(cast: MoneyCast())
/// Money? price;
/// ```
abstract class Cast<T> {
  const Cast();

  /// the value from the database to the Dart value
  T? get(dynamic value);

  /// the Dart value to the value for the database (and toJson)
  dynamic set(T? value);
}

/// A json column (or json text) to a map or list.
/// The drivers save a map or list as json text.
class JsonCast extends Cast<dynamic> {
  const JsonCast();

  @override
  dynamic get(dynamic value) => value is String ? jsonDecode(value) : value;

  @override
  dynamic set(dynamic value) => value;
}

/// A json column (or json text) to a typed list, like `List<String>`.
class ListCast<E> extends Cast<List<E>> {
  const ListCast();

  @override
  List<E>? get(dynamic value) {
    dynamic list = value is String ? jsonDecode(value) : value;
    return list == null ? null : List<E>.from(list as List<dynamic>);
  }

  @override
  dynamic set(List<E>? value) => value;
}

/// A bool from a bool, a number (like tinyint 0 and 1) or a text
/// (`1`, `0`, `true`, `false`, `t`, `f`).
/// A `bool` field gets it without `cast`.
class BoolCast extends Cast<bool> {
  const BoolCast();

  @override
  bool? get(dynamic value) {
    if (value == null || value is bool) return value as bool?;
    if (value is num) return value != 0;
    String text = value.toString().toLowerCase();
    return text == '1' || text == 'true' || text == 't';
  }

  @override
  dynamic set(bool? value) => value;
}

/// An enum, saved by its name, or by its index with `byIndex: true`.
/// An enum field gets `EnumCast(values)` (by name) without `cast`.
///
/// ```
/// @Column(cast: EnumCast(Status.values, byIndex: true))
/// Status? status;
/// ```
class EnumCast<E extends Enum> extends Cast<E> {
  final List<E> values;
  final bool byIndex;

  const EnumCast(this.values, {this.byIndex = false});

  @override
  E? get(dynamic value) {
    if (value == null) return null;
    if (byIndex) return values[int.parse(value.toString())];
    return values.byName(value.toString());
  }

  @override
  dynamic set(E? value) => byIndex ? value?.index : value?.name;
}

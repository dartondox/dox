import '../core/rule.dart';

/// Base for the built-in rules. It keeps name, message, params and
/// JSON Schema hints in fields, so each rule only writes [check].
abstract class BuiltInRule<T> extends Rule<T> {
  BuiltInRule(
    this._name,
    this._defaultMessage, {
    super.message,
    this._params = const <String, Object?>{},
    this._json = const <String, dynamic>{},
  });

  final String _name;
  final String _defaultMessage;
  final Map<String, Object?> _params;
  final Map<String, dynamic> _json;

  @override
  String get name {
    return _name;
  }

  @override
  String get defaultMessage {
    return _defaultMessage;
  }

  @override
  Map<String, Object?> get params {
    return _params;
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{..._json};
  }
}

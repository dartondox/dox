import 'package:dox_validation/dox_validation.dart' hide ValidationException;

/// Old dox validator API, kept for apps that use it directly.
/// It runs on `dox_validation` (`v.fromRules()`), like `req.validate()`.
///
/// ```
/// DoxValidator validator = DoxValidator(data);
/// validator.validate({'email': 'required|email'});
/// if (validator.hasError) print(validator.errors);
/// ```
class DoxValidator {
  /// request data
  final Map<String, dynamic> data;

  final Map<String, String> _errors = <String, String>{};
  final Map<String, String> _messages = <String, String>{};
  Validator? _validator;

  DoxValidator(this.data);

  /// check validation has errors
  bool get hasError => _errors.isNotEmpty;

  /// get list of error messages
  Map<String, String> get errors => _errors;

  /// add custom rule
  /// ```
  /// validator.addCustomRule('even', message: 'The {field} must be even',
  ///   fn: (Map<String, dynamic> data, dynamic value, String? args) {
  ///     return value is int && value.isEven;
  ///   });
  /// ```
  void addCustomRule(
    String ruleName, {
    required String message,
    required bool Function(Map<String, dynamic>, dynamic, String?) fn,
  }) {
    Validator validator = _validator ??= Validator();
    validator.registerRule(ruleName, (RuleDefinition definition) {
      return _CustomRule(
        ruleName,
        message,
        fn,
        data,
        definition.args.join(','),
      );
    });
  }

  /// set custom validator messages by rule name
  /// ```
  /// validator.setMessages({'required': 'The {field} is required'});
  /// ```
  void setMessages(Map<String, String> messages) {
    _messages.addAll(messages);
  }

  /// validate your data
  /// ```
  /// validator.validate({'field' : 'required|string'});
  /// ```
  void validate(Map<String, String> rules) {
    ObjectSchema schema = (_validator ?? v).fromRules(
      rules,
      messages: _messages,
    );
    ParseResult<Map<String, dynamic>> result = schema.safeParse(data);
    _errors.addAll(result.errors);
  }

  /// same as [validate], and also runs async rules like `unique`
  Future<void> validateAsync(Map<String, String> rules) async {
    ObjectSchema schema = (_validator ?? v).fromRules(
      rules,
      messages: _messages,
    );
    ParseResult<Map<String, dynamic>> result = await schema.safeParseAsync(
      data,
    );
    _errors.addAll(result.errors);
  }
}

class _CustomRule extends Rule<Object?> {
  _CustomRule(this._name, this._message, this._fn, this._data, this._args);

  final String _name;
  final String _message;
  final bool Function(Map<String, dynamic>, dynamic, String?) _fn;
  final Map<String, dynamic> _data;
  final String _args;

  @override
  String get name => _name;

  @override
  String get defaultMessage => _message;

  @override
  bool check(Object? value, RuleContext context) {
    return _fn(_data, value, _args);
  }
}

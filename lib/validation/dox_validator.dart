import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/logger.dart';
import 'package:dox_core/validation/nested_validation_visitor.dart';
import 'package:dox_core/validation/validation_item.dart';
import 'package:dox_core/validation/validation_rules.dart';
import 'package:sprintf/sprintf.dart';

class DoxValidator {
  /// request data
  final Map<String, dynamic> data;

  /// internal constants
  final Map<String, String> _errors = <String, String>{};
  List<String> get _methodNoNeedToSplitArguments => <String>['in'];

  DoxValidator(this.data);

  /// check validation has errors
  bool get hasError => _errors.isNotEmpty;

  /// get list of error messages
  Map<String, String> get errors => _errors;

  /// add custom rule
  /// ```
  /// validator.addCustomRule('unique', {
  ///   message: 'The {value} already exist',
  ///   fn: (Map<String, dynamic> data, dynamic value, String? arguments) {
  ///     /// add your logic here
  ///   }
  /// });
  /// ```
  void addCustomRule(
    String ruleName, {
    required String message,
    required bool Function(Map<String, dynamic>, dynamic, String?) fn,
  }) {
    _matchings[ruleName] = <String, dynamic>{
      'message': message,
      'function': fn,
    };
  }

  /// set custom validator messages
  /// ```
  /// validator.setMessages({'required': 'The {attribute} is required});
  /// ```
  void setMessages(Map<String, String> messages) {
    messages.forEach((String key, String value) {
      if (_matchings[key] != null) {
        _matchings[key]?['message'] = value;
      }
    });
  }

  /// validate your data
  /// ```
  /// validator.validate({'field' : 'required|string'});
  /// ```
  void validate(Map<String, String> rules) {
    rules.forEach((String field, String rule) {
      if (_isNestedValidation(field)) {
        NestedValidationVisitor v =
            NestedValidationVisitor(data: data, field: field, rule: rule);
        for (ValidationItem item in v.fieldsToValidate) {
          _validateItem(item);
        }
      } else {
        _validateItem(ValidationItem(
          field: field,
          name: field.split('.').last,
          value: data.getParam(field),
          rule: rule,
        ));
      }
    });
  }

  bool _isNestedValidation(String field) {
    return field.contains('.*.');
  }

  void _validateItem(ValidationItem item) {
    List<String> rulesForEachName = item.rule.split('|');
    for (String rule in rulesForEachName) {
      String? error =
          _applyMatchingRule(item.field, item.name, item.value, rule);
      if (error != null) {
        _errors[item.field] = error;
        break;
      }
    }
  }

  String? _applyMatchingRule(
      String field, String name, dynamic value, String rule) {
    List<String> parts = rule.split(':');
    String ruleKey = parts.first.toString().toLowerCase();
    String args = parts.length >= 2 ? parts[1] : '';
    Map<String, dynamic>? match = _matchings[ruleKey];
    if (match == null) {
      DoxLogger.warn("$ruleKey rule doesn't exist.");
      return null;
    }

    bool result =
        Function.apply(match['function'], <dynamic>[data, value, args]);
    if (result == true) {
      return null;
    }
    String error = match['message']
        .toString()
        .replaceAll('{attribute}', name)
        .replaceAll('{value}', value == null ? '' : value.toString());

    if (args.isNotEmpty) {
      List<String> arguments = _methodNoNeedToSplitArguments.contains(ruleKey)
          ? <String>[args.split(',').joinWithAnd()]
          : args.split(',');
      return sprintf(error, arguments);
    }

    return error;
  }

  final Map<String, Map<String, dynamic>> _matchings =
      <String, Map<String, dynamic>>{
    'required': <String, dynamic>{
      'message': 'The {attribute} is required',
      'function': Rules.isRequired,
    },
    'email': <String, dynamic>{
      'message': 'The {attribute} is not a valid email',
      'function': Rules.isEmail,
    },
    'string': <String, dynamic>{
      'message': 'The {attribute} must be a string',
      'function': Rules.isString,
    },
    'numeric': <String, dynamic>{
      'message': 'The {attribute} must be a number',
      'function': Rules.isNumeric,
    },
    'ip': <String, dynamic>{
      'message': 'The {attribute} must be an ip address',
      'function': Rules.isIp,
    },
    'boolean': <String, dynamic>{
      'message': 'The {attribute} must be a boolean',
      'function': Rules.isBoolean,
    },
    'integer': <String, dynamic>{
      'message': 'The {attribute} must be an integer',
      'function': Rules.isInteger,
    },
    'double': <String, dynamic>{
      'message': 'The {attribute} must be a double',
      'function': Rules.isDouble,
    },
    'array': <String, dynamic>{
      'message': 'The {attribute} must be an array',
      'function': Rules.isArray,
    },
    'json': <String, dynamic>{
      'message': 'The {attribute} is not a valid json',
      'function': Rules.isJson,
    },
    'alpha': <String, dynamic>{
      'message': 'The {attribute} must be an alphabetic',
      'function': Rules.isAlpha,
    },
    'alpha_dash': <String, dynamic>{
      'message': 'The {attribute} must be only alphabetic and dash',
      'function': Rules.isAlphaDash,
    },
    'alpha_numeric': <String, dynamic>{
      'message': 'The {attribute} must be only alphabetic and number',
      'function': Rules.isAlphaNumeric,
    },
    'date': <String, dynamic>{
      'message': 'The {attribute} must be a date',
      'function': Rules.isDate,
    },
    'url': <String, dynamic>{
      'message': 'The {attribute} must be a url',
      'function': Rules.isUrl,
    },
    'uuid': <String, dynamic>{
      'message': 'The {attribute} is invalid uuid',
      'function': Rules.isUUID,
    },
    'min_length': <String, dynamic>{
      'message': 'The {attribute} must be at least %s character',
      'function': Rules.minLength,
    },
    'max_length': <String, dynamic>{
      'message': 'The {attribute} may not be greater than %s character',
      'function': Rules.maxLength,
    },
    'length_between': <String, dynamic>{
      'message': 'The {attribute} must be between %s and %s character',
      'function': Rules.lengthBetween,
    },
    'between': <String, dynamic>{
      'message': 'The {attribute} must be between %s and %s',
      'function': Rules.between,
    },
    'in': <String, dynamic>{
      'message': 'The selected {attribute} is invalid. Valid options are %s',
      'function': Rules.inArray,
    },
    'not_in': <String, dynamic>{
      'message': 'The {attribute} field cannot be {value}',
      'function': Rules.notInArray,
    },
    'start_with': <String, dynamic>{
      'message': 'The {attribute} must start with %s',
      'function': Rules.startWith,
    },
    'end_with': <String, dynamic>{
      'message': 'The {attribute} must end with %s',
      'function': Rules.endWith,
    },
    'greater_than': <String, dynamic>{
      'message': 'The {attribute} must be greater than %s',
      'function': Rules.greaterThan,
    },
    'less_than': <String, dynamic>{
      'message': 'The {attribute} must be less than %s',
      'function': Rules.lessThan,
    },
    'min': <String, dynamic>{
      'message': 'The {attribute} must be greater than or equal %s',
      'function': Rules.min,
    },
    'max': <String, dynamic>{
      'message': 'The {attribute} must be less than or equal %s',
      'function': Rules.max,
    },
    'confirmed': <String, dynamic>{
      'message': 'The two password did not match',
      'function': Rules.confirmed,
    },
    'required_if': <String, dynamic>{
      'message': 'The {attribute} is required',
      'function': Rules.requiredIf,
    },
    'required_if_not': <String, dynamic>{
      'message': 'The {attribute} is required',
      'function': Rules.requiredIfNot,
    },
    'image': <String, dynamic>{
      'message': 'The {attribute} is either invalid or unsupported extension',
      'function': Rules.isImage,
    },
    'file': <String, dynamic>{
      'message': 'The {attribute} is either invalid or unsupported extension',
      'function': Rules.isFile,
    },
  };
}

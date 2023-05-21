import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/logger.dart';
import 'package:dox_core/validation/rules.dart';
import 'package:sprintf/sprintf.dart';

class DoxValidator {
  final Map<String, dynamic> data;
  DoxValidator(this.data);

  final Map<String, dynamic> _errors = {};

  validate(Map<String, String> rules) {
    rules.forEach((field, rule) {
      dynamic value = data.getParam(field);
      var rulesForEachName = rule.split('|');
      for (String r in rulesForEachName) {
        String? error = _applyMatchingRule(field, value, r);
        if (error != null) {
          _errors[field] = error;
          break;
        }
      }
    });
  }

  String? _applyMatchingRule(String field, dynamic value, String rule) {
    List parts = rule.split(':');
    String key = parts.first;
    String? args = parts.length >= 2 ? parts[1] : '';
    var match = _matchings[key];
    if (match == null) {
      DoxLogger.warn("$key rule doesn't exist.");
      return null;
    }
    bool result = Function.apply(match['function'], [data, value, args]);
    if (result == false) {
      String error = match['message']
          .toString()
          .replaceAll('{attribute}', field)
          .replaceAll('{value}', value == null ? '' : value.toString());
      if (args != null && args.isNotEmpty) {
        var arguments = _methodNoNeedToSplitArguments.contains(key)
            ? [args.split(',').joinWithAnd()]
            : args.split(',');
        return sprintf(error, arguments);
      }
      return error;
    }
    return null;
  }

  List get _methodNoNeedToSplitArguments => ['in'];

  bool hasError() {
    return _errors.isNotEmpty;
  }

  Map<String, dynamic> getErrors() {
    return _errors;
  }

  addCustomRule(
    String ruleName, {
    required String message,
    required bool Function(Map<String, dynamic>, dynamic, String?) fn,
  }) {
    _matchings[ruleName] = {
      "message": message,
      "function": fn,
    };
  }

  final Map<String, Map<String, dynamic>> _matchings = {
    'required': {
      'message': 'The {attribute} is required',
      'function': Rules.isRequired,
    },
    'email': {
      'message': 'The {attribute} is not a valid email',
      'function': Rules.isEmail,
    },
    'string': {
      'message': 'The {attribute} must be a string',
      'function': Rules.isString,
    },
    'numeric': {
      'message': 'The {attribute} must be a number',
      'function': Rules.isNumeric,
    },
    'ip': {
      'message': 'The {attribute} must be an ip address',
      'function': Rules.isIp,
    },
    'boolean': {
      'message': 'The {attribute} must be a boolean',
      'function': Rules.isBoolean,
    },
    'integer': {
      'message': 'The {attribute} must be an integer',
      'function': Rules.isInteger,
    },
    'double': {
      'message': 'The {attribute} must be a double',
      'function': Rules.isDouble,
    },
    'array': {
      'message': 'The {attribute} must be an array',
      'function': Rules.isArray,
    },
    'json': {
      'message': 'The {attribute} is not a valid json',
      'function': Rules.isJson,
    },
    'alpha': {
      'message': 'The {attribute} must be an alphabetic',
      'function': Rules.isAlpha,
    },
    'alpha_dash': {
      'message': 'The {attribute} must be only alphabetic and dash',
      'function': Rules.isAlphaDash,
    },
    'alpha_numeric': {
      'message': 'The {attribute} must be only alphabetic and number',
      'function': Rules.isAlphaNumeric,
    },
    'date': {
      'message': 'The {attribute} must be a date',
      'function': Rules.isDate,
    },
    'url': {
      'message': 'The {attribute} must be a url',
      'function': Rules.isUrl,
    },
    'uuid': {
      'message': 'The {attribute} is invalid uuid',
      'function': Rules.isUUID,
    },
    'min_length': {
      'message': 'The {attribute} must be at least %s character',
      'function': Rules.minLength,
    },
    'max_length': {
      'message': 'The {attribute} may not be greater than %s character',
      'function': Rules.maxLength,
    },
    'length_between': {
      'message': 'The {attribute} must be between %s and %s character',
      'function': Rules.lengthBetween,
    },
    'between': {
      'message': 'The {attribute} must be between %s and %s',
      'function': Rules.between,
    },
    'in': {
      'message': 'The selected {attribute} is invalid. Valid options are %s',
      'function': Rules.inArray,
    },
    'not_in': {
      'message': 'The {attribute} field cannot be {value}',
      'function': Rules.notInArray,
    },
    'start_with': {
      'message': 'The {attribute} must start with %s',
      'function': Rules.startWith,
    },
    'end_with': {
      'message': 'The {attribute} must end with %s',
      'function': Rules.endWith,
    },
    'greater_than': {
      'message': 'The {attribute} must be greater than %s',
      'function': Rules.greaterThan,
    },
    'less_than': {
      'message': 'The {attribute} must be less than %s',
      'function': Rules.lessThan,
    },
    'min': {
      'message': 'The {attribute} must be greater than or equal %s',
      'function': Rules.min,
    },
    'max': {
      'message': 'The {attribute} must be less than or equal %s',
      'function': Rules.max,
    },
    'confirmed': {
      'message': 'The two password did not match',
      'function': Rules.confirmed,
    },
    'required_if': {
      'message': 'The {attribute} is required',
      'function': Rules.requiredIf,
    },
    'required_if_not': {
      'message': 'The {attribute} is required',
      'function': Rules.requiredIfNot,
    },
  };
}

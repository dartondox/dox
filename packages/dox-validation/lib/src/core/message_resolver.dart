import '../constants/schema_constants.dart';

/// Everything a [MessageResolver] needs to build one message.
class MessageRequest {
  MessageRequest({
    required this.code,
    required this.path,
    required this.params,
    required this.fallback,
    this.customMessage,
  });

  /// Issue code, like `required`.
  final String code;

  /// Path of the value.
  final List<Object> path;

  /// Placeholder values. Always has `field` and `value`.
  final Map<String, Object?> params;

  /// Default template from the rule.
  final String fallback;

  /// Message set on the rule itself, like `.min(3, message: '...')`.
  final String? customMessage;
}

/// Turns issue codes into messages.
///
/// Order of lookup:
/// 1. the message set on the rule (`.min(3, message: '...')`)
/// 2. `messages['path.code']`, like `email.required` or `items.*.name.required`
/// 3. `messages['code']`, like `required`
/// 4. the default English template
///
/// For i18n, extend this class and override [resolve], then set
/// [MessageResolver.global] or pass it to `safeParse(messages: ...)`.
class MessageResolver {
  MessageResolver({Map<String, String> messages = const <String, String>{}})
      : _messages = <String, String>{...messages};

  /// The resolver used when none is passed to `parse`.
  static MessageResolver global = MessageResolver();

  final Map<String, String> _messages;

  /// The custom templates, by key.
  Map<String, String> get messages {
    return Map<String, String>.unmodifiable(_messages);
  }

  /// Add or replace templates.
  void setMessages(Map<String, String> messages) {
    _messages.addAll(messages);
  }

  /// Build the final message.
  String resolve(MessageRequest request) {
    String template = request.customMessage ??
        _findTemplate(request.code, request.path) ??
        request.fallback;
    return format(template, request.params);
  }

  /// Fill placeholders in [template].
  ///
  /// `{name}` is replaced by `params['name']`. Each `%s` is replaced by
  /// the next item in `params['args']` (old dox style messages).
  String format(String template, Map<String, Object?> params) {
    String result = template;
    for (MapEntry<String, Object?> entry in params.entries) {
      if (entry.key == 'args') {
        continue;
      }
      result = result.replaceAll('{${entry.key}}', _text(entry.value));
    }
    Object? args = params['args'];
    if (args is List<Object?>) {
      for (Object? arg in args) {
        if (!result.contains('%s')) {
          break;
        }
        result = result.replaceFirst('%s', _text(arg));
      }
    }
    return result;
  }

  String? _findTemplate(String code, List<Object> path) {
    if (path.isNotEmpty) {
      String exact = '${path.join('.')}.$code';
      if (_messages.containsKey(exact)) {
        return _messages[exact];
      }
      String wildcard = '${_wildcardPath(path)}.$code';
      if (_messages.containsKey(wildcard)) {
        return _messages[wildcard];
      }
    }
    return _messages[code];
  }

  String _wildcardPath(List<Object> path) {
    List<String> parts = <String>[];
    for (Object part in path) {
      parts.add(part is int ? '*' : part.toString());
    }
    return parts.join('.');
  }

  String _text(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    return value.toString();
  }
}

/// Helper to make a short, readable text from a list of values.
class ListText {
  /// Join like `a, b, and c`. Same output as the old dox `joinWithAnd`.
  static String joinWithAnd(List<Object?> values) {
    List<String> items = <String>[];
    for (Object? value in values) {
      items.add(value.toString());
    }
    if (items.length <= 1) {
      return items.join();
    }
    String last = items.removeLast();
    return '${items.join(', ')}, and $last';
  }

  /// `true` when [text] is one of the true words, like `yes` or `1`.
  static bool isTrueWord(String text) {
    return SchemaConstants.trueWords.contains(text.trim().toLowerCase());
  }

  /// `true` when [text] is one of the false words, like `no` or `0`.
  static bool isFalseWord(String text) {
    return SchemaConstants.falseWords.contains(text.trim().toLowerCase());
  }
}

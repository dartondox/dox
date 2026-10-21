import 'package:dox_validation/dox_validation.dart';
import 'package:test/test.dart';

class SlugRule extends Rule<String> {
  SlugRule({super.message});

  @override
  String get name {
    return 'slug';
  }

  @override
  String get defaultMessage {
    return 'The {field} must be a slug';
  }

  @override
  bool check(String value, RuleContext context) {
    return RegExp(r'^[a-z0-9-]+$').hasMatch(value);
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{'pattern': r'^[a-z0-9-]+$'};
  }
}

class UniqueEmailRule extends AsyncRule<String> {
  UniqueEmailRule(this.taken);

  final List<String> taken;

  @override
  String get name {
    return 'unique';
  }

  @override
  String get defaultMessage {
    return 'The {field} has already been taken';
  }

  @override
  Future<bool> checkAsync(String value, RuleContext context) async {
    return !taken.contains(value);
  }
}

class MinWordsRule extends Rule<String> {
  MinWordsRule(this.count);

  final int count;

  @override
  String get name {
    return 'min_words';
  }

  @override
  String get defaultMessage {
    return 'The {field} needs {count} words';
  }

  @override
  Map<String, Object?> get params {
    return <String, Object?>{'count': count};
  }

  @override
  bool check(String value, RuleContext context) {
    return value.trim().split(RegExp(r'\s+')).length >= count;
  }
}

extension SlugMethods on StringSchema {
  StringSchema slug({String? message}) {
    return use(SlugRule(message: message));
  }
}

void main() {
  tearDown(() {
    MessageResolver.global = MessageResolver();
  });

  group('custom Rule |', () {
    test('use() adds the rule', () {
      StringSchema s = v.string().use(SlugRule());
      expect(s.parse('my-post'), 'my-post');
      ParseResult<String> result = s.safeParse('My Post');
      expect(result.issues.first.code, 'slug');
      expect(result.issues.first.message, 'The value must be a slug');
    });

    test('extension method works like a built-in', () {
      ObjectSchema s = v.object(<String, Schema<Object?>>{
        'slug': v.string().min(3).slug(message: 'Bad {field}'),
      });
      expect(s.safeParse(<String, dynamic>{'slug': 'A B'}).errors,
          <String, String>{'slug': 'Bad slug'});
    });

    test('params fill placeholders', () {
      ParseResult<String> result =
          v.string().use(MinWordsRule(3)).safeParse('one two');
      expect(result.issues.first.message, 'The value needs 3 words');
    });

    test('async rule', () async {
      StringSchema s = v.string().use(UniqueEmailRule(<String>['a@dox.dev']));
      expect(s.isAsync, true);
      ParseResult<String> result = await s.safeParseAsync('a@dox.dev');
      expect(result.issues.first.message, 'The value has already been taken');
    });

    test('rule JSON hint is merged', () {
      expect(v.string().slug().toJsonSchema(), <String, dynamic>{
        'type': 'string',
        'pattern': r'^[a-z0-9-]+$',
      });
    });
  });

  group('messages |', () {
    test('global resolver by code', () {
      v.messages.setMessages(<String, String>{
        'required': '{field} is needed',
      });
      ObjectSchema s = v.object(<String, Schema<Object?>>{'name': v.string()});
      expect(s.safeParse(<String, dynamic>{}).errors['name'], 'name is needed');
    });

    test('path specific and wildcard keys', () {
      MessageResolver resolver = MessageResolver(messages: <String, String>{
        'email.required': 'Email please',
        'items.*.name.required': 'Item name please',
      });
      ObjectSchema s = v.object(<String, Schema<Object?>>{
        'email': v.string(),
        'name': v.string(),
        'items': v.list(v.object(<String, Schema<Object?>>{
          'name': v.string(),
        })),
      });
      ParseResult<Map<String, dynamic>> result = s.safeParse(
        <String, dynamic>{
          'items': <Map<String, dynamic>>[<String, dynamic>{}],
        },
        messages: resolver,
      );
      expect(result.errors, <String, String>{
        'email': 'Email please',
        'name': 'The name is required',
        'items.0.name': 'Item name please',
      });
    });

    test('rule message wins over resolver', () {
      v.messages = MessageResolver(messages: <String, String>{
        'min_length': 'global',
      });
      expect(
          v
              .string()
              .min(3, message: 'local')
              .safeParse('a')
              .issues
              .first
              .message,
          'local');
      expect(v.string().min(3).safeParse('a').issues.first.message, 'global');
    });

    test('custom resolver subclass for i18n', () {
      ParseResult<String> result =
          v.string().safeParse(null, messages: GermanResolver());
      expect(result.issues.first.message, 'value ist erforderlich');
    });

    test('old %s placeholders', () {
      MessageResolver resolver = MessageResolver();
      expect(
          resolver.format('between %s and %s', <String, Object?>{
            'args': <Object?>[1, 5],
          }),
          'between 1 and 5');
    });
  });

  group('CallbackRule |', () {
    test('works with use()', () {
      AnySchema s = v.any().use(CallbackRule(
            name: 'even',
            defaultMessage: 'The {field} must be even',
            callback: (Object? value, RuleContext context) {
              return value is int && value.isEven;
            },
          ));
      expect(s.safeParse(2).success, true);
      expect(s.safeParse(3).issues.first.message, 'The value must be even');
    });
  });
}

class GermanResolver extends MessageResolver {
  @override
  String resolve(MessageRequest request) {
    if (request.code == IssueCodes.required) {
      return format('{field} ist erforderlich', request.params);
    }
    return super.resolve(request);
  }
}

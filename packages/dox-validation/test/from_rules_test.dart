import 'package:dox_validation/dox_validation.dart';
import 'package:test/test.dart';

class FakeFile implements FileInput {
  FakeFile(this.extension);

  @override
  final String extension;
}

/// Run old dox style rules and return the first error per field.
Map<String, String> check(
  Map<String, dynamic> data,
  Map<String, String> rules, {
  Map<String, String> messages = const <String, String>{},
}) {
  return v.fromRules(rules, messages: messages).safeParse(data).errors;
}

void main() {
  group('fromRules: old dox-core behavior |', () {
    test('required on null with dot', () {
      expect(
        check(
          <String, dynamic>{
            'user': <String, dynamic>{'name': null},
          },
          <String, String>{'user.name': 'required'},
        )['user.name'],
        'The name is required',
      );
    });

    test('required on null, empty text, empty list', () {
      expect(
        check(
          <String, dynamic>{'email': null},
          <String, String>{'email': 'required'},
        )['email'],
        'The email is required',
      );
      expect(
        check(
          <String, dynamic>{'email': ''},
          <String, String>{'email': 'required'},
        )['email'],
        'The email is required',
      );
      expect(
        check(
          <String, dynamic>{'items': <String>[]},
          <String, String>{'items': 'required'},
        )['items'],
        'The items is required',
      );
    });

    test('email', () {
      expect(
        check(
          <String, dynamic>{'email': 'invalid'},
          <String, String>{'email': 'required|email'},
        )['email'],
        'The email is not a valid email',
      );
      expect(
        check(
          <String, dynamic>{'email': 'support@dartondox.dev'},
          <String, String>{'email': 'required|email'},
        ),
        isEmpty,
      );
    });

    test('numeric, integer, double', () {
      expect(
        check(
          <String, dynamic>{'age': '1'},
          <String, String>{'age': 'numeric'},
        ),
        isEmpty,
      );
      expect(
        check(<String, dynamic>{'age': 1}, <String, String>{'age': 'numeric'}),
        isEmpty,
      );
      expect(
        check(
          <String, dynamic>{'age': 'abcd'},
          <String, String>{'age': 'numeric'},
        )['age'],
        'The age must be a number',
      );
      expect(
        check(
          <String, dynamic>{'age': '10'},
          <String, String>{'age': 'integer'},
        ),
        isEmpty,
      );
      expect(
        check(
          <String, dynamic>{'age': '10.2'},
          <String, String>{'age': 'integer'},
        )['age'],
        'The age must be an integer',
      );
      expect(
        check(
          <String, dynamic>{'amount': 'double'},
          <String, String>{'amount': 'double'},
        )['amount'],
        'The amount must be a double',
      );
      expect(
        check(
          <String, dynamic>{'amount': '10.2'},
          <String, String>{'amount': 'double'},
        ),
        isEmpty,
      );
    });

    test('alpha family', () {
      expect(
        check(
          <String, dynamic>{'name': 'dox1'},
          <String, String>{'name': 'alpha'},
        )['name'],
        'The name must be an alphabetic',
      );
      expect(
        check(
          <String, dynamic>{'name': '&@#'},
          <String, String>{'name': 'alpha_numeric'},
        )['name'],
        'The name must be only alphabetic and number',
      );
      expect(
        check(
          <String, dynamic>{'name': 'dox_web-framework'},
          <String, String>{'name': 'alpha_dash'},
        ),
        isEmpty,
      );
      expect(
        check(
          <String, dynamic>{'name': 1},
          <String, String>{'name': 'alpha_dash'},
        )['name'],
        'The name must be only alphabetic and dash',
      );
    });

    test('ip, boolean, array, json, date, url, uuid', () {
      expect(
        check(
          <String, dynamic>{'ip': 'abcd'},
          <String, String>{'ip': 'ip'},
        )['ip'],
        'The ip must be an ip address',
      );
      expect(
        check(
          <String, dynamic>{'active': true},
          <String, String>{'active': 'boolean'},
        ),
        isEmpty,
      );
      expect(
        check(
          <String, dynamic>{'active': 'true'},
          <String, String>{'active': 'boolean'},
        )['active'],
        'The active must be a boolean',
      );
      expect(
        check(
          <String, dynamic>{'list': 'text'},
          <String, String>{'list': 'array'},
        )['list'],
        'The list must be an array',
      );
      expect(
        check(
          <String, dynamic>{'info': 'user info'},
          <String, String>{'info': 'json'},
        )['info'],
        'The info is not a valid json',
      );
      expect(
        check(
          <String, dynamic>{'dob': '1994-11-22'},
          <String, String>{'dob': 'date'},
        ),
        isEmpty,
      );
      expect(
        check(
          <String, dynamic>{'dob': '1994/11/22'},
          <String, String>{'dob': 'date'},
        )['dob'],
        'The dob must be a date',
      );
      expect(
        check(
          <String, dynamic>{'url': 'just string'},
          <String, String>{'url': 'url'},
        )['url'],
        'The url must be a url',
      );
      expect(
        check(
          <String, dynamic>{'uuid': 'just string'},
          <String, String>{'uuid': 'uuid'},
        )['uuid'],
        'The uuid is invalid uuid',
      );
    });

    test('in and not_in', () {
      expect(
        check(
          <String, dynamic>{'status': 'active'},
          <String, String>{'status': 'in:active,pending'},
        ),
        isEmpty,
      );
      expect(
        check(
          <String, dynamic>{'status': 'failed'},
          <String, String>{'status': 'in:active,pending'},
        )['status'],
        'The selected status is invalid. Valid options are active, and pending',
      );
      expect(
        check(
          <String, dynamic>{'status': 'active'},
          <String, String>{'status': 'not_in:active,pending'},
        )['status'],
        'The status field cannot be active',
      );
    });

    test('lengths', () {
      String uuid = '3f1d2c8e-1b2a-4c3d-9e8f-0a1b2c3d4e5f';
      expect(
        check(
          <String, dynamic>{'uuid': uuid},
          <String, String>{'uuid': 'min_length:50'},
        )['uuid'],
        'The uuid must be at least 50 character',
      );
      expect(
        check(
          <String, dynamic>{'uuid': uuid},
          <String, String>{'uuid': 'max_length:10'},
        )['uuid'],
        'The uuid may not be greater than 10 character',
      );
      expect(
        check(
          <String, dynamic>{'uuid': uuid},
          <String, String>{'uuid': 'length_between:10,15'},
        )['uuid'],
        'The uuid must be between 10 and 15 character',
      );
      expect(
        check(
          <String, dynamic>{'uuid': uuid},
          <String, String>{'uuid': 'length_between:10,50'},
        ),
        isEmpty,
      );
    });

    test('min, max, greater_than, less_than, between', () {
      expect(
        check(
          <String, dynamic>{'age': '1'},
          <String, String>{'age': 'min:10'},
        )['age'],
        'The age must be greater than or equal 10',
      );
      expect(
        check(
          <String, dynamic>{'age': '10'},
          <String, String>{'age': 'min:10'},
        ),
        isEmpty,
      );
      expect(
        check(
          <String, dynamic>{'age': '11'},
          <String, String>{'age': 'max:10'},
        )['age'],
        'The age must be less than or equal 10',
      );
      expect(
        check(
          <String, dynamic>{'age': '6'},
          <String, String>{'age': 'greater_than:10'},
        )['age'],
        'The age must be greater than 10',
      );
      expect(
        check(
          <String, dynamic>{'age': '11'},
          <String, String>{'age': 'less_than:10'},
        )['age'],
        'The age must be less than 10',
      );
      expect(
        check(
          <String, dynamic>{'age': 20},
          <String, String>{'age': 'between:1,10'},
        )['age'],
        'The age must be between 1 and 10',
      );
    });

    test('min and max on text and lists (Laravel style)', () {
      expect(
        check(
          <String, dynamic>{'name': 'ab'},
          <String, String>{'name': 'string|min:3'},
        )['name'],
        'The name must be at least 3 character',
      );
      expect(
        check(
          <String, dynamic>{'name': '12'},
          <String, String>{'name': 'string|min:3'},
        )['name'],
        'The name must be at least 3 character',
      );
      expect(
        check(
          <String, dynamic>{
            'tags': <int>[1],
          },
          <String, String>{'tags': 'array|min:2'},
        )['tags'],
        'The tags must have at least 2 items',
      );
    });

    test('start_with and end_with', () {
      expect(
        check(
          <String, dynamic>{'name': 'dox'},
          <String, String>{'name': 'start_with:dart'},
        )['name'],
        'The name must start with dart',
      );
      expect(
        check(
          <String, dynamic>{'name': 'dox'},
          <String, String>{'name': 'end_with:dart'},
        )['name'],
        'The name must end with dart',
      );
      expect(
        check(
          <String, dynamic>{'name': 'dox'},
          <String, String>{'name': 'end_with:x'},
        ),
        isEmpty,
      );
    });

    test('confirmed', () {
      expect(
        check(
          <String, dynamic>{'password': '123', 'password_confirmation': '1234'},
          <String, String>{'password': 'confirmed'},
        )['password'],
        'The two password did not match',
      );
      expect(
        check(
          <String, dynamic>{'password': '123', 'password_confirmation': '123'},
          <String, String>{'password': 'confirmed'},
        ),
        isEmpty,
      );
      expect(
        check(
          <String, dynamic>{'password': '123', 'password_confirm': '123'},
          <String, String>{'password': 'confirmed:password_confirm'},
        ),
        isEmpty,
      );
    });

    test('confirmed uses the sibling in nested data', () {
      expect(
        check(
          <String, dynamic>{
            'user': <String, dynamic>{'pin': '1', 'pin_confirmation': '2'},
          },
          <String, String>{'user.pin': 'confirmed'},
        ).keys,
        <String>['user.pin'],
      );
    });

    test('required_if and required_if_not', () {
      expect(
        check(
          <String, dynamic>{'type': 'register'},
          <String, String>{'dob': 'required_if:type,register'},
        )['dob'],
        'The dob is required',
      );
      expect(
        check(
          <String, dynamic>{'type': 'login'},
          <String, String>{'dob': 'required_if:type,register'},
        ),
        isEmpty,
      );
      expect(
        check(
          <String, dynamic>{'type': 'register'},
          <String, String>{'dob': 'required_if_not:type,login'},
        )['dob'],
        'The dob is required',
      );
      expect(
        check(
          <String, dynamic>{'type': 'login'},
          <String, String>{'dob': 'required_if_not:type,login'},
        ),
        isEmpty,
      );
      expect(
        check(
          <String, dynamic>{'type': 'b'},
          <String, String>{'dob': 'required_if:type,a,b'},
        ).keys,
        <String>['dob'],
      );
    });

    test('map with dot', () {
      Map<String, String> errors = check(
        <String, dynamic>{
          'info': <String, String>{'name': 'dox', 'email': ''},
        },
        <String, String>{
          'info.name': 'required|string',
          'info.email': 'required|email',
        },
      );
      expect(errors, <String, String>{'info.email': 'The email is required'});
    });

    test('nested wildcards', () {
      Map<String, dynamic> data = <String, dynamic>{
        'products': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'iphone',
            'items': <Map<String, String>>[
              <String, String>{'title': ''},
              <String, String>{'title': 'case'},
            ],
          },
          <String, dynamic>{
            'name': '',
            'items': <Map<String, String>>[
              <String, String>{'title': 'cable'},
              <String, String>{'title': ''},
            ],
          },
        ],
      };
      Map<String, String> errors = check(data, <String, String>{
        'products.*.items.*.title': 'required',
        'products.*.name': 'required',
      });
      expect(errors, <String, String>{
        'products.0.items.0.title': 'The title is required',
        'products.1.name': 'The name is required',
        'products.1.items.1.title': 'The title is required',
      });
    });

    test('image and file', () {
      expect(
        check(
          <String, dynamic>{'photo': FakeFile('png')},
          <String, String>{'photo': 'image'},
        ),
        isEmpty,
      );
      expect(
        check(
          <String, dynamic>{'photo': FakeFile('pdf')},
          <String, String>{'photo': 'image'},
        )['photo'],
        'The photo is either invalid or unsupported extension',
      );
      expect(
        check(
          <String, dynamic>{'doc': FakeFile('pdf')},
          <String, String>{'doc': 'file:pdf,doc'},
        ),
        isEmpty,
      );
      expect(
        check(
          <String, dynamic>{'doc': 'x'},
          <String, String>{'doc': 'file'},
        ).keys,
        <String>['doc'],
      );
    });

    test('custom messages by rule and by field', () {
      Map<String, String> errors = check(
        <String, dynamic>{'age': '5'},
        <String, String>{'name': 'required', 'age': 'min:10'},
        messages: <String, String>{
          'name.required': 'Name please',
          'min': 'The {field} must be %s or more',
        },
      );
      expect(errors, <String, String>{
        'name': 'Name please',
        'age': 'The age must be 10 or more',
      });
    });

    test('stops at first failed rule per field', () {
      ParseResult<Map<String, dynamic>> result = v
          .fromRules(<String, String>{'email': 'required|email|min_length:20'})
          .safeParse(<String, dynamic>{'email': 'x'});
      expect(result.issues.length, 1);
      expect(result.issues.single.code, IssueCodes.email);
    });
  });

  group('fromRules: Laravel presence rules |', () {
    test('missing and not required skips all rules', () {
      expect(
        check(<String, dynamic>{}, <String, String>{
          'email': 'email|max_length:5',
        }),
        isEmpty,
      );
    });

    test('empty text and not required skips rules', () {
      expect(
        check(
          <String, dynamic>{'email': ''},
          <String, String>{'email': 'email'},
        ),
        isEmpty,
      );
    });

    test('null without nullable skips rules (old dox behavior)', () {
      expect(
        check(
          <String, dynamic>{'age': null},
          <String, String>{'age': 'integer'},
        ),
        isEmpty,
      );
    });

    test('nullable allows null', () {
      expect(
        check(
          <String, dynamic>{'age': null},
          <String, String>{'age': 'nullable|integer|min:18'},
        ),
        isEmpty,
      );
      expect(
        check(
          <String, dynamic>{'age': 10},
          <String, String>{'age': 'nullable|integer|min:18'},
        ).keys,
        <String>['age'],
      );
    });

    test('sometimes skips required when missing', () {
      Map<String, String> rules = <String, String>{
        'name': 'sometimes|required',
      };
      expect(check(<String, dynamic>{}, rules), isEmpty);
      expect(check(<String, dynamic>{'name': ''}, rules).keys, <String>[
        'name',
      ]);
    });

    test('output has only fields with rules, values unchanged', () {
      Map<String, dynamic> out = v
          .fromRules(<String, String>{
            'age': 'integer',
            'user.name': 'required',
            'missing': 'string',
          })
          .parse(<String, dynamic>{
            'age': '18',
            'extra': true,
            'user': <String, dynamic>{'name': 'dox', 'secret': 1},
          });
      expect(out, <String, dynamic>{
        'age': '18',
        'user': <String, dynamic>{'name': 'dox'},
      });
    });

    test('missing parent of dotted key still checks required', () {
      expect(
        check(<String, dynamic>{}, <String, String>{'info.email': 'required'}),
        <String, String>{'info.email': 'The email is required'},
      );
    });

    test('rules on parent and children', () {
      Map<String, String> rules = <String, String>{
        'items': 'required|array',
        'items.*.id': 'required|integer',
      };
      expect(check(<String, dynamic>{}, rules).keys, <String>['items']);
      expect(
        check(<String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'x'},
          ],
        }, rules),
        <String, String>{'items.0.id': 'The id must be an integer'},
      );
    });

    test('unknown rule throws when building', () {
      expect(() {
        v.fromRules(<String, String>{'a': 'required|nope'});
      }, throwsArgumentError);
    });

    test('rule needing a number throws when building', () {
      expect(() {
        v.fromRules(<String, String>{'a': 'min:abc'});
      }, throwsArgumentError);
    });
  });

  group('fromRules: custom rules |', () {
    test('registerRule on own validator (DI)', () {
      Validator validator = Validator();
      validator.registerRule('even', (RuleDefinition d) {
        return CallbackRule(
          name: 'even',
          defaultMessage: 'The {field} must be even',
          callback: (Object? value, RuleContext context) {
            return int.tryParse(value.toString())?.isEven ?? false;
          },
        );
      });
      ObjectSchema s = validator.fromRules(<String, String>{
        'n': 'required|even',
      });
      expect(s.safeParse(<String, dynamic>{'n': 3}).errors, <String, String>{
        'n': 'The n must be even',
      });
      expect(v.registry.has('even'), false);
    });

    test('async rule from registry, with args', () async {
      Validator validator = Validator();
      validator.registerRule('unique', (RuleDefinition d) {
        return FakeUniqueRule(d.arg(0));
      });
      ObjectSchema s = validator.fromRules(<String, String>{
        'email': 'required|unique:users',
      });
      ParseResult<Map<String, dynamic>> result = await s.safeParseAsync(
        <String, dynamic>{'email': 'taken@dox.dev'},
      );
      expect(result.errors, <String, String>{
        'email': 'The email already exists in users',
      });
    });

    test('fromRules result can be extended with fluent schemas', () {
      ObjectSchema s = v.fromRules(<String, String>{'name': 'required'}).extend(
        <String, Schema<Object?>>{'age': v.coerce.int().optional()},
      );
      expect(
        s.parse(<String, dynamic>{'name': 'x', 'age': '3'}),
        <String, dynamic>{'name': 'x', 'age': 3},
      );
    });
  });
}

class FakeUniqueRule extends AsyncRule<Object?> {
  FakeUniqueRule(this.table);

  final String table;

  @override
  String get name {
    return 'unique';
  }

  @override
  String get defaultMessage {
    return 'The {field} already exists in {table}';
  }

  @override
  Map<String, Object?> get params {
    return <String, Object?>{'table': table};
  }

  @override
  Future<bool> checkAsync(Object? value, RuleContext context) async {
    return value != 'taken@dox.dev';
  }
}

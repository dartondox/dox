import 'dart:typed_data';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../dtos/custom.dto.dart';
import '../dtos/files.dto.dart';
import '../dtos/nested.dto.dart';
import '../dtos/rules.dto.dart';

/// the errors of [schema] for [input] (JSON types)
Future<Map<String, String>> errorsOf(
  DtoSchema<Object> schema,
  Map<String, dynamic> input, {
  Source source = Source.body,
}) async {
  ParseResult<Object> result = await schema.safeValidateMap(
    input,
    source: source,
  );
  return result.errors;
}

/// one rule: a good value, a bad value and the message of the bad one
class RuleCase {
  const RuleCase(this.key, this.good, this.bad, this.message);

  final String key;
  final Object good;
  final Object bad;
  final String message;
}

void checkCases(DtoSchema<Object> schema, List<RuleCase> cases) {
  for (RuleCase item in cases) {
    test('${item.key}: pass and fail', () async {
      expect(
        await errorsOf(schema, <String, dynamic>{item.key: item.good}),
        isEmpty,
      );
      expect(
        await errorsOf(schema, <String, dynamic>{item.key: item.bad}),
        <String, String>{item.key: item.message},
      );
    });
  }
}

const List<int> png = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0];
const List<int> pdf = <int>[0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x37];
const List<int> zip = <int>[0x50, 0x4B, 0x03, 0x04, 0x14, 0x00];
const List<int> svg = <int>[0x3C, 0x73, 0x76, 0x67, 0x3E];

RequestFile fileOf(String name, List<int> bytes, {int? size}) {
  return RequestFile(
    filename: name,
    filetype: 'application/octet-stream',
    length: size ?? bytes.length,
    bytes: Uint8List.fromList(bytes),
  );
}

void main() {
  group('text rules |', () {
    checkCases($TextRulesDto, const <RuleCase>[
      RuleCase('len', 'abc', 'a', 'The len must be between 2 and 4 characters'),
      RuleCase('exact', 'abc', 'ab', 'The exact must be exactly 3 characters'),
      RuleCase(
        'len_min',
        'ab',
        'a',
        'The len_min must be at least 2 characters',
      ),
      RuleCase(
        'min_len',
        'ab',
        'a',
        'The min_len must be at least 2 characters',
      ),
      RuleCase(
        'max_len',
        'abc',
        'abcd',
        'The max_len may not be greater than 3 characters',
      ),
      RuleCase('email', 'a@dox.dev', 'nope', 'The email is not a valid email'),
      RuleCase('url', 'https://dox.dev', 'ftp://x', 'The url must be a url'),
      RuleCase(
        'uuid',
        '0F8FAD5B-D9CB-469F-A165-70867728950E',
        'abc',
        'The uuid is invalid uuid',
      ),
      RuleCase('ip', '::1', '300.1.1.1', 'The ip must be an ip address'),
      RuleCase('regex', 'abc', 'abc1', 'The regex format is invalid'),
      RuleCase(
        'in_list',
        'a',
        'c',
        'The selected in_list is invalid. Valid options are a, and b',
      ),
      RuleCase('not_in', 'user', 'root', 'The not_in field cannot be root'),
      RuleCase('starts', 'doxy', 'xdox', 'The starts must start with dox'),
      RuleCase('ends', 'a.dev', 'a.com', 'The ends must end with .dev'),
      RuleCase('alpha', 'abc', 'ab1', 'The alpha must be an alphabetic'),
      RuleCase(
        'alnum',
        'ab1',
        'ab-',
        'The alnum must be only alphabetic and number',
      ),
      RuleCase(
        'dash',
        'a-b_c',
        'a b',
        'The dash must be only alphabetic and dash',
      ),
    ]);

    test('length counts characters, not bytes', () async {
      expect(
        await errorsOf($TextRulesDto, <String, dynamic>{'exact': 'éé€'}),
        isEmpty,
      );
    });

    test('ipv4 works', () async {
      expect(
        await errorsOf($TextRulesDto, <String, dynamic>{'ip': '10.0.0.1'}),
        isEmpty,
      );
    });
  });

  group('change text |', () {
    test('trim, lower and upper case', () async {
      ChangeText value = await $ChangeTextDto.validateMap(<String, dynamic>{
        'trimmed': '  a  ',
        'lower': ' ABC ',
        'upper': 'abc',
      });
      expect(value.trimmed, 'a');
      expect(value.lower, 'abc');
      expect(value.upper, 'ABC');
    });

    test('empty text is missing, unless @AllowEmpty', () async {
      ChangeText value = await $ChangeTextDto.validateMap(<String, dynamic>{
        'keep': '',
        'blank': '   ',
      });
      expect(value.keep, '');
      expect(value.blank, isNull);
    });

    test('a required text rejects empty text', () async {
      expect(
        await errorsOf($CreateUserDto, <String, dynamic>{
          'name': '   ',
          'email': '',
        }),
        <String, String>{
          'name': 'The name is required',
          'email': 'The email is required',
        },
      );
    });
  });

  group('number rules |', () {
    checkCases($NumberRulesDto, const <RuleCase>[
      RuleCase('min', 18, 17, 'The min must be greater than or equal 18'),
      RuleCase('max', 100, 101, 'The max must be less than or equal 100'),
      RuleCase('range', 5.5, 11, 'The range must be between 1 and 10'),
      RuleCase('positive', 1, 0, 'The positive must be greater than 0'),
      RuleCase('gt', 0.6, 0.5, 'The gt must be greater than 0.5'),
      RuleCase('lt', 99.9, 100, 'The lt must be less than 100'),
      RuleCase(
        'in_num',
        2,
        4,
        'The selected in_num is invalid. Valid options are 1, 2, and 3',
      ),
      RuleCase('not_in_num', 1, 0, 'The not_in_num field cannot be 0'),
    ]);
  });

  group('list rules |', () {
    checkCases($ListRulesDto, const <RuleCase>[
      RuleCase(
        'min_items',
        <int>[1],
        <int>[],
        'The min_items must have at least 1 items',
      ),
      RuleCase(
        'max_items',
        <String>['a', 'b'],
        <String>['a', 'b', 'c'],
        'The max_items may not have more than 2 items',
      ),
      RuleCase(
        'unique',
        <String>['a', 'b'],
        <String>['a', 'a'],
        'The unique must not have duplicate items',
      ),
    ]);

    test('a value rule checks each item, with the index in the key', () async {
      expect(
        await errorsOf($ListRulesDto, <String, dynamic>{
          'emails': <String>['a@dox.dev', 'b@dox.dev', 'nope'],
        }),
        <String, String>{'emails.2': 'The emails is not a valid email'},
      );
    });
  });

  group('date rules |', () {
    checkCases($DateRulesDto, const <RuleCase>[
      RuleCase(
        'after',
        '2000-01-02',
        '2000-01-01T00:00:00Z',
        'The after must be a date after 2000-01-01',
      ),
      RuleCase(
        'before',
        '2020-01-01',
        '2999-01-01',
        'The before must be a date before now',
      ),
    ]);

    test('a date without a time zone is UTC', () async {
      AllTypes value = await $AllTypesDto.validateMap(<String, dynamic>{
        'dt': '2024-01-31T10:00:00',
      });
      expect(value.dt, DateTime.utc(2024, 1, 31, 10));
      expect(value.dt!.isUtc, isTrue);
    });

    test('a bad date is a date error', () async {
      expect(
        await errorsOf($AllTypesDto, <String, dynamic>{'dt': '2024-02-30'}),
        <String, String>{'dt': 'The dt must be a date'},
      );
    });
  });

  group('types |', () {
    test('JSON is strict', () async {
      expect(
        await errorsOf($AllTypesDto, <String, dynamic>{
          's': 1,
          'i': '18',
          'd': 'x',
          'n': '1',
          'b': 'true',
          'role': 'Admin',
          'list': 'a',
          'map': <String, dynamic>{'a': 'x'},
          'raw': 5,
        }),
        <String, String>{
          's': 'The s must be a string',
          'i': 'The i must be an integer',
          'd': 'The d must be a number',
          'n': 'The n must be a number',
          'b': 'The b must be a boolean',
          'role':
              'The selected role is invalid. Valid options are admin, and user',
          'list': 'The list must be an array',
          'map.a': 'The a must be an integer',
          'raw': 'The raw must be an object',
        },
      );
    });

    test('int takes 18.0, not 4.5', () async {
      AllTypes value = await $AllTypesDto.validateMap(<String, dynamic>{
        'i': 18.0,
        'd': 18,
      });
      expect(value.i, 18);
      expect(value.d, 18.0);
      expect(
        await errorsOf($AllTypesDto, <String, dynamic>{'i': 4.5}),
        <String, String>{'i': 'The i must be an integer'},
      );
    });

    test('query text is converted', () async {
      AllTypes value = await $AllTypesDto.validateMap(<String, dynamic>{
        'i': '18',
        'd': '4.5',
        'n': '7',
        'b': 'on',
        'role': 'admin',
        'list': '3',
        'map': <String, dynamic>{'a': '1'},
      }, source: Source.query);
      expect(value.i, 18);
      expect(value.d, 4.5);
      expect(value.n, 7);
      expect(value.b, isTrue);
      expect(value.role, Role.admin);
      expect(value.list, <int>[3]);
      expect(value.map, <String, int>{'a': 1});
    });

    test('query text that does not fit gives the type error', () async {
      expect(
        await errorsOf($AllTypesDto, <String, dynamic>{
          'i': '4.5',
          'b': 'maybe',
        }, source: Source.query),
        <String, String>{
          'i': 'The i must be an integer',
          'b': 'The b must be a boolean',
        },
      );
    });

    test('any and raw maps are not checked', () async {
      AllTypes value = await $AllTypesDto.validateMap(<String, dynamic>{
        'any': <int>[1],
        'raw': <String, dynamic>{'x': 1},
      });
      expect(value.any, <int>[1]);
      expect(value.raw, <String, dynamic>{'x': 1});
    });
  });

  group('required, defaults and Maybe |', () {
    test('defaults and optional fields', () async {
      CreateUser user = await $CreateUserDto.validateMap(<String, dynamic>{
        'name': ' Ann ',
        'email': 'ann@dox.dev',
      });
      expect(user.name, 'Ann');
      expect(user.age, isNull);
      expect(user.role, Role.user);
      expect(user.tags, isEmpty);
    });

    test('null is not allowed for a field with a default', () async {
      expect(
        await errorsOf($CreateUserDto, <String, dynamic>{
          'name': 'Ann',
          'email': 'ann@dox.dev',
          'role': null,
        }),
        <String, String>{'role': 'The role is required'},
      );
    });

    test('Maybe knows missing from null', () async {
      UpdateUser missing = await $UpdateUserDto.validateMap(
        <String, dynamic>{},
      );
      expect(missing.bio.isPresent, isFalse);
      UpdateUser cleared = await $UpdateUserDto.validateMap(<String, dynamic>{
        'bio': null,
      });
      expect(cleared.bio.isPresent, isTrue);
      expect(cleared.bio.value, isNull);
      UpdateUser set = await $UpdateUserDto.validateMap(<String, dynamic>{
        'bio': 'hi',
        'age': 3,
      });
      expect(set.bio.value, 'hi');
      expect(set.age.value, 3);
    });

    test(
      'rules check a present Maybe value; a Maybe<int> rejects null',
      () async {
        expect(
          await errorsOf($UpdateUserDto, <String, dynamic>{
            'bio': 'too long',
            'age': null,
          }),
          <String, String>{'age': 'The age is required'},
        );
        expect(
          await errorsOf($UpdateUserDto, <String, dynamic>{'bio': 'too long'}),
          <String, String>{
            'bio': 'The bio may not be greater than 5 characters',
          },
        );
      },
    );

    test('type errors come before rules', () async {
      expect(
        await errorsOf($CreateUserDto, <String, dynamic>{
          'name': 'A',
          'email': 5,
        }),
        <String, String>{'email': 'The email must be a string'},
      );
    });
  });

  group('keys and options |', () {
    test('snake_case keys and @Name', () async {
      SignUpKeys value = await $SignUpKeysDto.validateMap(<String, dynamic>{
        'first_name': 'Ann',
        'emailAddress': 'a@dox.dev',
      });
      expect(value.firstName, 'Ann');
      expect(
        await errorsOf($SignUpKeysDto, <String, dynamic>{'firstName': 'Ann'}),
        <String, String>{
          'first_name': 'The first_name is required',
          'emailAddress': 'The emailAddress is required',
        },
      );
    });

    test('KeyCase.field keeps the Dart name', () async {
      CamelKeys value = await $CamelKeysDto.validateMap(<String, dynamic>{
        'firstName': 'Ann',
      });
      expect(value.firstName, 'Ann');
    });

    test('unknown keys are dropped, or an error with strict', () async {
      expect(
        await errorsOf($CreateUserDto, <String, dynamic>{
          'name': 'Ann',
          'email': 'a@dox.dev',
          'is_admin': true,
        }),
        isEmpty,
      );
      expect(
        await errorsOf($StrictInputDto, <String, dynamic>{
          'name': 'x',
          'is_admin': true,
        }),
        <String, String>{'is_admin': 'The is_admin field is not allowed'},
      );
    });

    test('a body that is not an object is a _root error', () async {
      ParseResult<Object> result = await $CreateUserDto.run(<int>[
        1,
        2,
      ], DtoState(root: <int>[1, 2]));
      expect(result.errors, <String, String>{
        '_root': 'The request body must be a JSON object.',
      });
    });

    test('the _root message can be changed by the resolver', () async {
      ParseResult<Object> result = await $CreateUserDto.run(
        <int>[1],
        DtoState(
          root: <int>[1],
          resolver: MessageResolver(
            messages: <String, String>{'_root.object': 'Send an object'},
          ),
        ),
      );
      expect(result.errors, <String, String>{'_root': 'Send an object'});
    });
  });

  group('messages |', () {
    test('annotation message, then key.code, then code', () async {
      expect(
        await errorsOf($WithMessagesDto, <String, dynamic>{
          'age': 'x',
          'nick': 'ab',
        }),
        <String, String>{
          'email': 'We need your email',
          'name': 'Please fill in name',
          'age': 'The age must be a number',
        },
      );
      expect(
        await errorsOf($WithMessagesDto, <String, dynamic>{
          'email': 'a',
          'name': 'b',
          'nick': 'ab',
        }),
        <String, String>{'nick': 'At least 3 letters, please'},
      );
    });

    test('a message resolver with a locale', () async {
      ParseResult<CreateUser> result = await $CreateUserDto.safeValidateMap(
        <String, dynamic>{},
        messages: ThaiMessages(),
        locale: 'th',
      );
      expect(result.errors['name'], 'กรุณากรอก name');
    });
  });

  group('nested |', () {
    test('errors use dotted paths with list indexes', () async {
      expect(
        await errorsOf($CreateOrderDto, <String, dynamic>{
          'address': <String, dynamic>{'city': 'Bangkok', 'post_code': '101'},
          'items': <Map<String, dynamic>>[
            <String, dynamic>{'name': 'Shoes', 'quantity': 2},
            <String, dynamic>{'name': 'Socks', 'quantity': 0},
          ],
        }),
        <String, String>{
          'address.post_code': 'The post_code must be exactly 5 characters',
          'items.1.quantity': 'The quantity must be greater than 0',
        },
      );
    });

    test('a missing nested object is required', () async {
      expect(
        await errorsOf($CreateOrderDto, <String, dynamic>{
          'items': <Map<String, dynamic>>[],
          'billing': 'x',
        }),
        <String, String>{
          'address': 'The address is required',
          'billing': 'The billing must be an object',
        },
      );
    });

    test('nested validate() runs with the parent path', () async {
      expect(
        await errorsOf($CreateOrderDto, <String, dynamic>{
          'address': <String, dynamic>{'city': 'Nowhere', 'post_code': '10110'},
          'items': <Map<String, dynamic>>[
            <String, dynamic>{'name': 'a', 'quantity': 1},
          ],
        }),
        <String, String>{'address.city': 'No such city'},
      );
    });

    test('toMap and fromMap', () async {
      CreateOrder order = $CreateOrderDto.fromMap(<String, dynamic>{
        'address': <String, dynamic>{'city': 'Bangkok', 'post_code': '10110'},
        'items': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'a', 'quantity': 1},
        ],
      });
      expect(order.items.first.quantity, 1);
      expect($CreateOrderDto.toMap(order), <String, dynamic>{
        'address': <String, dynamic>{'city': 'Bangkok', 'post_code': '10110'},
        'items': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'a', 'quantity': 1},
        ],
        'billing': null,
      });
    });

    test('a DTO works inside a fluent schema', () {
      ObjectSchema schema = v.object(<String, Schema<Object?>>{
        'address': $AddressDto,
      });
      expect(
        schema.safeParse(<String, dynamic>{
          'address': <String, dynamic>{'city': 'x', 'post_code': '1'},
        }).errors,
        <String, String>{
          'address.post_code': 'The post_code must be exactly 5 characters',
        },
      );
    });
  });

  group('validate() |', () {
    test('runs after the field rules', () async {
      expect(
        await errorsOf($SignUpDto, <String, dynamic>{
          'password': 'short',
          'password_confirmation': 'other',
        }),
        <String, String>{
          'password': 'The password must be at least 8 characters',
        },
      );
      expect(
        await errorsOf($SignUpDto, <String, dynamic>{
          'password': 'long enough',
          'password_confirmation': 'other',
          'starts_at': '2024-02-01',
          'ends_at': '2024-01-01',
        }),
        <String, String>{
          'password_confirmation': 'The passwords do not match',
          'ends_at': 'The end must be after the start',
        },
      );
    });

    test('an async validate() works', () async {
      expect($AsyncCheckDto.isAsync, isTrue);
      expect(
        await errorsOf($AsyncCheckDto, <String, dynamic>{'code': 'bad'}),
        <String, String>{'code': 'The code is bad'},
      );
      expect(
        () => $AsyncCheckDto.parse(<String, dynamic>{'code': 'x'}),
        throwsStateError,
      );
    });
  });

  group('custom rules |', () {
    test('a Rule<T> annotation, on a value and on list items', () async {
      expect(
        await errorsOf($CreatePostDto, <String, dynamic>{
          'slug': 'Not A Slug',
          'scores': <int>[5, 2],
        }),
        <String, String>{
          'slug': 'The slug must be a slug',
          'scores.1': 'The scores must be at least 5',
        },
      );
    });

    test('an AsyncRule runs last, on a value and on list items', () async {
      expect(
        await errorsOf($CreatePostDto, <String, dynamic>{
          'slug': 'ok',
          'handle': 'taken',
          'handles': <String>['a', 'taken'],
        }),
        <String, String>{
          'handle': 'The handle is taken',
          'handles.1': 'The handles is taken',
        },
      );
    });

    test('async rules do not run when a field rule failed', () async {
      expect(
        await errorsOf($CreatePostDto, <String, dynamic>{
          'slug': 'BAD',
          'handle': 'taken',
        }),
        <String, String>{'slug': 'The slug must be a slug'},
      );
    });

    test('a custom rule adds its JSON Schema keys', () {
      Map<String, dynamic> json = $CreatePostDto.toJsonSchema();
      expect(
        json['properties']['slug']['pattern'],
        r'^[a-z0-9]+(-[a-z0-9]+)*$',
      );
    });
  });

  group('files |', () {
    test('a good image and pdf', () async {
      UploadAvatar value = await $UploadAvatarDto.validateMap(<String, dynamic>{
        'avatar': fileOf('me.png', png),
        'documents': <Object>[fileOf('a.pdf', pdf), fileOf('b.docx', zip)],
      }, source: Source.query);
      expect(value.avatar.filename, 'me.png');
      expect(value.documents, hasLength(2));
    });

    test('the real type wins over the name, svg is not an image', () async {
      expect(
        await errorsOf($UploadAvatarDto, <String, dynamic>{
          'avatar': fileOf('me.svg', svg),
          'documents': <Object>[fileOf('a.pdf', png), fileOf('b.zip', zip)],
        }, source: Source.query),
        <String, String>{
          'avatar': 'The avatar must be an image',
          'documents.0': 'The documents must be a file of type: pdf, docx',
          'documents.1': 'The documents must be a file of type: pdf, docx',
        },
      );
    });

    test('max size', () async {
      expect(
        await errorsOf($UploadAvatarDto, <String, dynamic>{
          'avatar': fileOf('me.png', png, size: 2048),
        }, source: Source.query),
        <String, String>{'avatar': 'The avatar may not be larger than 1KB'},
      );
    });

    test('text where a file is expected, and files in JSON', () async {
      expect(
        await errorsOf($UploadAvatarDto, <String, dynamic>{
          'avatar': 'x',
        }, source: Source.query),
        <String, String>{'avatar': 'The avatar must be a file'},
      );
      expect(
        await errorsOf($UploadAvatarDto, <String, dynamic>{'avatar': 'x'}),
        <String, String>{'avatar': 'The avatar must be a file'},
      );
    });

    test('JSON Schema of a file', () {
      Map<String, dynamic> avatar = $UploadAvatarDto
          .toJsonSchema()['properties']['avatar'];
      expect(avatar['type'], 'string');
      expect(avatar['format'], 'binary');
      expect(avatar['contentMediaType'], 'image/*');
      expect(avatar['maxLength'], 1024);
    });
  });

  group('JSON Schema |', () {
    test('of CreateUser, with snake_case keys', () {
      expect($CreateUserDto.toJsonSchema(), <String, dynamic>{
        'type': 'object',
        'title': 'CreateUser',
        'properties': <String, dynamic>{
          'name': <String, dynamic>{
            'type': 'string',
            'minLength': 3,
            'maxLength': 50,
          },
          'email': <String, dynamic>{'type': 'string', 'format': 'email'},
          'age': <String, dynamic>{
            'type': <String>['integer', 'null'],
            'minimum': 18,
          },
          'role': <String, dynamic>{
            'type': 'string',
            'enum': <String>['admin', 'user'],
            'default': 'user',
          },
          'tags': <String, dynamic>{
            'type': 'array',
            'items': <String, dynamic>{'type': 'string'},
            'maxItems': 5,
            'default': <dynamic>[],
          },
        },
        'required': <String>['name', 'email'],
      });
    });

    test('nested DTOs go to \$defs', () {
      Map<String, dynamic> json = $CreateOrderDto.toJsonSchema();
      expect(json['properties']['address'], <String, dynamic>{
        r'$ref': r'#/$defs/Address',
      });
      expect(json[r'$defs']['Address']['properties'].keys, <String>[
        'city',
        'post_code',
      ]);
      expect($StrictInputDto.toJsonSchema()['additionalProperties'], isFalse);
    });
  });
}

class ThaiMessages extends MessageResolver {
  static const Map<String, Map<String, String>> _texts =
      <String, Map<String, String>>{
        'th': <String, String>{'required': 'กรุณากรอก {field}'},
      };

  @override
  String resolve(MessageRequest request) {
    String? template = _texts[request.locale]?[request.code];
    if (template == null) {
      return super.resolve(request);
    }
    return format(template, request.params);
  }
}

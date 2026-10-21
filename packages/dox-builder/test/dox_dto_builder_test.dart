import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dox_builder/dox_builder.dart';
import 'package:test/test.dart';

/// a small copy of dox_validation: the real annotations, and stubs of
/// the classes the generator finds by name.
final Map<String, String> _validation = <String, String>{
  'dox_validation|lib/dox_validation.dart': '''
export 'src/dto/dto_annotations.dart';

abstract class Rule<T> {
  const Rule({this.message});
  final String? message;
}
abstract class AsyncRule<T> extends Rule<T> {
  const AsyncRule({super.message});
}
abstract class FileInput {}
class RequestFile implements FileInput {}
class Maybe<T> {
  const Maybe.missing();
}
class DtoErrors {}
abstract class DtoSchema<T> {}
''',
  'dox_validation|lib/src/dto/dto_annotations.dart': File(
    '../dox-validation/lib/src/dto/dto_annotations.dart',
  ).readAsStringSync(),
};

const String _header = '''
import 'package:dox_validation/dox_validation.dart';

part 'a.g.dart';
''';

/// The generated part of [source], or the build errors.
Future<String> _generate(String source) async {
  Map<String, String> sources = <String, String>{
    ..._validation,
    'a|lib/a.dart': '$_header$source',
  };
  TestBuilderResult result = await testBuilder(
    buildDoxModel(BuilderOptions.empty),
    sources,
    rootPackage: 'a',
  );
  if (!result.succeeded) return 'ERROR: ${result.errors.join('\n')}';
  String output = '';
  await testBuilder(
    buildDoxModel(BuilderOptions.empty),
    sources,
    rootPackage: 'a',
    outputs: <String, Object>{
      'a|lib/a.dox_model_generator.g.part': decodedMatches(
        predicate<String>((String text) {
          output = text;
          return true;
        }),
      ),
    },
  );
  return output;
}

const String _createUser = '''
enum Role { admin, user }

class Slug extends Rule<String> {
  const Slug();
}

class Unique extends AsyncRule<Object?> {
  const Unique(this.table);
  final String table;
}

@Dto(messages: <String, String>{'required': 'Fill in {field}'})
class CreateUser {
  /// The name.
  @Length(min: 3, max: 50)
  @Trim()
  final String firstName;

  @Email()
  @Unique('users')
  final String email;

  @Min(18)
  final int? age;

  final Role role;

  @Regex('[a-z]+')
  @Slug()
  final String slug;

  @MaxItems(5)
  @Email()
  final List<String> emails;

  final Maybe<String?> bio;

  const CreateUser({
    required this.firstName,
    required this.email,
    this.age,
    this.role = Role.user,
    required this.slug,
    this.emails = const <String>[],
    this.bio = const Maybe.missing(),
  });

  void validate(DtoErrors errors) {}
}
''';

void main() {
  group('DTO generator |', () {
    late String out;

    setUpAll(() async {
      out = await _generate(_createUser);
    });

    test('a const schema with the name and type', () {
      expect(out, isNot(startsWith('ERROR')), reason: out);
      expect(out, contains(r'const DtoSchema<CreateUser> $CreateUserDto'));
      expect(
        out,
        contains(r'class _$CreateUserDto extends DtoSchema<CreateUser>'),
      );
      expect(out, contains("String get name => 'CreateUser';"));
      expect(out, contains('bool get hasChecks => true;'));
      expect(out, contains('bool get isAsync => true;'));
    });

    test('snake_case keys and text changes', () {
      expect(
        out,
        contains(
          "s.string(s.read(input, 'first_name'), p, 'first_name', _m, trim: true)",
        ),
      );
    });

    test('straight-line rules', () {
      expect(out, contains('c0.runes.length >= 3 && c0.runes.length <= 50'));
      expect(out, contains('IssueCodes.lengthBetween'));
      expect(out, contains('Patterns.email.hasMatch(c1)'));
      expect(
        out,
        contains("static final RegExp _r0 = RegExp('^(?:[a-z]+)\\\$');"),
      );
      expect(
        out,
        contains('const Slug().check(c4, s.context(p, \'slug\', c4))'),
      );
      expect(out, contains("'admin' => Role.admin,"));
    });

    test('list rules check the list, value rules each item', () {
      expect(out, contains('if (!(c5.length <= 5))'));
      expect(out, contains('Patterns.email.hasMatch(v)'));
    });

    test('messages, async rules, validate() and Maybe', () {
      expect(out, contains("'required': 'Fill in {field}'"));
      expect(
        out,
        contains(
          "await s.asyncRule(const Unique('users'), f, p, 'email', _m);",
        ),
      );
      expect(out, contains('o.validate(DtoErrors(s, p));'));
      expect(out, contains('Maybe<String?>(c6 as String?)'));
    });

    test('defaults and the JSON Schema', () {
      expect(out, contains('role: c3 is Undefined ? Role.user : c3 as Role'));
      expect(out, contains("'title': 'CreateUser'"));
      expect(out, contains("'description': 'The name.'"));
      expect(out, contains('JsonSchemaTools.merge('));
      expect(out, contains('const Slug().toJsonSchema()'));
    });
  });

  group('DTO generator stops the build |', () {
    Future<void> expectError(String source, String message) async {
      String out = await _generate(source);
      expect(out, startsWith('ERROR'), reason: out);
      expect(out, contains(message));
    }

    test('a field that is not final', () {
      return expectError('''
@Dto()
class A {
  String name;
  A({required this.name});
}''', 'must be final');
    });

    test('a field that is not a constructor parameter', () {
      return expectError('''
@Dto()
class A {
  final String name = 'x';
  const A();
}''', 'parameter of the unnamed constructor');
    });

    test('a type that is not supported', () {
      return expectError('''
@Dto()
class A {
  final Uri link;
  const A({required this.link});
}''', 'is not supported');
    });

    test('a rule that does not fit the type', () {
      return expectError('''
@Dto()
class A {
  @Email()
  final int age;
  const A({required this.age});
}''', '@Email does not fit the type int');
    });

    test('a Maybe without const Maybe.missing()', () {
      return expectError('''
@Dto()
class A {
  final Maybe<String> bio;
  const A({required this.bio});
}''', 'const Maybe.missing()');
    });

    test('a generic class, or one that extends another', () async {
      await expectError('''
@Dto()
class A<T> {
  const A();
}''', 'can not be generic');
      await expectError('''
class B {
  const B();
}
@Dto()
class A extends B {
  const A();
}''', 'can not extend another class');
    });

    test('bad annotation values', () async {
      await expectError('''
@Dto()
class A {
  @Lowercase()
  @Uppercase()
  final String a;
  @Regex('[a-')
  final String b;
  @Min(1.5)
  final int c;
  @Length()
  final String d;
  const A({required this.a, required this.b, required this.c, required this.d});
}''', 'both @Lowercase and @Uppercase');
      String out = await _generate('''
@Dto()
class A {
  @Regex('[a-')
  final String b;
  @Min(1.5)
  final int c;
  @Length()
  final String d;
  @MaxSize('2 apples')
  final RequestFile e;
  @After('soon')
  final DateTime f;
  const A({required this.b, required this.c, required this.d, required this.e, required this.f});
}''');
      expect(out, contains('not a valid regex'));
      expect(out, contains('uses a fraction'));
      expect(out, contains('needs min:, max: or both'));
      expect(out, contains('needs a size like'));
      expect(out, contains('ISO 8601 date'));
    });

    test('@UniqueItems on a list of DTOs', () {
      return expectError('''
@Dto()
class B {
  const B();
}
@Dto()
class A {
  @UniqueItems()
  final List<B> items;
  const A({required this.items});
}''', '@UniqueItems does not work');
    });
  });

  group('DTO registry |', () {
    test('lib/dtos.g.dart lists every DTO', () async {
      String output = '';
      await testBuilder(
        buildDoxDtos(BuilderOptions.empty),
        <String, String>{
          ..._validation,
          'a|lib/users.dart': '''
import 'package:dox_validation/dox_validation.dart';
@Dto()
class CreateUser {}
''',
          'a|lib/posts/posts.dart': '''
import 'package:dox_validation/dox_validation.dart';
@Dto()
class CreatePost {}
class NotADto {}
''',
        },
        rootPackage: 'a',
        outputs: <String, Object>{
          'a|lib/dtos.g.dart': decodedMatches(
            predicate<String>((String s) {
              output = s;
              return true;
            }),
          ),
        },
      );
      expect(
        output,
        contains("import 'package:dox_validation/dox_validation.dart';"),
      );
      expect(output, contains("import 'package:a/posts/posts.dart';"));
      expect(output, contains(r'$CreatePostDto,'));
      expect(output, contains(r'$CreateUserDto,'));
      expect(output, isNot(contains('NotADto')));
    });

    test('two DTOs with the same name stop the build', () async {
      TestBuilderResult result = await testBuilder(
        buildDoxDtos(BuilderOptions.empty),
        <String, String>{
          ..._validation,
          'a|lib/a.dart': '''
import 'package:dox_validation/dox_validation.dart';
@Dto()
class Same {}
''',
          'a|lib/b.dart': '''
import 'package:dox_validation/dox_validation.dart';
@Dto()
class Same {}
''',
        },
        rootPackage: 'a',
      );
      expect(result.succeeded, isFalse);
      expect(result.errors.join(), contains('Two @Dto classes are named Same'));
    });

    test('no DTOs, no file', () async {
      await testBuilder(
        buildDoxDtos(BuilderOptions.empty),
        <String, String>{'a|lib/a.dart': 'class A {}'},
        rootPackage: 'a',
        outputs: <String, Object>{},
      );
    });
  });
}

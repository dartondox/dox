import 'dart:io';
import 'dart:isolate';

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
  'dox_validation|lib/src/dto/dto_annotations.dart': File.fromUri(
    // dox_validation lives in its own repo: find it through the package config
    Isolate.resolvePackageUriSync(
      Uri.parse('package:dox_validation/src/dto/dto_annotations.dart'),
    )!,
  ).readAsStringSync(),
};

const String _header = '''
import 'package:dox_validation/dox_validation.dart';

part 'a.g.dart';
''';

/// The generated part of [source], or the build errors.
Future<String> _generate(
  String source, {
  String imports = '',
  Map<String, String> files = const <String, String>{},
}) async {
  Map<String, String> sources = <String, String>{
    ..._validation,
    ...files,
    'a|lib/a.dart': '$imports\n$_header$source',
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
      // a file with its own @Dto gets its own part
      for (String file in files.keys)
        file.replaceFirst('.dart', '.dox_model_generator.g.part'): anything,
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

    test(
      '@RequiredIf and @RequiredWith run when the value is missing',
      () async {
        String output = await _generate('''
@Dto()
class A {
  final String? type;

  @RequiredIf('type', 'company')
  final String? company;

  @RequiredWith(<String>['type'])
  final Maybe<int> size;

  const A({this.type, this.company, this.size = const Maybe.missing()});
}''');
        // the generated code is formatted, so compare without spaces
        String code = output.replaceAll(RegExp(r'\s+'), '');
        expect(
          code,
          contains(
            "s.requiredWhen(constRequiredIf('type','company'),c1,input,p,'company',_m,);",
          ),
        );
        expect(
          code,
          contains(
            "s.requiredWhen(constRequiredWith(<String>['type']),c2,input,p,'size',_m,);",
          ),
        );
      },
    );

    test('a Dart field name where the input key is needed', () async {
      String rules = '''
class Same extends Rule<Object?> {
  const Same(this.other);
  final String other;
}
class Confirmed extends Rule<Object?> {
  const Confirmed({this.other});
  final String? other;
}
''';
      await expectError(
        '''
$rules
@Dto()
class A {
  final String? accountType;

  @RequiredIf('accountType', 'company')
  final String? company;

  const A({this.accountType, this.company});
}''',
        "@RequiredIf on A.company: 'accountType' is a Dart field name. Use the input key 'account_type'.",
      );
      await expectError('''
$rules
@Dto()
class A {
  final String? emailAddress;

  @Same('emailAddress')
  final String? again;

  @RequiredWith(<String>['emailAddress'])
  final String? name;

  @Confirmed(other: 'emailAddress')
  final String? pin;

  const A({this.emailAddress, this.again, this.name, this.pin});
}''', "@Same on A.again: 'emailAddress' is a Dart field name");
      // input keys, keys that are no field, and same-name fields are fine
      String output = await _generate('''
$rules
@Dto()
class A {
  final String? accountType;
  final String? type;

  @RequiredIf('account_type', 'company')
  @Same('password_confirmation')
  final String? company;

  @RequiredWith(<String>['type', 'tag_source'])
  @Confirmed()
  final String? name;

  const A({this.accountType, this.type, this.company, this.name});
}''');
      expect(output, isNot(startsWith('ERROR')));
    });

    test('a strict DTO knows the key @Confirmed reads', () async {
      String output = await _generate('''
class Confirmed extends Rule<Object?> {
  const Confirmed({this.other});
  final String? other;
}

@Dto(strict: true)
class A {
  @Confirmed()
  final String password;

  @Confirmed(other: 'pin_again')
  final String? pin;

  const A({required this.password, this.pin});
}''');
      String code = output.replaceAll(RegExp(r'\s+'), '');
      expect(
        code,
        contains(
          "_keys=<String>{'password','pin','password_confirmation','pin_again',}",
        ),
      );
    });

    test('@DateFormatted with a letter it does not know', () async {
      String rule = '''
class DateFormatted extends Rule<String> {
  const DateFormatted(this.format);
  final String format;
}
''';
      await expectError('''
$rule
@Dto()
class A {
  @DateFormatted('Y-m-d Q')
  final String? day;
  const A({this.day});
}''', '@DateFormatted on A.day: the letter "Q"');
      String output = await _generate(
        r'''
''' +
            rule +
            r'''
@Dto()
class A {
  @DateFormatted('Y-m-d\\TH:i:sP \\Q')
  final String? day;
  const A({this.day});
}''',
      );
      expect(output, isNot(startsWith('ERROR')));
    });

    test('@RequiredIf on a field that is always required', () {
      return expectError('''
@Dto()
class A {
  @RequiredIf('type', 'company')
  final String company;
  const A({required this.company});
}''', '@RequiredIf on A.company does nothing');
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

  group('DTO file rules |', () {
    // copies of the new annotations, so the test also runs against a
    // dox_validation release that does not have them yet
    const String stubs = '''
class MinSize {
  const MinSize(this.size, {this.message});
  final String size;
  final String? message;
}
class MimeTypes {
  const MimeTypes(this.types, {this.message});
  final List<String> types;
  final String? message;
}
class Dimensions {
  const Dimensions({this.width, this.height, this.minWidth, this.maxWidth,
    this.minHeight, this.maxHeight, this.ratio, this.message});
  final int? width;
  final int? height;
  final int? minWidth;
  final int? maxWidth;
  final int? minHeight;
  final int? maxHeight;
  final double? ratio;
  final String? message;
}
''';

    test('size, MIME type and dimension checks', () async {
      String out = await _generate('''
$stubs
@Dto()
class A {
  @MinSize('1KB')
  @MimeTypes(<String>['IMAGE/PNG', 'image/*'])
  @Dimensions(minWidth: 100, maxHeight: 500, ratio: 3 / 2)
  final RequestFile a;
  const A({required this.a});
}''');
      expect(out, isNot(startsWith('ERROR')), reason: out);
      expect(out, contains('c0.length >= 1024'));
      expect(out, contains('IssueCodes.minSize'));
      expect(out, contains("params: const <String, Object?>{'min': '1KB'}"));
      // the output is formatted, so check the parts
      expect(out, contains('FileTypes.matchesMimeTypes(c0'));
      expect(out, contains("'image/png',"));
      expect(out, contains('IssueCodes.mimeTypes'));
      expect(out, contains('ImageSize.fits('));
      expect(out, contains('minWidth: 100,'));
      expect(out, contains('maxHeight: 500,'));
      expect(out, contains('ratio: 1.5,'));
      expect(out, contains('IssueCodes.dimensions'));
      expect(out, contains('DefaultMessages.dimensions'));
    });

    test('bad values stop the build', () async {
      String out = await _generate('''
$stubs
@Dto()
class A {
  @MinSize('a lot')
  final RequestFile a;
  @Dimensions()
  final RequestFile b;
  const A({required this.a, required this.b});
}''');
      expect(out, contains('@MinSize on'));
      expect(out, contains('needs a size like'));
      expect(out, contains('@Dimensions on'));
      expect(out, contains('needs at least one limit'));
    });
  });

  group('DTO prefixes |', () {
    test('types from a prefixed import keep the prefix', () async {
      String out = await _generate(
        '''
@Dto()
class Outer {
  final o.Inner inner;
  final List<o.Inner> list;
  final o.Status status;
  final Map<String, o.Status>? byName;
  const Outer({
    required this.inner,
    required this.list,
    required this.status,
    this.byName,
  });
}
''',
        imports: "import 'other.dart' as o;",
        files: <String, String>{
          'a|lib/other.dart': '''
import 'package:dox_validation/dox_validation.dart';
enum Status { draft, live }
@Dto()
class Inner {
  final String name;
  const Inner({required this.name});
}
''',
        },
      );
      expect(out, isNot(startsWith('ERROR')));
      expect(out, contains(r'o.$InnerDto.convert('));
      expect(out, contains(r'o.$InnerDto.fromMap('));
      expect(out, contains('List<o.Inner>'));
      expect(out, contains('o.Status.draft'));
      expect(out, contains('Map<String, o.Status>?'));
      expect(out, isNot(contains(' Inner ')));
    });
  });

  group('DTO registry |', () {
    test('lib/generated/dtos.g.dart lists every DTO', () async {
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
        generateFor: <String>{r'a|lib/$lib$'},
        outputs: <String, Object>{
          'a|lib/generated/dtos.g.dart': decodedMatches(
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
      expect(output, contains('const List<DtoSchema<Object>> dtos'));
      expect(output, contains(r'$CreatePostDto,'));
      expect(output, contains(r'$CreateUserDto,'));
      expect(output, isNot(contains('NotADto')));
    });

    test('an app with no DTOs gets an empty list', () async {
      String output = '';
      await testBuilder(
        buildDoxDtos(BuilderOptions.empty),
        <String, String>{
          ..._validation,
          // like dox_core: it exports dox_validation and has AppConfig
          'core|lib/core.dart': '''
export 'package:dox_validation/dox_validation.dart';
class AppConfig {}
''',
          'a|lib/config/app.dart': '''
import 'package:core/core.dart';
class NotADto {}
''',
        },
        rootPackage: 'a',
        generateFor: <String>{r'a|lib/$lib$'},
        outputs: <String, Object>{
          'a|lib/generated/dtos.g.dart': decodedMatches(
            predicate<String>((String s) {
              output = s;
              return true;
            }),
          ),
        },
      );
      // only the import that gives DtoSchema, so no unused import
      expect(output, contains("import 'package:core/core.dart';"));
      expect(output, isNot(contains("import 'package:a/")));
      expect(
        output,
        contains('final List<DtoSchema<Object>> dtos = <DtoSchema<Object>>[];'),
      );
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

    test('no DTOs and no AppConfig import, no file', () async {
      await testBuilder(
        buildDoxDtos(BuilderOptions.empty),
        <String, String>{
          ..._validation,
          // like dox_orm: it uses dox_validation, but it is not an app
          'a|lib/a.dart': '''
import 'package:dox_validation/dox_validation.dart';
abstract class A implements Rule<String> {}
''',
        },
        rootPackage: 'a',
        generateFor: <String>{r'a|lib/$lib$'},
        outputs: <String, Object>{},
      );
    });
  });
}

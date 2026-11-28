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
  Map<String, String> packages = const <String, String>{},
}) async {
  Map<String, String> sources = <String, String>{
    ..._validation,
    ...packages,
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
        if (files[file]!.contains('@Dto'))
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

  /// Not used: @Describe wins.
  @Describe("Age in years. It's \\\$0 to join.")
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
      // no @RequiredIf or @RequiredWith: the converted values are not kept
      expect(out, contains('bool get usesRequiredWhen => false;'));
    });

    test('snake_case keys and text changes', () {
      expect(out, contains('Object? firstName = state.string('));
      expect(out, contains("state.read(input, 'first_name'),"));
      expect(out, contains('trim: true,'));
    });

    test('straight-line rules', () {
      expect(
        out,
        contains('firstName.runes.length >= 3 && firstName.runes.length <= 50'),
      );
      expect(out, contains('IssueCodes.lengthBetween'));
      expect(out, contains('Patterns.email.hasMatch(email)'));
      expect(
        out,
        contains("static final RegExp _r0 = RegExp('^(?:[a-z]+)\\\$');"),
      );
      expect(out, contains("state.context(path, 'slug', slug)"));
      expect(out, contains("'admin' => Role.admin,"));
    });

    test('list rules check the list, value rules each item', () {
      expect(out, contains('if (!(emails.length <= 5))'));
      expect(out, contains('Patterns.email.hasMatch(v)'));
    });

    test('messages, async rules, validate() and Maybe', () {
      expect(out, contains("'required': 'Fill in {field}'"));
      expect(out, contains('String value = dto.email;'));
      expect(
        out,
        contains(
          "await state.asyncRule(\n        const Unique('users'),\n        value,",
        ),
      );
      expect(out, contains('dto.validate(DtoErrors(state, path));'));
      expect(out, contains('Maybe<String?>(bio as String?)'));
    });

    test('defaults and the JSON Schema', () {
      expect(
        out,
        contains('role: role is Undefined ? Role.user : role as Role'),
      );
      expect(out, contains("'title': 'CreateUser'"));
      expect(out, contains("'description': 'The name.'"));
      // @Describe: the text is escaped for a Dart string.
      expect(
        out,
        contains(r"'description': 'Age in years. It\'s \$0 to join.'"),
      );
      expect(out, isNot(contains('Not used')));
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
}

@Dto()
class B {
  final A a;
  const B({required this.a});
}

@Dto()
class C {
  final String name;
  const C({required this.name});
}''');
        // the generated code is formatted, so compare without spaces
        String code = output.replaceAll(RegExp(r'\s+'), '');
        expect(
          code,
          contains(
            "state.requiredWhen(constRequiredIf('type','company'),company,input,path,'company',_messages,);",
          ),
        );
        expect(
          code,
          contains(
            "state.requiredWhen(constRequiredWith(<String>['type']),size,input,path,'size',_messages,);",
          ),
        );
        // the rules run after all fields are converted, so a rule can
        // read a field that comes after it
        expect(
          code.indexOf('state.requiredWhen('),
          greaterThan(code.indexOf('Object?size=')),
        );
        // A has the rules and B nests A: both keep the converted values.
        // C has none, so only C says it does not use them.
        String flag = 'boolgetusesRequiredWhen=>false;';
        expect(flag.allMatches(code), hasLength(1));
        expect(code.indexOf(flag), greaterThan(code.indexOf(r'class_$CDto')));
      },
    );

    test('a DTO deep in lists and maps still counts as nested', () async {
      String output = await _generate('''
@Dto()
class A {
  @Trim()
  final String? type;

  @RequiredIf('type', 'company')
  final String? vat;

  const A({this.type, this.vat});

  void validate(DtoErrors errors) {}
}

@Dto()
class B {
  final List<List<A>> rows;
  const B({required this.rows});
}

@Dto()
class C {
  final Map<String, List<A?>> groups;
  const C({required this.groups});
}''');
      expect(output, isNot(startsWith('ERROR')), reason: output);
      String code = output.replaceAll(RegExp(r'\s+'), '');
      // A has the rule, and B and C hold A deep inside: all keep values
      expect(code, isNot(contains('boolgetusesRequiredWhen=>false;')));
      // validate() of A runs for each item at any depth
      String b = code.substring(
        code.indexOf(r'class_$BDto'),
        code.indexOf(r'class_$CDto'),
      );
      expect(b, contains('boolgethasChecks=>true;'));
      expect(
        b,
        contains(r"$ADto.crossCheck(x1,state,<Object>[...path,'rows',i0,i1]);"),
      );
      String c = code.substring(code.indexOf(r'class_$CDto'));
      expect(c, contains('boolgethasChecks=>true;'));
      expect(
        c,
        contains(
          r"if(x1!=null){$ADto.crossCheck(x1,state,<Object>[...path,'groups',e0.key,i1",
        ),
      );
    });

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

    test('emptyStringsToNull reads "" as null', () async {
      String output = await _generate('''
@Dto(emptyStringsToNull: true)
class A {
  final String? note;

  const A({this.note});
}''');
      expect(output, isNot(startsWith('ERROR')), reason: output);
      expect(output, contains("state.read(input, 'note', emptyToNull: true)"));
    });

    group('ValidationFlags |', () {
      const String dto = '''
@Dto()
class A {
  @MinLength(2)
  final String name;
  final List<String> tags;
  final Maybe<String> nick;
  final List<String>? extra;

  const A({
    required this.name,
    required this.tags,
    this.nick = const Maybe.missing(),
    this.extra,
  });
}''';

      // a stub of the DtoState of a dox_validation with the flags
      const String newState = 'class DtoState { bool get allErrors => false; }';

      test('an older dox_validation gets the old code', () async {
        String code = (await _generate(dto)).replaceAll(RegExp(r'\s+'), '');
        expect(code, isNot(contains('allErrors')));
        expect(code, isNot(contains('emptyList')));
        expect(code, isNot(contains('sentEmpty')));
        expect(
          code,
          contains('if(state.issues.length!=issuesBefore)returnnull;'),
        );
      });

      test('a dox_validation with the flags reads them at run time', () async {
        String output = await _generate('$dto\n$newState');
        expect(output, isNot(startsWith('ERROR')), reason: output);
        String code = output.replaceAll(RegExp(r'\s+'), '');
        // dtoAllErrors: the rules run, then the code stops
        expect(
          code,
          contains(
            'if(state.issues.length!=issuesBefore&&!state.allErrors)returnnull;',
          ),
        );
        expect(
          code.indexOf('if(state.issues.length!=issuesBefore)returnnull;'),
          greaterThan(code.indexOf('MinLength')),
        );
        // dtoRejectEmptyList: only the required list
        expect(
          code,
          contains(
            "if(tags==null||tagsisUndefined||state.emptyList(tags)){state.required(path,'tags',_messages);tags=invalid;}",
          ),
        );
        expect(RegExp(r'emptyList\(').allMatches(code), hasLength(1));
        // a list with a bad item is bad: no empty check, no list rules
        expect(code, contains('intb0=state.issues.length;'));
        expect(code, contains('tags=state.issues.length!=b0?invalid:o0;'));
        // dtoMaybeRejectsEmpty
        expect(
          code,
          contains(
            "if(nick==null||state.sentEmpty(nick,input,'nick'))state.required(path,'nick',_messages);",
          ),
        );
      });

      test('the runtime comes through an import', () async {
        String code = (await _generate(
          dto,
          imports: "import 'state.dart';",
          files: <String, String>{'a|lib/state.dart': newState},
        )).replaceAll(RegExp(r'\s+'), '');
        expect(code, contains('state.allErrors'));
        expect(code, contains('state.emptyList(tags)'));
      });

      test('a hidden or prefixed DtoState gives the old code', () async {
        for (String import in <String>[
          "import 'state.dart' hide DtoState;",
          "import 'state.dart' as st;",
        ]) {
          String code = (await _generate(
            dto,
            imports: import,
            files: <String, String>{'a|lib/state.dart': newState},
          )).replaceAll(RegExp(r'\s+'), '');
          expect(code, isNot(contains('allErrors')), reason: import);
          expect(code, isNot(contains('invalid:o0')), reason: import);
        }
      });

      test('a map with a bad item is bad too', () async {
        String code = (await _generate('''
@Dto()
class A {
  final Map<String, int> scores;
  const A({required this.scores});
}
$newState''')).replaceAll(RegExp(r'\s+'), '');
        expect(code, contains('scores=state.issues.length!=b0?invalid:o0;'));
      });

      test('a DTO with no rules still stops before it builds', () async {
        String code = (await _generate('''
@Dto()
class A {
  final int age;
  const A({required this.age});
}
$newState''')).replaceAll(RegExp(r'\s+'), '');
        expect(
          code,
          contains(
            'if(state.issues.length!=issuesBefore&&!state.allErrors)returnnull;if(state.issues.length!=issuesBefore)returnnull;returnA(',
          ),
        );
      });
    });

    test('a field local has the name of its field, or a suffix', () async {
      String output = await _generate('''
@Dto()
class A {
  final String name;
  final String state;
  final String path;
  final int x0;
  final String invalid;
  final DateTime? sentAt;
  const A({
    required this.name,
    required this.state,
    required this.path,
    required this.x0,
    required this.invalid,
    this.sentAt,
  });
}''');
      expect(output, isNot(startsWith('ERROR')), reason: output);
      // the name of the field, declared with its first value
      expect(output, contains('Object? name = state.string('));
      // a field with the name of a parameter, a generated local or a
      // constant of dox_validation gets a suffix
      expect(output, contains('Object? stateValue = state.string('));
      expect(output, contains('Object? pathValue = state.string('));
      expect(output, contains('Object? x0Value = state.integer('));
      expect(output, contains('Object? invalidValue = state.string('));
      expect(output, contains('name: name as String,'));
      expect(output, contains('state: stateValue as String,'));
      // toMap(): no temp for a plain value, one when the value is read two
      // times
      expect(output, contains("'name': dto.name"));
      expect(output, contains('DateTime? sentAt = dto.sentAt;'));
      expect(
        output,
        contains('sentAt == null ? null : sentAt.toIso8601String()'),
      );
    });

    test('a field named like a type, and an X in a type name', () async {
      String output = await _generate('''
@Dto()
class Xray {
  final int id;
  const Xray({required this.id});
}

@Dto()
class HasXray {
  final int num;
  @In(<int>[1, 2])
  final int level;
  final Xray xray;
  final List<Xray> items;
  final List<DateTime>? days;
  const HasXray({
    required this.num,
    required this.level,
    required this.xray,
    required this.items,
    this.days,
  });
}''');
      expect(output, isNot(startsWith('ERROR')), reason: output);
      // `num` is a type of the generated code, so the local is not `num`
      expect(output, contains('Object? numValue = state.integer('));
      expect(output, contains('const <num>{1, 2}'));
      // the X of a type name stays
      expect(output, contains(r'$XrayDto.toMap(dto.xray)'));
      expect(output, contains('Xray x0 in dto.items'));
    });

    test('@OrDefault drops the issues of its field', () async {
      String output = await _generate('''
@Dto()
class A {
  @OrDefault()
  @Min(1)
  final int days;

  const A({this.days = 30});
}''');
      expect(output, isNot(startsWith('ERROR')), reason: output);
      String code = output.replaceAll(RegExp(r'\s+'), '');
      expect(code, contains('intdaysIssuesBefore=state.issues.length;'));
      expect(
        code,
        contains('if(state.dropIssuesAfter(daysIssuesBefore))days=undefined;'),
      );
      expect(code, contains('intdaysIssuesBeforeRules=state.issues.length;'));
      expect(
        code,
        contains(
          'if(state.dropIssuesAfter(daysIssuesBeforeRules))days=undefined;',
        ),
      );
      expect(code, contains('daysisUndefined?30:daysasint'));
    });

    test('@OrDefault on a Maybe field builds', () async {
      String output = await _generate('''
@Dto()
class A {
  @OrDefault()
  final Maybe<int> days;

  const A({this.days = const Maybe.missing()});
}''');
      expect(output, isNot(startsWith('ERROR')), reason: output);
      String code = output.replaceAll(RegExp(r'\s+'), '');
      expect(
        code,
        contains('if(state.dropIssuesAfter(daysIssuesBefore))days=undefined;'),
      );
      expect(code, contains('daysisUndefined?constMaybe<int>.missing()'));
    });

    test('@OrDefault on a required field stops the build', () async {
      String output = await _generate('''
@Dto()
class A {
  @OrDefault()
  final int days;

  const A({required this.days});
}''');
      expect(output, contains('@OrDefault on'));
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

  group('DTO options and Laravel rules |', () {
    /// The generated code of [source] with no spaces.
    Future<String> code(String source) async {
      String output = await _generate(source);
      expect(output, isNot(startsWith('ERROR')), reason: output);
      return output.replaceAll(RegExp(r'\s+'), '');
    }

    Future<void> expectError(String source, String message) async {
      String output = await _generate(source);
      expect(output, startsWith('ERROR'));
      expect(output, contains(message));
    }

    const String plain = '''
@Dto()
class A {
  final String name;
  final List<String> tags;
  final int age;
  final bool on;
  const A({required this.name, required this.tags, required this.age, required this.on});
}''';

    test('no option: no trim, coerce or names', () async {
      String c = await code(plain);
      expect(c, isNot(contains('trim:true')));
      expect(c, isNot(contains('coerce')));
      expect(c, isNot(contains('_a')));
      expect(c, isNot(contains('state.attributes')));
    });

    test('@Dto(trim: true) trims each text field and item', () async {
      String c = await code(plain.replaceFirst('@Dto()', '@Dto(trim: true)'));
      expect(
        c,
        contains(
          "state.string(state.read(input,'name'),path,'name',_messages,trim:true",
        ),
      );
      expect(c, contains('state.string(tags[i0],q0,i0,_messages,trim:true)'));
      expect(
        c,
        contains("state.integer(state.read(input,'age'),path,'age',_messages"),
      );
      // with emptyStringsToNull, blank text is null too
      c = await code(
        plain.replaceFirst(
          '@Dto()',
          '@Dto(trim: true, emptyStringsToNull: true)',
        ),
      );
      expect(
        c,
        contains("state.read(input,'name',emptyToNull:true,trim:true)"),
      );
    });

    test('@Dto(coerce: true) reads JSON text as numbers and bools', () async {
      String c = await code('''
@Dto(coerce: true)
class A {
  final int age;
  final double price;
  final num size;
  final List<bool> flags;
  final String name;
  const A({required this.age, required this.price, required this.size, required this.flags, required this.name});
}''');
      expect(
        c,
        contains(
          "state.integer(state.read(input,'age'),path,'age',_messages,coerce:true",
        ),
      );
      expect(
        c,
        contains(
          "state.decimal(state.read(input,'price'),path,'price',_messages,coerce:true",
        ),
      );
      expect(
        c,
        contains(
          "state.number(state.read(input,'size'),path,'size',_messages,coerce:true",
        ),
      );
      expect(
        c,
        contains('state.boolean(flags[i0],q0,i0,_messages,coerce:true)'),
      );
      expect(
        c,
        contains("state.string(state.read(input,'name'),path,'name',_messages"),
      );
    });

    test('@Dto(attributes:) names the fields in messages', () async {
      String c = await code('''
@Dto(attributes: <String, String>{'first_name': 'first name'})
class A {
  final String firstName;
  const A({required this.firstName});
}''');
      expect(
        c,
        contains(
          "staticconstMap<String,String>_attributes=<String,String>{'first_name':'firstname',};",
        ),
      );
      expect(
        c,
        contains(
          'convert(Object?input,DtoStatestate,List<Object>path){state.attributes(path,_attributes);if(inputis!Map)',
        ),
      );
    });

    test('@After and @Before take words and another field', () async {
      String c = await code('''
@Dto()
class A {
  final DateTime start;

  @After('start')
  @Before('tomorrow')
  final DateTime end;

  @AfterOrEqual('today')
  @BeforeOrEqual('end')
  final List<DateTime>? days;

  @AfterOrEqual('2024-01-01')
  @After('yesterday')
  final Maybe<DateTime> at;

  const A({required this.start, required this.end, this.days, this.at = const Maybe.missing()});
}''');
      expect(c, contains('if(!(startis!DateTime||end.isAfter(start))){'));
      expect(c, contains("params:const<String,Object?>{'date':'start'}"));
      expect(
        c,
        contains(
          'end.isBefore(DateTime.utc(state.now.year,state.now.month,state.now.day+1)',
        ),
      );
      expect(
        c,
        contains(
          '!v.isBefore(DateTime.utc(state.now.year,state.now.month,state.now.day',
        ),
      );
      expect(
        c,
        contains('IssueCodes.afterOrEqual,DefaultMessages.afterOrEqual'),
      );
      expect(c, contains('if(!(endis!DateTime||!v.isAfter(end))){'));
      expect(
        c,
        contains('IssueCodes.beforeOrEqual,DefaultMessages.beforeOrEqual'),
      );
      expect(
        c,
        contains('staticfinalDateTime_d0=DateTime.fromMicrosecondsSinceEpoch('),
      );
      expect(c, contains('!at.isBefore(_d0)'));
      expect(
        c,
        contains(
          'at.isAfter(DateTime.utc(state.now.year,state.now.month,state.now.day-1)',
        ),
      );
    });

    test('@After needs a date, a word or a DateTime field', () async {
      await expectError('''
@Dto()
class A {
  final String start;

  @After('start')
  final DateTime end;

  const A({required this.start, required this.end});
}''', '@After on A.end needs an ISO 8601 date');
      await expectError('''
@Dto()
class A {
  @Before('2024-13-01')
  final DateTime end;
  const A({required this.end});
}''', 'not "2024-13-01"');
      await expectError('''
@Dto()
class A {
  @After('end')
  final DateTime end;
  const A({required this.end});
}''', '@After on A.end needs an ISO 8601 date');
    });

    test('the new Required* rules, @Filled and @Present', () async {
      String c = await code('''
@Dto()
class A {
  final String? type;
  final String? email;

  @RequiredUnless('type', 'guest')
  @RequiredWithout(<String>['email'])
  final String? phone;

  @RequiredWithoutAll(<String>['email', 'phone'])
  @Filled()
  final Maybe<String> fax;

  @Present()
  final String? note;

  const A({this.type, this.email, this.phone, this.fax = const Maybe.missing(), this.note});
}''');
      expect(
        c,
        contains(
          "state.requiredWhen(constRequiredUnless('type','guest'),phone,input,path,'phone',_messages,);",
        ),
      );
      expect(
        c,
        contains(
          "state.requiredWhen(constRequiredWithout(<String>['email']),phone",
        ),
      );
      expect(
        c,
        contains(
          "state.requiredWhen(constRequiredWithoutAll(<String>['email','phone']),fax",
        ),
      );
      expect(
        c,
        contains(
          "state.requiredWhen(constFilled(),fax,input,path,'fax',_messages)",
        ),
      );
      expect(
        c,
        contains(
          "state.requiredWhen(constPresent(),note,input,path,'note',_messages)",
        ),
      );
      expect(c, isNot(contains('boolgetusesRequiredWhen=>false;')));
    });

    test('the new Required* rules need a field that can be missing', () async {
      await expectError('''
@Dto()
class A {
  @RequiredUnless('type', 'guest')
  final String phone;
  const A({required this.phone});
}''', '@RequiredUnless on A.phone does nothing');
      await expectError('''
@Dto()
class A {
  final String? emailAddress;
  @RequiredWithout(<String>['emailAddress'])
  final String? phone;
  const A({this.emailAddress, this.phone});
}''', "'emailAddress' is a Dart field name. Use the input key 'email_address'.");
    });

    test('@ExcludeIf and @ExcludeUnless skip the field', () async {
      String c = await code('''
@Dto()
class A {
  final String? type;

  @ExcludeIf('type', 'person')
  @ExcludeUnless('type', <String>['company', 'shop'])
  @RequiredIf('type', 'shop')
  @MinLength(3)
  final String? vat;

  const A({this.type, this.vat});
}''');
      expect(
        c,
        contains(
          "Object?vat;boolvatExcluded=constExcludeIf('type','person').appliesTo(input)||constExcludeUnless('type',<String>['company','shop',]).appliesTo(input);if(vatExcluded){vat=undefined;}else{vat=state.string(state.read(input,'vat'),path,'vat',_messages);}",
        ),
      );
      expect(
        c,
        contains(
          "if(!vatExcluded)state.requiredWhen(constRequiredIf('type','shop'),vat",
        ),
      );
      // the rules see `undefined`, so they do not run
      expect(c, contains('if(vatisString){'));
      await expectError('''
@Dto()
class A {
  @ExcludeIf('type', 'person')
  final String vat;
  const A({required this.vat});
}''', '@ExcludeIf on A.vat does nothing');
      await expectError('''
@Dto()
class A {
  @Prohibited()
  final String debug;
  const A({required this.debug});
}''', '@Prohibited on A.debug can never pass: the field is always required');
      await expectError(
        '''
@Dto()
class A {
  final String? type;
  @ProhibitedIf('type', 'guest')
  final String debug;
  const A({this.type, required this.debug});
}''',
        '@ProhibitedIf on A.debug can not pass when its condition matches: the field is always required',
      );
    });

    const String rules = '''
class Different<T> extends Rule<T> {
  const Different(this.other);
  final String other;
}
class Accepted<T> extends Rule<T> {
  const Accepted();
}
class GreaterThanField<T extends num> extends Rule<T> {
  const GreaterThanField(this.other);
  final String other;
}
''';

    test('rules that read the next key check the whole list', () async {
      String c = await code('''
$rules
@Dto()
class A {
  final List<String> old;

  @Different('old')
  @Accepted()
  final List<String>? tags;

  @Prohibited()
  @ProhibitedIf('old', 'x')
  final List<String>? gone;

  @GreaterThanField('min')
  final int max;
  final int min;

  const A({required this.old, this.tags, this.gone, required this.max, required this.min});
}''');
      expect(
        c,
        contains(
          "constDifferent('old').check(tags,state.context(path,'tags',tags))",
        ),
      );
      // @Prohibited reads the raw key, for every value
      expect(
        c,
        contains(
          "state.requiredWhen(constProhibited(),gone,input,path,'gone',_messages",
        ),
      );
      expect(
        c,
        contains(
          "state.requiredWhen(constProhibitedIf('old','x'),gone,input,path,'gone',_messages",
        ),
      );
      // a rule that does not read a key still checks each item
      expect(c, contains("constAccepted().check(v,state.context(q,i,v))"));
      expect(
        c,
        contains(
          "constGreaterThanField('min').check(max,state.context(path,'max',max))",
        ),
      );
      await expectError('''
$rules
@Dto()
class A {
  @GreaterThanField('min')
  final List<int> max;
  final int min;
  const A({required this.max, required this.min});
}''', '@GreaterThanField checks num');
      await expectError('''
$rules
@Dto()
class A {
  @Different('oldName')
  final String? name;
  final String? oldName;
  const A({this.name, this.oldName});
}''', "@Different on A.name: 'oldName' is a Dart field name");
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
      expect(out, contains('a.length >= 1024'));
      expect(out, contains('IssueCodes.minSize'));
      expect(out, contains("params: const <String, Object?>{'min': '1KB'}"));
      // the output is formatted, so check the parts
      expect(out, contains('FileTypes.matchesMimeTypes(a'));
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

    // origin/main builds these: the class keeps the prefix of prefixOf()
    Map<String, (String, String)> imports = <String, (String, String)>{
      'a prefixed import, then the plain one': (
        "import 'other.dart' as o2;\nimport 'other.dart';",
        '',
      ),
      'a prefixed barrel, then the plain file': (
        "import 'barrel.dart' as b;\nimport 'other.dart';",
        '',
      ),
      'only a prefixed import': ("import 'other.dart' as o;", 'o.'),
    };
    for (MapEntry<String, (String, String)> shape in imports.entries) {
      test('a nested DTO: ${shape.key}', () async {
        String type = '${shape.value.$2}Inner';
        String out = await _generate(
          '''
@Dto()
class Outer {
  final $type inner;
  const Outer({required this.inner});
}
''',
          imports:
              "import 'package:dox_annotation/dox_annotation.dart';\n"
              '${shape.value.$1}',
          packages: <String, String>{
            'dox_annotation|lib/dox_annotation.dart':
                "export 'src/json_writer.dart';",
            'dox_annotation|lib/src/json_writer.dart': File(
              '../dox-annotation/lib/src/json_writer.dart',
            ).readAsStringSync(),
          },
          files: <String, String>{
            'a|lib/barrel.dart': "export 'other.dart';",
            'a|lib/other.dart': '''
import 'package:dox_validation/dox_validation.dart';
import 'package:dox_annotation/dox_annotation.dart';

part 'other.g.dart';

@Dto()
class Inner {
  final String name;
  const Inner({required this.name});
}
''',
          },
        );
        String p = shape.value.$2;
        expect(out, isNot(startsWith('ERROR')));
        expect(out, contains('$p\$InnerDto.convert('));
        expect(out, contains('$p\$InnerDto.fromMap('));
        expect(out, contains('$p\$InnerDto.toMap('));
      });
    }

    test('a nested DTO imported with show: a clear error', () async {
      String out = await _generate(
        '''
@Dto()
class Outer {
  final Inner inner;
  const Outer({required this.inner});
}
''',
        imports: "import 'other.dart' show Inner;",
        files: <String, String>{
          'a|lib/other.dart': '''
import 'package:dox_validation/dox_validation.dart';
@Dto()
class Inner {
  final String name;
  const Inner({required this.name});
}
''',
        },
      );
      expect(out, startsWith('ERROR'));
      expect(
        out,
        contains(
          'The type Inner of Outer.inner is a @Dto, but its generated code '
          'is hidden here',
        ),
      );
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
    group('no JSON writer |', () {
      /// a dox_annotation with JsonWriter and JsonObjectWriter
      final Map<String, String> annotation = <String, String>{
        'dox_annotation|lib/dox_annotation.dart':
            "export 'src/json_writer.dart';",
        'dox_annotation|lib/src/json_writer.dart': File(
          '../dox-annotation/lib/src/json_writer.dart',
        ).readAsStringSync(),
      };

      test(
        'a DTO writeObject() gives toMap(), with no \$write function',
        () async {
          String out = await _generate(
            '''
@Dto()
class Inner {
  final int id;
  const Inner({required this.id});
}

@Dto()
class Outer {
  final Inner inner;
  final List<Inner> all;
  final Inner? maybe;
  const Outer({required this.inner, required this.all, this.maybe});
}

@Dto()
class OwnJson {
  final int id;
  const OwnJson({required this.id});
  Map<String, dynamic> toJson() => <String, dynamic>{};
}
''',
            imports: "import 'package:dox_annotation/dox_annotation.dart';",
            packages: annotation,
          );
          expect(out, isNot(startsWith('ERROR')));
          expect(
            out,
            contains(
              r'class _$OuterDto extends DtoSchema<Outer> '
              'implements JsonObjectWriter {',
            ),
          );
          expect(out, contains(r'$InnerDto.toMap(dto.inner)'));
          expect(out, contains('writer.value(toMap(object as Outer))'));
          // a DTO with its own toJson() keeps it
          expect(
            out,
            contains(r'class _$OwnJsonDto extends DtoSchema<OwnJson> {'),
          );
          expect(out, isNot(contains('JsonRun')));
          expect(out, isNot(contains(r'$write')));
        },
      );

      const String source = '''
@Dto()
class Inner {
  final int id;
  const Inner({required this.id});
}
''';

      test('a toJson() from a mixin: no writeObject()', () async {
        String out = (await _generate(
          r'''
mixin Loud {
  Map<String, dynamic> toJson() => <String, dynamic>{};
}

@Dto()
class FromMixin with Loud {
  final int id;
  FromMixin({required this.id});
}
''',
          imports: "import 'package:dox_annotation/dox_annotation.dart';",
          packages: annotation,
        )).replaceAll(RegExp(r'\s'), '');
        expect(
          out,
          contains(r'class_$FromMixinDtoextendsDtoSchema<FromMixin>{'),
        );
        expect(out, isNot(contains('writeObject')));
      });

      test('an older dox_annotation: no writeObject()', () async {
        String out = await _generate(source);
        expect(out, isNot(contains('ERROR')));
        expect(out, isNot(contains('writeObject')));
        expect(out, isNot(contains('JsonObjectWriter')));
      });

      test('a class of the app with the same name: no writeObject()', () async {
        String out = await _generate('''
class JsonWriter {}
class JsonObjectWriter {}
$source
''');
        expect(out, isNot(contains('writeObject')));
      });
    });
  });
}

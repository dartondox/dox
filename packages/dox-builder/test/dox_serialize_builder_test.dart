import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dox_builder/dox_builder.dart';
import 'package:test/test.dart';

/// a small copy of dox_core: the Serializer and the `@Name` that the
/// generator finds by name, in a dox library.
const String _core = '''
export 'package:dox_annotation/dox_annotation.dart';

class Name {
  const Name(this.key);
  final String key;
}

class Serializer<T> {
  Serializer(dynamic data);
  Map<String, dynamic> convert(T m) => <String, dynamic>{};
  dynamic toJson() => null;
  static List<T>? listOf<T>(Serializer<T> serializer) => null;
  static bool hasItem(Serializer<Object?> serializer) => false;
  static T itemOf<T>(Serializer<T> serializer) => throw 0;
}
class IocContainer {}
''';

Map<String, String> _sources(String source) {
  String annotation(String name) {
    return File('../dox-annotation/lib/src/$name').readAsStringSync();
  }

  return <String, String>{
    'dox_annotation|lib/dox_annotation.dart': '''
export 'src/json_writer.dart';
export 'src/serialize.dart';
''',
    'dox_annotation|lib/src/json_writer.dart': annotation('json_writer.dart'),
    'dox_annotation|lib/src/serialize.dart': annotation('serialize.dart'),
    'dox_core|lib/dox_core.dart': _core,
    'a|lib/a.dart':
        '''
import 'package:dox_core/dox_core.dart';

part 'a.g.dart';

$source
''',
  };
}

/// The generated part of [source], and the build logs.
Future<(String, String)> _generate(String source) async {
  String output = '';
  List<String> logs = <String>[];
  await testBuilder(
    buildDoxModel(BuilderOptions.empty),
    _sources(source),
    rootPackage: 'a',
    onLog: (log) => logs.add(log.message),
    outputs: <String, Object>{
      'a|lib/a.dox_model_generator.g.part': decodedMatches(
        predicate<String>((String text) {
          output = text;
          return true;
        }),
      ),
    },
  );
  return (output, logs.join('\n'));
}

/// The generated `container.g.dart` of [source], and the build logs.
Future<(String, String)> _container(String source) async {
  String output = '';
  List<String> logs = <String>[];
  await testBuilder(
    buildDoxContainer(BuilderOptions.empty),
    _sources(source),
    rootPackage: 'a',
    onLog: (log) => logs.add(log.message),
    outputs: <String, Object>{
      'a|lib/generated/container.g.dart': decodedMatches(
        predicate<String>((String text) {
          output = text;
          return true;
        }),
      ),
    },
  );
  return (output, logs.join('\n'));
}

/// [text] with no white space, to compare code
String _flat(String text) => text.replaceAll(RegExp(r'\s+'), '');

const String _models = '''
class Tag {
  Tag(this.name);
  final String? name;
}

class Post {
  Post(this.title, this.tags);
  final String title;
  final List<Tag> tags;
}

class User implements JsonWritable {
  User(this.name, this.createdAt, this.score, this.posts);
  final String name;
  final DateTime createdAt;
  final int score;
  final List<Post> posts;
  @override
  void writeJson(JsonWriter writer) {}
}
''';

/// one serializer with a body of [body]
String _post(String name, String body) {
  return '''
$_models
@Serialize()
class $name extends Serializer<Post> with _\$$name {
  $name(super.data);

  @override
  Map<String, dynamic> convert(Post m) {
    $body
  }
}
''';
}

void main() {
  group('@Serialize() serializer', () {
    test('the template of make:serializer writes {}', () async {
      final (String out, String logs) = await _generate('''
$_models
@Serialize()
class PostSerializer extends Serializer<Post> {
  PostSerializer(super.data);

  @override
  Map<String, dynamic> convert(Post m) {
    return <String, dynamic>{};
  }
}
''');
      expect(logs, isNot(contains('@Serialize()')));
      String flat = _flat(out);
      expect(
        flat,
        contains(_flat("static final JsonRun _end = JsonRun('{}');")),
      );
      expect(
        flat,
        contains(
          _flat('''
void \$writePostSerializerItem(Post m, JsonWriter writer) {
  writer.run(_\$PostSerializerWriter._end);
}'''),
        ),
      );
      expect(
        flat,
        contains(
          _flat(
            'mixin _\$PostSerializer on Serializer<Post> implements '
            'JsonWritable',
          ),
        ),
      );
      expect(
        flat,
        contains(
          _flat(
            'const SerializeWriter \$PostSerializerWriter = '
            '_\$PostSerializerWriter();',
          ),
        ),
      );
    });

    test('locals, members, a nested map and a nested serializer', () async {
      final (String out, String logs) = await _generate('''
$_models
@Serialize()
class UserInfo extends Serializer<User> with _\$UserInfo {
  UserInfo(super.data);

  static const String top = 'top';
  String get prefix => '#';

  @override
  Map<String, dynamic> convert(User m) {
    bool recent = m.createdAt.isAfter(DateTime.utc(2024));
    return <String, dynamic>{
      'data': m,
      'active': recent,
      'label': m.score > 10 ? top : 'normal',
      'name': '\$prefix\${m.name}',
      'tags': m.posts.map(_title).toList(),
      'rating': <String, dynamic>{'score': m.score, 'half': m.score / 2},
      'posts': PostSerializer(m.posts),
      'me': this,
    };
  }

  String _title(Post p) => p.title;
}

@Serialize()
class PostSerializer extends Serializer<Post> with _\$PostSerializer {
  PostSerializer(super.data);

  @override
  Map<String, dynamic> convert(Post m) => <String, dynamic>{'title': m.title};
}
''');
      expect(logs, isNot(contains('@Serialize()')));
      String flat = _flat(out);
      for (String line in <String>[
        'void _\$writeUserInfoItem(UserInfo serializer, User m, '
            'JsonWriter writer) {',
        'bool recent = m.createdAt.isAfter(DateTime.utc(2024));',
        "static final JsonRun _dataKey = JsonRun('{\"data\":');",
        'm.writeJson(writer);',
        'writer.boolean(recent);',
        "writer.string(m.score > 10 ? UserInfo.top : 'normal');",
        "writer.string('\${serializer.prefix}\${m.name}');",
        'List<String> tags = m.posts.map(serializer._title).toList();',
        'writer.string(tags[i]);',
        "JsonRun('],\"rating\":{\"score\":');",
        'writer.value(m.score / 2);',
        "JsonRun('},\"posts\":[');",
        '\$writePostSerializerItem(postsValue[i], writer);',
        'writer.value(serializer);',
      ]) {
        expect(flat, contains(_flat(line)), reason: line);
      }
    });

    Map<String, (String, String)> fallbacks = <String, (String, String)>{
      'collection if': (
        "return <String, dynamic>{if (m.tags.isEmpty) 'a': 1};",
        'a map in convert() has a collection if, for or spread',
      ),
      'collection for': (
        "return <String, dynamic>{for (Tag t in m.tags) 'a': t.name};",
        'a map in convert() has a collection if, for or spread',
      ),
      'spread': (
        "return <String, dynamic>{'a': 1, ...<String, dynamic>{}};",
        'a map in convert() has a collection if, for or spread',
      ),
      'spread in a nested map': (
        "return <String, dynamic>{'a': <String, dynamic>{...{}}};",
        'a map in convert() has a collection if, for or spread',
      ),
      'a key that is not constant': (
        'return <String, dynamic>{m.title: 1};',
        'a map in convert() has a key that is not a constant string: m.title',
      ),
      'an if statement': (
        "if (m.tags.isEmpty) return <String, dynamic>{}; "
            "return <String, dynamic>{'a': 1};",
        'convert() has an if statement',
      ),
      'a statement': (
        "print(m); return <String, dynamic>{'a': 1};",
        'convert() has a statement that is not a local variable',
      ),
      'no map literal': (
        "Map<String, dynamic> map = <String, dynamic>{'a': 1}; return map;",
        'convert() does not return a map literal',
      ),
      'super': (
        "return <String, dynamic>{'a': super.convert(m)};",
        'convert() uses super',
      ),
    };
    for (MapEntry<String, (String, String)> shape in fallbacks.entries) {
      test('${shape.key}: no writer and a warning', () async {
        final (String out, String logs) = await _generate(
          _post('Shape', shape.value.$1),
        );
        expect(
          logs,
          contains(
            '@Serialize() Shape gets no fast JSON writer: ${shape.value.$2}',
          ),
        );
        expect(out, contains('// Shape: no JSON writer, ${shape.value.$2}'));
        expect(out, contains(r'mixin _$Shape {}'));
        expect(out, isNot(contains(r'$writeShape')));
      });
    }

    test('a serializer with its own toJson(): no writer', () async {
      final (String out, String logs) = await _generate('''
$_models
@Serialize()
class Own extends Serializer<Post> {
  Own(super.data);
  @override
  Map<String, dynamic> convert(Post m) => <String, dynamic>{};
  @override
  dynamic toJson() => 1;
}
''');
      expect(logs, contains('Own gets no fast JSON writer: it has its own'));
      expect(out, contains('// Own: no JSON writer'));
    });
  });

  group('@Serialize() plain class', () {
    test('fields, @Name, nested classes and the map', () async {
      final (String out, String logs) = await _generate('''
enum Level { basic, pro }

@Serialize()
class Address {
  final String city;
  const Address(this.city);
}

@Serialize()
class Extra {
  final int loginCount;
  @Name('seen')
  final DateTime? lastSeen;
  final List<String> roles;
  final Level level;
  final Address home;
  final List<Address> others;
  int counter = 0;
  final int _hidden = 1;
  static const int version = 1;

  Extra(this.loginCount, this.lastSeen, this.roles, this.level, this.home,
      this.others);
}
''');
      expect(
        logs,
        contains('@Serialize() Extra: the field counter is not final'),
      );
      String flat = _flat(out);
      for (String line in <String>[
        "JsonRun('{\"login_count\":');",
        "JsonRun(',\"seen\":');",
        'writer.dateTime(dto.lastSeen);',
        'writer.string(dto.level.name);',
        '\$writeAddress(dto.home, writer);',
        '\$writeAddress(others[i], writer);',
        'Map<String, dynamic> \$ExtraToMap(Extra dto) {',
        "'home': \$AddressToMap(dto.home),",
        "'seen': lastSeen == null ? null : lastSeen.toIso8601String(),",
        'Object? toJsonValue(Object object) => \$ExtraToMap(object as Extra);',
      ]) {
        expect(flat, contains(_flat(line)), reason: line);
      }
      expect(out, isNot(contains('counter')));
      expect(out, isNot(contains('_hidden')));
      expect(out, isNot(contains('version')));
    });

    test('its own toJson(), abstract or generic: no writer', () async {
      final (String out, String logs) = await _generate('''
@Serialize()
class Own {
  final int id;
  const Own(this.id);
  Map<String, dynamic> toJson() => <String, dynamic>{'my_id': id};
}

@Serialize()
abstract class Shape {}

@Serialize()
class Box<T> {
  final T value;
  const Box(this.value);
}
''');
      expect(logs, contains('Own gets no fast JSON writer: it has its own'));
      expect(logs, contains('Shape gets no fast JSON writer: it is abstract'));
      expect(logs, contains('Box gets no fast JSON writer: it is generic'));
      expect(out, contains('// Own: no JSON writer'));
      expect(out, isNot(contains(r'$writeOwn')));
    });
  });

  group('container.g.dart', () {
    test('the writers go into the container', () async {
      final (String out, String logs) = await _container('''
${_post('Fast', "return <String, dynamic>{'title': m.title};")}

@Serialize()
class Slow extends Serializer<Post> {
  Slow(super.data);
  @override
  Map<String, dynamic> convert(Post m) => <String, dynamic>{m.title: 1};
}

class Sub extends Fast {
  Sub(super.data);
}

@Serialize()
class Plain {
  final int id;
  const Plain(this.id);
}
''');
      expect(out, contains(r'c.jsonWriter(i1.$FastWriter);'));
      expect(out, contains(r'c.jsonWriter(i1.$PlainWriter);'));
      expect(out, isNot(contains('Slow')));
      expect(
        logs,
        contains(
          'Sub (package:a/a.dart) extends the @Serialize() serializer Fast',
        ),
      );
    });
  });
}

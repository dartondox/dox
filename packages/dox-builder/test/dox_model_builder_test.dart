import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dox_builder/dox_builder.dart';
import 'package:test/test.dart';

/// the generator finds annotations by class name,
/// so the test defines small copies of the dox_orm annotations.
const String _annotations = '''
class Column {
  final String? name;
  final Function? beforeSave;
  final Function? beforeGet;
  final Object? cast;
  const Column({this.name, this.beforeSave, this.beforeGet, this.cast});
}
class Scope {
  final bool global;
  const Scope({this.global = false});
}
class JsonCast {
  const JsonCast();
}
enum Status { draft, live }
class Computed {
  final String? name;
  const Computed({this.name});
}
class HasMany {
  final Type model;
  final bool? eager;
  final String? foreignKey;
  const HasMany(this.model, {this.eager, this.foreignKey});
}
''';

Future<String> _generate(String model) async {
  String output = '';
  await testBuilder(
    buildDoxModel(BuilderOptions.empty),
    <String, String>{
      'dox_annotation|lib/dox_annotation.dart': "export 'src/dox_model.dart';",
      'dox_annotation|lib/src/dox_model.dart': File(
        '../dox-annotation/lib/src/dox_model.dart',
      ).readAsStringSync(),
      'a|lib/annotations.dart': _annotations,
      'a|lib/user.dart':
          '''
import 'package:dox_annotation/dox_annotation.dart';
import 'annotations.dart';
part 'user.g.dart';
$model
''',
    },
    rootPackage: 'a',
    outputs: <String, Object>{
      'a|lib/user.dox_model_generator.g.part': decodedMatches(
        predicate<String>((String s) {
          output = s;
          return true;
        }),
      ),
    },
  );
  return output;
}

void main() {
  group('DoxModelBuilder |', () {
    test('columns, relations and computed getters', () async {
      String out = await _generate('''
@DoxModel(table: 'users')
class User {
  @Column()
  String? firstName;

  @Column(name: 'mail')
  String? email;

  @HasMany(User, eager: true, foreignKey: 'parent_id')
  List<User> children = <User>[];

  @Computed()
  String get fullName => firstName ?? '';

  @Computed(name: 'label')
  String get display => 'x';

  String get notComputed => 'y';

  static int counter = 0;

  Future<void> onCreating() async {}
}
''');
      expect(out, contains("String get tableName => 'users';"));
      expect(
        out.replaceAll(RegExp(r'\s'), ''),
        contains(
          "<String>['id','first_name','mail','created_at','updated_at',]",
        ),
      );
      expect(out, contains("'mail': instance.email"));
      expect(out, contains("getHasMany<User, User>"));
      expect(out, contains("foreignKey: 'parent_id'"));
      expect(out, contains("map['full_name'] = instance.fullName;"));
      expect(out, contains("map['label'] = instance.display;"));
      expect(out, isNot(contains('notComputed')));
      expect(out, isNot(contains('counter')));
      expect(out, contains('bool get hasModelHooks => true;'));

      /// computed values are not read from the database
      expect(out, isNot(contains("m['full_name']")));
    });

    test('no computed getters, no setComputedValues override', () async {
      String out = await _generate('''
@DoxModel()
class Tag {
  @Column()
  String? name;
}
''');
      expect(out, contains("..name = m['name'] as String?"));
      expect(out, isNot(contains('setComputedValues')));
      expect(out, isNot(contains('hasModelHooks')));
    });

    test('fast getters, dates and a columns only map', () async {
      String out = await _generate('''
@DoxModel()
class Tag {
  @Column()
  String? name;

  @HasMany(Tag, eager: true)
  List<Tag> children = <Tag>[];
}
''');

      /// the getters give the same object each time
      expect(out, contains('get tableColumns => const <String>['));
      expect(out, contains('get relationsResultMatcher => const <String'));

      /// a date from the driver is used as it is
      expect(out, contains("m['created_at'] is DateTime?"));
      expect(out, contains('bool get readsRowDates => true;'));

      /// columnsToMap() has no relations, convertToMap() adds them
      String columns = out.substring(
        out.indexOf('columnsToMap() {'),
        out.indexOf('convertToMap('),
      );
      expect(columns, contains("'name': instance.name"));
      expect(columns, isNot(contains('children')));
      expect(out, contains("map['children'] = toMap(instance.children);"));
    });

    test('a beforeGet hook keeps dates as strings', () async {
      String out = await _generate('''
@DoxModel()
class Tag {
  @Column(beforeGet: read)
  String? name;

  static String? read(Map<String, dynamic> m) => null;
}
''');
      expect(out, isNot(contains('readsRowDates')));
    });

    test('a two word relation is found in the preload list', () async {
      String out = await _generate('''
@DoxModel()
class User {
  @HasMany(User)
  List<User> userInfos = <User>[];
}
''');

      /// preload() keeps the field name, the json key is snake case
      expect(out, contains("preload.contains('userInfos')"));
      expect(out, contains("map['user_infos'] = toMap(instance.userInfos);"));
    });

    test('the primary key type follows primaryKeyType', () async {
      String out = await _generate('''
@DoxModel(primaryKey: 'uuid', primaryKeyType: String)
class Device {}
''');
      expect(out, contains('String? get uuid => tempIdValue as String?;'));
      expect(out, contains('set uuid(String? val) => tempIdValue = val;'));
      expect(out, contains("..uuid = m['uuid'] as String?"));
    });

    test('the primary key is int by default', () async {
      String out = await _generate('''
@DoxModel()
class Device {}
''');
      expect(out, contains('int? get id => tempIdValue as int?;'));
    });

    test('timestamps: false leaves out created_at and updated_at', () async {
      String out = await _generate('''
@DoxModel(timestamps: false)
class Setting {}
''');
      expect(out, contains("'created_at': null"));
      expect(out, contains("'updated_at': null"));
      expect(out, isNot(contains('..createdAt')));
      expect(out, isNot(contains("'created_at' :")));
    });

    test('updatedAt: null turns off only updated_at', () async {
      String out = await _generate('''
@DoxModel(updatedAt: null)
class Log {}
''');
      expect(out, contains("'created_at': 'created_at'"));
      expect(out, contains("'updated_at': null"));
      expect(out, isNot(contains('..updatedAt')));
    });

    test('casts: the cast argument, bool and enum fields', () async {
      String out = await _generate('''
@DoxModel()
class Item {
  @Column(cast: JsonCast())
  Map<String, dynamic>? meta;

  @Column()
  bool done = false;

  @Column()
  Status? status;
}
''');
      expect(out, contains('static const _metaCast = JsonCast();'));
      expect(out, contains('static const _doneCast = BoolCast();'));
      expect(
        out,
        contains('static const _statusCast = EnumCast(Status.values);'),
      );
      expect(out, contains("..meta = _metaCast.get(m['meta'])"));
      expect(out, contains("..done = _doneCast.get(m['done']) as bool"));
      expect(out, contains("'status': _statusCast.set(instance.status)"));
    });

    test('setColumnValue sets a field by its column name', () async {
      String out = await _generate('''
@DoxModel(timestamps: false)
class Post {
  @Column()
  int? viewCount;

  @Column(name: 'title_text')
  String? title;

  @Column()
  bool done = false;

  @Column()
  List<String>? tags;

  @HasMany(Post)
  List<Post> replies = <Post>[];

  /// fields named like the parameters do not clash
  @Column()
  String? column;

  @Column()
  int? value;
}
''');
      String flat = out.replaceAll(RegExp(r'\s+'), ' ');
      expect(
        flat,
        contains(
          '@override bool setColumnValue(String column, dynamic value) { '
          'Post instance = this as Post; switch (column) {',
        ),
      );
      expect(
        flat,
        contains(
          "case 'id': if (value is! int?) return false; "
          'instance.id = value; return true;',
        ),
      );
      expect(
        flat,
        contains(
          "case 'view_count': if (value is! int?) return false; "
          'instance.viewCount = value; return true;',
        ),
      );
      expect(
        flat,
        contains(
          "case 'title_text': if (value is! String?) return false; "
          'instance.title = value; return true;',
        ),
      );
      expect(
        flat,
        contains(
          "case 'done': if (value is! bool) return false; "
          'instance.done = value; return true;',
        ),
      );
      expect(
        flat,
        contains(
          "case 'tags': if (value is! List<String>?) return false; "
          'instance.tags = value; return true;',
        ),
      );
      expect(flat, contains('instance.column = value; return true;'));
      expect(flat, contains('instance.value = value; return true;'));
      expect(flat, contains('} return false; }'));

      /// a relation is not a column
      expect(flat, isNot(contains("case 'replies'")));

      /// no timestamps, no timestamp columns
      expect(flat, isNot(contains("case 'created_at'")));
    });

    test('setColumnValue has the timestamp columns', () async {
      String out = await _generate('''
@DoxModel(createdAt: 'made_at')
class Post {}
''');
      String flat = out.replaceAll(RegExp(r'\s+'), ' ');
      expect(
        flat,
        contains(
          "case 'made_at': if (value is! DateTime?) return false; "
          'instance.createdAt = value; return true;',
        ),
      );
      expect(flat, contains("case 'updated_at':"));
    });

    test('local and global scopes', () async {
      String out = await _generate('''
@DoxModel()
class Post {
  @Scope()
  static dynamic popular(dynamic q, int views, {bool exact = false}) => q;

  @Scope(global: true)
  static dynamic visible(dynamic q) => q;
}
''');
      String flat = out.replaceAll(RegExp(r'\s+'), ' ');
      expect(flat, contains('extension PostScopes on QueryBuilder<Post>'));
      expect(
        flat,
        contains(
          'dynamic popular(int views, {bool exact = false}) => '
          'Post.popular(this, views, exact: exact);',
        ),
      );
      expect(flat, contains("const {'visible': Post.visible}"));
      expect(flat, isNot(contains('dynamic visible(')));
    });
  });
}

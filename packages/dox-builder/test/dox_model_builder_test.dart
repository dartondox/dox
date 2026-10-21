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
  const Column({this.name, this.beforeSave, this.beforeGet});
}
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
  });
}

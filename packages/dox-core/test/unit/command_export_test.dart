import 'package:dox_annotation/command.dart' as annotation;
import 'package:dox_core/command.dart';
import 'package:test/test.dart';

void main() {
  test('dox_core/command.dart gives the classes of dox_annotation', () {
    expect(Command, same(annotation.Command));
    expect(MigrationFile, same(annotation.MigrationFile));
  });
}

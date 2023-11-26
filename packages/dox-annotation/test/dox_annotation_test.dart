import 'package:dox_annotation/dox_annotation.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    final model = DoxModel(table: 'blog');

    setUp(() {
      // Additional setup goes here.
    });

    test('First Test', () {
      expect(model.table == 'blog', isTrue);
    });
  });
}

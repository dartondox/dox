import 'package:test/test.dart';

import 'blog_serializer.dart';

void main() {
  group('serializer', () {
    test('singular', () {
      var serializer = BlogSerializer(Blog());
      var map = serializer.toJson();
      expect(map['title'], 'hello');
    });

    test('singular null', () {
      var serializer = BlogSerializer(null);
      var map = serializer.toJson();
      expect(map, null);
    });

    test('list', () {
      var serializer = BlogSerializer([Blog()]);
      var map = serializer.toJson();
      expect(map[0]['title'], 'hello');
    });
  });
}

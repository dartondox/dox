import 'package:test/test.dart';

import 'blog_serializer.dart';

void main() {
  group('serializer', () {
    test('singular', () {
      BlogSerializer serializer = BlogSerializer(Blog());
      dynamic map = serializer.toJson();
      expect(map['title'], 'hello');
    });

    test('singular null', () {
      BlogSerializer serializer = BlogSerializer(null);
      dynamic map = serializer.toJson();
      expect(map, null);
    });

    test('list', () {
      BlogSerializer serializer = BlogSerializer(<Blog>[Blog()]);
      dynamic map = serializer.toJson();
      expect(map[0]['title'], 'hello');
    });
  });
}

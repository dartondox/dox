import 'package:dox_core/utils/utils.dart';
import 'package:test/test.dart';

void main() {
  group('Utils |', () {
    group('sanitizeRoutePath |', () {
      test('normal', () {
        String route = sanitizeRoutePath('admin');
        expect(route, '/admin');
      });

      test('with slash', () {
        String route = sanitizeRoutePath('/admin');
        expect(route, '/admin');
      });

      test('with double slash', () {
        String route = sanitizeRoutePath('//admin');
        expect(route, '/admin');
      });

      test('with double slash on both side', () {
        String route = sanitizeRoutePath('//admin//');
        expect(route, '/admin');
      });

      test('with single slash on both side', () {
        String route = sanitizeRoutePath('/admin/');
        expect(route, '/admin');
      });

      test('long route', () {
        String route = sanitizeRoutePath('/admin//something');
        expect(route, '/admin/something');
      });

      test('with param', () {
        String route = sanitizeRoutePath('/admin//{name}');
        expect(route, '/admin/{name}');
      });

      test('with 2 param', () {
        String route = sanitizeRoutePath('/admin//{name}//{id}');
        expect(route, '/admin/{name}/{id}');
      });
    });
  });
}

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

void main() {
  group('map extension', () {
    test('get param by dot', () {
      Map<String, dynamic> map = {
        'user': {
          'info': {'name': 'aj'},
          'hobbies': ['reading', 'driving', 'dancing']
        }
      };

      expect(map.getParam('user.info.name'), 'aj');
      expect(map.getParam('user.info'), {'name': 'aj'});
      expect(map.getParam('user.hobbies'), ['reading', 'driving', 'dancing']);
      expect(
          map.getParam('user.hobbies.foo'), ['reading', 'driving', 'dancing']);
    });

    test('remove param by dot', () {
      Map<String, dynamic> map = {
        'user': {
          'info': {'name': 'aj'},
          'foo': 'bar',
        }
      };

      var newMap = map.removeParam('user.info');
      expect(newMap, {
        'user': {'foo': 'bar'}
      });
    });
  });

  group('List join', () {
    test('join by and', () {
      List<String> list = ['active', 'pending', 'failed'];
      String result = list.joinWithAnd();
      expect(result, 'active, pending, and failed');
    });

    test('join by and single', () {
      List<String> list = ['active'];
      String result = list.joinWithAnd();
      expect(result, 'active');
    });

    test('join by or', () {
      List<String> list = ['active', 'pending', 'failed'];
      String result = list.joinWithAnd(', ', 'or');
      expect(result, 'active, pending, or failed');
    });
  });
}

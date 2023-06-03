import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

void main() {
  group('map extension', () {
    test('get param by dot', () {
      Map<String, dynamic> map = <String, dynamic>{
        'user': <String, dynamic>{
          'info': <String, dynamic>{'name': 'aj'},
          'hobbies': <String>['reading', 'driving', 'dancing']
        }
      };

      expect(map.getParam('user.info.name'), 'aj');
      expect(map.getParam('user.info'), <String, String>{'name': 'aj'});
      expect(map.getParam('user.hobbies'),
          <String>['reading', 'driving', 'dancing']);
      expect(map.getParam('user.hobbies.foo'),
          <String>['reading', 'driving', 'dancing']);
    });

    test('remove param by dot', () {
      Map<String, dynamic> map = <String, dynamic>{
        'user': <String, dynamic>{
          'info': <String, String>{'name': 'aj'},
          'foo': 'bar',
        }
      };

      Map<String, dynamic> newMap = map.removeParam('user.info');
      expect(newMap, <String, dynamic>{
        'user': <String, String>{'foo': 'bar'}
      });
    });
  });

  group('List join', () {
    test('join by and', () {
      List<String> list = <String>['active', 'pending', 'failed'];
      String result = list.joinWithAnd();
      expect(result, 'active, pending, and failed');
    });

    test('join by and single', () {
      List<String> list = <String>['active'];
      String result = list.joinWithAnd();
      expect(result, 'active');
    });

    test('join by or', () {
      List<String> list = <String>['active', 'pending', 'failed'];
      String result = list.joinWithAnd(', ', 'or');
      expect(result, 'active, pending, or failed');
    });
  });
}

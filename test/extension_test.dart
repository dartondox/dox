import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

void main() {
  group('map extension', () {
    test('get param by dot', () {
      Map<String, dynamic> map = {
        'user': {
          'info': {'name': 'aj'}
        }
      };

      expect(map.getParam('user.info.name'), 'aj');
      expect(map.getParam('user.info'), {'name': 'aj'});
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
}

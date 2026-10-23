import 'package:dox_core/storage/storage_config.dart';
import 'package:test/test.dart';

void main() {
  group('StorageDiskFactory |', () {
    StorageDiskFactory factory = const StorageDiskFactory();
    Map<String, dynamic> s3 = <String, dynamic>{
      'driver': 's3',
      'bucket': 'b',
      'key': 'k',
      'secret': 's',
    };

    test('s3 with all settings works', () {
      expect(factory.driver('s3', s3), isNotNull);
    });

    for (String key in <String>['bucket', 'key', 'secret']) {
      test('s3 without $key names the missing setting', () {
        Map<String, dynamic> options = <String, dynamic>{...s3}..remove(key);
        expect(
          () => factory.driver('files', options),
          throwsA(
            isA<ArgumentError>().having(
              (ArgumentError e) => e.message,
              'message',
              'Storage disk "files" needs the "$key" setting. '
                  'It is missing or empty.',
            ),
          ),
        );
      });
    }

    test('s3 with an empty value is missing too', () {
      Map<String, dynamic> options = <String, dynamic>{...s3, 'bucket': ''};
      expect(() => factory.driver('s3', options), throwsArgumentError);
    });
  });
}

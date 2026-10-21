import 'package:dox_storage/dox_storage.dart';
import 'package:test/test.dart';

import 'support/disk_contract.dart';

void main() {
  runDiskContract('MemoryDriver', () async {
    return Disk(MemoryDriver());
  });

  group('MemoryDriver', () {
    test('visibility is stored per file', () async {
      Disk disk = Disk(MemoryDriver(visibility: Visibility.private));
      await disk.put('a.txt', 'a');
      expect(await disk.getVisibility('a.txt'), Visibility.private);
      await disk.setVisibility('a.txt', Visibility.public);
      expect(await disk.getVisibility('a.txt'), Visibility.public);
      await disk.put(
        'b.txt',
        'b',
        options: const WriteOptions(visibility: Visibility.public),
      );
      expect(await disk.getVisibility('b.txt'), Visibility.public);
    });

    test('visibility of a missing file throws', () async {
      Disk disk = Disk(MemoryDriver());
      expect(disk.getVisibility('x'), throwsA(isA<FileNotFoundException>()));
    });

    test('urls', () async {
      Disk disk = Disk(MemoryDriver(urlBase: 'https://cdn.test/'));
      expect(await disk.getUrl('a/b.txt'), 'https://cdn.test/a/b.txt');
      expect(await disk.getSignedUrl('a.txt'), contains('signature='));
      expect(await disk.getSignedUploadUrl('a.txt'), contains('upload=1'));
    });
  });
}

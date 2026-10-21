import 'dart:io';

import 'package:dox_storage/dox_storage.dart';

Future<void> main() async {
  Directory root = await Directory.systemTemp.createTemp('dox_storage_example');

  DriveManager drive = DriveManager(
    defaultDisk: 'local',
    disks: <String, DriverContract>{
      'local': LocalDriver(
        LocalDriverConfig(
          root: root.path,
          urlBase: 'https://app.test/uploads',
          appKey: 'change-me',
        ),
      ),
      // 's3': S3Driver(S3DriverConfig(
      //   bucket: 'my-bucket',
      //   region: 'us-east-1',
      //   accessKeyId: Platform.environment['AWS_ACCESS_KEY_ID']!,
      //   secretAccessKey: Platform.environment['AWS_SECRET_ACCESS_KEY']!,
      // )),
    },
  );

  Disk disk = drive.use();
  await disk.put('avatars/1.txt', 'hello');
  print(await disk.getString('avatars/1.txt'));
  print(await disk.getMetaData('avatars/1.txt'));
  print(await disk.getUrl('avatars/1.txt'));
  print(await disk.getSignedUrl('avatars/1.txt'));

  ListResult list = await disk.listAll('avatars');
  print(list.objects);

  await disk.deleteAll('avatars');
  await root.delete(recursive: true);
}

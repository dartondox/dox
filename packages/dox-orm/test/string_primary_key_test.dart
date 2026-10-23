import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

import 'connection.dart';
import 'models/device/device.model.dart';

void main() async {
  await initQueryBuilder();

  group('String primary key |', () {
    setUp(() async {
      await Schema().create('device', (Table table) {
        table.string('uuid', 36).primary();
        table.string('name');
        table.timestamps();
      });
    });

    tearDown(() async {
      await Schema().dropIfExists('device');
    });

    test('save, find, update and delete with a UUID key', () async {
      Device device = Device();
      device.uuid = '0b6f2c1e-1a2b-4c3d-8e9f-001122334455';
      device.name = 'phone';
      expect(device.exists, false);

      /// the key is set, but the row is new, so save() inserts it
      await device.save();
      expect(device.exists, true);

      Device? found = await Device().find(device.uuid);
      String? uuid = found?.uuid;
      expect(uuid, '0b6f2c1e-1a2b-4c3d-8e9f-001122334455');
      expect(found?.exists, true);

      found?.name = 'tablet';
      await found?.save();
      expect(await Device().count(), 1);
      Device? updated = await Device().find(device.uuid);
      expect(updated?.name, 'tablet');

      await updated?.delete();
      expect(await Device().count(), 0);
    });
  });
}

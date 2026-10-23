import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

import 'connection.dart';
import 'models/setting/setting.model.dart';

void main() async {
  await initQueryBuilder();

  group('Timestamps off |', () {
    setUp(() async {
      /// no created_at and updated_at columns
      await Schema().create('setting', (Table table) {
        table.id();
        table.string('name');
      });
    });

    tearDown(() async {
      await Schema().dropIfExists('setting');
    });

    test('save and update a model without timestamps', () async {
      Setting setting = Setting();
      setting.name = 'theme';
      await setting.save();

      setting.name = 'language';
      await setting.save();

      Setting? found = await Setting().find(setting.id);
      expect(found?.name, 'language');
      expect(found?.toJson().containsKey('created_at'), false);
      expect(found?.toJson().containsKey('updated_at'), false);

      Setting created = await Setting().create(<String, dynamic>{'name': 'x'});
      expect(created.name, 'x');
    });
  });
}

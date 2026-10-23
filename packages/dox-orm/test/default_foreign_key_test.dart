import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

import 'connection.dart';
import 'models/owner/owner.model.dart';

void main() async {
  await initQueryBuilder();

  group('Default foreign keys |', () {
    setUp(() async {
      await Schema().create('owners', (Table table) {
        table.id();
        table.string('name');
      });
      await Schema().create('pets', (Table table) {
        table.id();
        table.string('name');
        table.integer('owner_id');
      });
      await Schema().create('clubs', (Table table) {
        table.id();
        table.string('name');
      });
      await Schema().create('club_owner', (Table table) {
        table.id();
        table.integer('owner_id');
        table.integer('club_id');
      });
    });

    tearDown(() async {
      await Schema().dropIfExists('owners');
      await Schema().dropIfExists('pets');
      await Schema().dropIfExists('clubs');
      await Schema().dropIfExists('club_owner');
    });

    test('keys use the model name, not the table name', () async {
      expect(Owner().foreignKeyName, 'owner_id');

      Owner owner = await Owner().create(<String, dynamic>{'name': 'Ann'});
      await Pet().create(<String, dynamic>{
        'name': 'Rex',
        'owner_id': owner.id,
      });
      Club club = await Club().create(<String, dynamic>{'name': 'Dogs'});
      await QueryBuilder.table('club_owner')
          .insert(<String, dynamic>{'owner_id': owner.id, 'club_id': club.id});

      Owner? found = await Owner()
          .preload('pets')
          .preload('firstPet')
          .preload('clubs')
          .find(owner.id);
      expect(found?.pets.length, 1);
      expect(found?.firstPet?.name, 'Rex');
      expect(found?.clubs.first.name, 'Dogs');

      Pet? pet = await Pet().preload('owner').find(1);
      expect(pet?.owner?.name, 'Ann');
    });
  });
}

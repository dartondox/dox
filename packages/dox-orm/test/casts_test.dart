import 'dart:convert';

import 'package:dox_orm/dox_orm.dart';
import 'package:test/test.dart';

import 'connection.dart';
import 'models/cast_item/cast_item.model.dart';

void main() async {
  await initQueryBuilder();

  group('Casts |', () {
    setUp(() async {
      await Schema().dropIfExists('cast_item');

      /// json is in text columns, so every database gives the raw text
      /// and the cast decodes it
      await Schema().create('cast_item', (Table table) {
        table.id();
        table.text('meta').nullable();
        table.text('tags').nullable();
        table.boolean('active').nullable();
        table.boolean('done').withDefault(false);
        table.string('status').nullable();
        table.integer('level').nullable();
        table.integer('price').nullable();
      });
    });

    tearDown(() async {
      await Schema().dropIfExists('cast_item');
    });

    test('save and read back', () async {
      CastItem item = CastItem()
        ..meta = <String, dynamic>{'a': 1, 'b': 'x'}
        ..tags = <String>['red', 'blue']
        ..active = true
        ..done = true
        ..status = Status.live
        ..level = Level.high
        ..price = Money(1250);
      await item.save();

      Map<String, dynamic>? row = await QueryBuilder.table('cast_item')
          .find(item.id);
      expect(row?['status'], 'live');
      expect(row?['level'], 2);
      expect(row?['price'], 1250);

      CastItem? found = await CastItem().find(item.id);
      expect(found?.meta, <String, dynamic>{'a': 1, 'b': 'x'});
      expect(found?.tags, <String>['red', 'blue']);
      expect(found?.tags, isA<List<String>>());
      expect(found?.active, true);
      expect(found?.done, true);
      expect(found?.status, Status.live);
      expect(found?.level, Level.high);
      expect(found?.price?.cents, 1250);
    });

    test('nulls', () async {
      CastItem item = CastItem();
      await item.save();
      CastItem? found = await CastItem().find(item.id);
      expect(found?.meta, isNull);
      expect(found?.tags, isNull);
      expect(found?.active, isNull);
      expect(found?.done, false);
      expect(found?.status, isNull);
      expect(found?.level, isNull);
      expect(found?.price, isNull);
    });

    test('toJson uses the cast', () async {
      CastItem item = CastItem()
        ..status = Status.draft
        ..level = Level.mid
        ..price = Money(5)
        ..tags = <String>['a'];
      Map<String, dynamic> json = item.toJson();
      expect(json['status'], 'draft');
      expect(json['level'], 1);
      expect(json['price'], 5);
      expect(jsonEncode(json), contains('"tags":["a"]'));
    });

    test('BoolCast reads numbers and text', () {
      expect(const BoolCast().get(1), true);
      expect(const BoolCast().get(0), false);
      expect(const BoolCast().get('t'), true);
      expect(const BoolCast().get('false'), false);
      expect(const BoolCast().get(true), true);
    });
  });
}

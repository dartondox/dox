import 'dart:convert';
import 'dart:math';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/json.dart' show advanceEncode;
import 'package:test/test.dart';

import '../dtos/dtos.dart';
import '../dtos/nested.dto.dart';
import '../dtos/response.dto.dart';
import '../dtos/rules.dto.dart';
import '../utils/test_app_key.dart';

String _bytes(Object? value) => utf8.decode(JSON.bytes(value));

/// The JSON of a DTO in a response must be the JSON of the map that its
/// schema makes with toMap().
void _same<T extends Object>(DtoSchema<T> schema, T dto) {
  String want = jsonEncode(schema.toMap(dto), toEncodable: advanceEncode);
  expect(_bytes(dto), want);
  expect(JSON.stringify(dto), want);
}

void main() {
  group('a DTO as JSON |', () {
    setUp(() {
      Dox().initialize(AppConfig(appKey: testAppKey, dtos: testDtos));
    });

    test('the generated schema writes the object', () {
      expect($ProductViewDto, isA<JsonObjectWriter>());
      ProductView product = ProductView(
        id: 7,
        productName: 'A "book" é 😀',
        price: 12.5,
        inStock: true,
        soldAt: DateTime.utc(2024, 5, 17, 3, 4, 5, 6),
      );
      expect(
        _bytes(product),
        '{"id":7,"product_name":"A \\"book\\" é 😀","price":12.5,'
        '"in_stock":true,"sold_at":"2024-05-17T03:04:05.006Z"}',
      );
      _same($ProductViewDto, product);
      _same(
        $ProductViewDto,
        const ProductView(id: -1, productName: '', price: 0, inStock: false),
      );
    });

    test('in a list and in a map', () {
      List<ProductView> products = <ProductView>[
        for (int i = 0; i < 50; i++)
          ProductView(
            id: i,
            productName: 'product $i',
            price: i / 4,
            inStock: i.isEven,
          ),
      ];
      String list = jsonEncode(<Map<String, dynamic>>[
        for (ProductView p in products) $ProductViewDto.toMap(p),
      ]);
      expect(_bytes(products), list);
      expect(JSON.stringify(products), list);
      expect(
        _bytes(<String, dynamic>{'data': products, 'count': 50}),
        '{"data":$list,"count":50}',
      );
    });

    test('nested DTOs', () {
      CreateOrder order = const CreateOrder(
        address: Address(city: 'Bangkok', postCode: '10110'),
        items: <OrderItem>[
          OrderItem(name: 'a', quantity: 1),
          OrderItem(name: 'b', quantity: 2),
        ],
      );
      expect(
        _bytes(order),
        '{"address":{"city":"Bangkok","post_code":"10110"},'
        '"items":[{"name":"a","quantity":1},{"name":"b","quantity":2}],'
        '"billing":null}',
      );
      _same($CreateOrderDto, order);
      _same(
        $CreateOrderDto,
        const CreateOrder(
          address: Address(city: 'a', postCode: '1'),
          items: <OrderItem>[],
          billing: Address(city: 'b', postCode: '2'),
        ),
      );
    });

    test('every type, with a value and with null', () {
      _same($AllTypesDto, const AllTypes());
      AllTypes all = AllTypes(
        s: 'text',
        i: 3,
        d: 1.5,
        n: 2,
        b: true,
        dt: DateTime(2024, 1, 2, 3, 4, 5, 6, 7),
        role: Role.admin,
        list: const <int>[1, 2],
        map: const <String, int>{'a': 1},
        any: const <String, dynamic>{
          'x': <int>[1],
        },
        raw: const <String, dynamic>{'k': 'v', 'n': null},
      );
      _same($AllTypesDto, all);
      expect(_bytes(all), contains('"role":"admin"'));
    });

    test('a Maybe field: there, null and missing', () {
      _same($UpdateUserDto, const UpdateUser());
      expect(_bytes(const UpdateUser()), '{}');
      UpdateUser both = const UpdateUser(
        bio: Maybe<String?>('hi'),
        age: Maybe<int>(3),
      );
      _same($UpdateUserDto, both);
      expect(_bytes(both), '{"bio":"hi","age":3}');
      UpdateUser empty = const UpdateUser(bio: Maybe<String?>(null));
      _same($UpdateUserDto, empty);
      expect(_bytes(empty), '{"bio":null}');
    });

    test('the keys of keyCase', () {
      _same($CamelKeysDto, const CamelKeys(firstName: 'a'));
      expect(_bytes(const CamelKeys(firstName: 'a')), '{"firstName":"a"}');
    });

    test('a subclass in a DTO field: only the declared fields', () {
      ProductView secret = const SecretProductView(
        id: 1,
        productName: 'p',
        price: 1,
        inStock: true,
        secret: 'hidden',
      );
      MixedView mixed = MixedView(
        dates: const <DateTime>[],
        roles: const <Role>[],
        days: const <String, DateTime>{},
        grid: const <List<Role>>[],
        own: const OwnJson(id: 1),
        owns: const <OwnJson>[],
        product: secret,
        products: <ProductView>[secret],
        byName: <String, ProductView>{'p': secret},
      );
      _same($MixedViewDto, mixed);
      expect(_bytes(mixed), isNot(contains('secret')));
      // on its own, it is written with all of its fields
      expect(_bytes(secret), contains('"secret":"hidden"'));
    });

    test('dates and enums in lists and maps, and DTOs in a map', () {
      ProductView product = const ProductView(
        id: 1,
        productName: 'p',
        price: 1,
        inStock: true,
      );
      MixedView mixed = MixedView(
        dates: <DateTime>[DateTime.utc(2024), DateTime(2025, 2, 3)],
        roles: const <Role>[Role.admin, Role.user],
        days: <String, DateTime>{'a': DateTime.utc(2024, 2, 2)},
        grid: const <List<Role>>[
          <Role>[Role.user],
          <Role>[],
        ],
        own: const OwnJson(id: 1),
        owns: const <OwnJson>[OwnJson(id: 2), OwnJson(id: 3)],
        product: product,
        products: <ProductView>[product, product],
        byName: <String, ProductView>{'p': product},
      );
      _same($MixedViewDto, mixed);
      String text = _bytes(mixed);
      expect(text, contains('"roles":["admin","user"]'));
      expect(text, contains('"dates":["2024-01-01T00:00:00.000Z",'));

      /// inside another DTO, a DTO is written by its schema
      expect(text, contains('"own":{"id":1}'));
      expect(text, contains('"by_name":{"p":{"id":1,'));
    });

    test('a DTO with its own toJson() keeps it', () {
      expect($OwnJsonDto, isNot(isA<JsonObjectWriter>()));
      expect(_bytes(const OwnJson(id: 4)), '{"my_id":4}');
      expect(JSON.stringify(const OwnJson(id: 4)), '{"my_id":4}');
    });

    test('a DTO that is not in AppConfig(dtos:) is an error', () {
      Dox().initialize(AppConfig(appKey: testAppKey));
      const ProductView product = ProductView(
        id: 1,
        productName: 'p',
        price: 1,
        inStock: true,
      );
      expect(
        () => JSON.bytes(product),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
      expect(
        () => JSON.stringify(product),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
    });

    test('random DTOs', () {
      Random random = Random(3);
      const List<String> texts = <String>[
        '',
        'plain',
        'a "quote" \\ and \n',
        'မြန်မာစာ 😀',
        'a text that is longer than thirty two characters in total',
      ];
      T? maybe<T>(T value) => random.nextBool() ? value : null;
      for (int i = 0; i < 2000; i++) {
        AllTypes all = AllTypes(
          s: maybe(texts[random.nextInt(texts.length)]),
          i: maybe(random.nextInt(1 << 32) - (1 << 31)),
          d: maybe(random.nextInt(100000) / 100),
          n: maybe(random.nextInt(50)),
          b: maybe(random.nextBool()),
          dt: maybe(
            DateTime.fromMicrosecondsSinceEpoch(
              random.nextInt(1 << 32) * 1000 + random.nextInt(2) * 7,
              isUtc: random.nextBool(),
            ),
          ),
          role: maybe(Role.values[random.nextInt(2)]),
          list: maybe(<int>[for (int k = random.nextInt(4); k > 0; k--) k]),
          map: maybe(<String, int>{'a': i}),
          any: maybe(texts[random.nextInt(texts.length)]),
          raw: maybe(<String, dynamic>{
            'k': <int>[i],
          }),
        );
        _same($AllTypesDto, all);
      }
    });

    /// RunsView has no Maybe field: its fixed parts are runs, and its
    /// lists and its nested DTO are written with direct calls.
    test('random DTOs that are written with runs', () {
      Random random = Random(5);
      const List<String> texts = <String>[
        '',
        'plain',
        'a "quote" \\ and \n \u0001',
        'မြန်မာစာ 😀',
        'a text that is longer than thirty two characters in total',
      ];
      String text() => texts[random.nextInt(texts.length)];
      int number() => switch (random.nextInt(6)) {
        0 => -9223372036854775807 - 1,
        1 => 9223372036854775807,
        2 => random.nextInt(100) - 50,
        3 => -random.nextInt(1 << 32),
        _ => random.nextInt(1 << 32) * random.nextInt(1 << 20),
      };
      ProductView product() => ProductView(
        id: number(),
        productName: text(),
        price: random.nextInt(10000) / 100,
        inStock: random.nextBool(),
        soldAt: random.nextBool() ? null : DateTime.utc(2024, 1, 2),
      );
      for (int i = 0; i < 2000; i++) {
        RunsView view = RunsView(
          id: number(),
          tags: <String>[for (int k = random.nextInt(4); k > 0; k--) text()],
          notes: <String?>[
            for (int k = random.nextInt(4); k > 0; k--)
              random.nextBool() ? null : text(),
          ],
          numbers: <int>[for (int k = random.nextInt(5); k > 0; k--) number()],
          flags: <bool>[
            for (int k = random.nextInt(3); k > 0; k--) random.nextBool(),
          ],
          main: product(),
          products: <ProductView>[
            for (int k = random.nextInt(4); k > 0; k--) product(),
          ],
          odd: text(),
          active: random.nextBool(),
        );
        _same($RunsViewDto, view);
      }
      expect(
        _bytes(
          RunsView(
            id: 1,
            tags: <String>['a', 'b'],
            notes: <String?>[null],
            numbers: <int>[],
            flags: <bool>[true],
            main: const ProductView(
              id: 2,
              productName: 'p',
              price: 1,
              inStock: false,
            ),
            products: <ProductView>[],
            odd: 'o',
            active: true,
          ),
        ),
        '{"id":1,"tags":["a","b"],"notes":[null],"numbers":[],'
        '"flags":[true],"main":{"id":2,"product_name":"p","price":1.0,'
        '"in_stock":false,"sold_at":null},"products":[],'
        r'"a \"key\" é \\ $x":"o","active":true}',
      );
    });
  });
}

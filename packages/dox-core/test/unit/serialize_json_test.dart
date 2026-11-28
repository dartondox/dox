import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/json.dart' show advanceEncode, useSdkJsonEncoder;
import 'package:test/test.dart';

import '../serialize/nopart.dart';
import '../serialize/serialize.dart';
import '../utils/test_app_key.dart';

String _bytes(Object? value) => utf8.decode(JSON.bytes(value));

/// [value] gives [want] with the Dox encoder, with the encoder of the
/// SDK (`CoreFlags.sdkJsonEncoder`) and with `JSON.stringify()`.
void _same(Object? value, String want) {
  expect(_bytes(value), want);
  expect(JSON.stringify(value), want);
  useSdkJsonEncoder = true;
  try {
    expect(_bytes(value), want);
  } finally {
    useSdkJsonEncoder = false;
  }
}

/// The JSON of the map of `toJson()`, as before `@Serialize()`.
String _mapJson(Serializer<Object?> serializer) {
  return jsonEncode(serializer.toJson(), toEncodable: advanceEncode);
}

User _user({int id = 1, Post? lastPost, Account? account, String? nick}) {
  return User(
    id: id,
    name: 'Mg "Mg" é 😀',
    nick: nick,
    createdAt: DateTime.utc(2024, 5, 17, 3, 4, 5, 6),
    score: 11,
    posts: <Post>[
      Post('one', <Tag>[Tag('a'), Tag(null)]),
      Post('two', <Tag>[]),
    ],
    lastPost: lastPost,
    account: account,
  );
}

void main() {
  setUp(() {
    Dox().initialize(
      AppConfig(appKey: testAppKey, container: registerSerializeWriters),
    );
  });

  group('@Serialize() serializer |', () {
    test('one item: the same JSON as the map of toJson()', () {
      UserInfo info = UserInfo(
        _user(account: Account(3, null), lastPost: Post('last', <Tag>[])),
        now: DateTime.utc(2024, 5, 18),
      );
      expect(Dox().ioc.jsonWriterOf(UserInfo), $UserInfoWriter);
      String want = _mapJson(info);
      expect(
        want,
        '{"data":{"id":3,"email":null},"extra":{"login_count":11,'
        '"seen":"2024-05-17T03:04:05.006Z","roles":["user"],"level":"basic",'
        '"levels":[],"home":{"city":"Yangon","zip_code":null},"work":null,'
        '"others":[],"counts":{},"meta":{},"ratio":0.5,"account":null},'
        '"active":true,"label":"top","name":"#Mg \\"Mg\\" é 😀",'
        '"nick":"Mg \\"Mg\\" é 😀","tags":["a",null],"rating":{"score":11,'
        '"count":2,"deep":{"half":5.5,"at":"2024-05-17T03:04:05.006Z"}},'
        '"posts":[{"title":"one","tags":["a",null],"labels":[{"tag":"a"},'
        '{"tag":null}]},{"title":"two","tags":[],"labels":[]}],'
        '"last":{"title":"last","tags":[],"labels":[]},'
        '"first":{"title":"one","tags":["a",null],"labels":[{"tag":"a"},'
        '{"tag":null}]},"id":1}',
      );
      _same(info, want);
    });

    test('nullable values that are null', () {
      UserInfo info = UserInfo(_user(nick: 'nick'), now: DateTime.utc(2030));
      String want = _mapJson(info);
      expect(want, contains('"data":null'));
      expect(want, contains('"last":null'));
      expect(want, contains('"nick":"nick"'));
      expect(want, contains('"active":false'));
      _same(info, want);
    });

    test('a list gives an array, null data gives null', () {
      UserInfo list = UserInfo(<User>[_user(), _user(id: 2)]);
      String want = _mapJson(list);
      expect(want, startsWith('[{"data":null'));
      expect(want, contains('"id":2}]'));
      _same(list, want);
      _same(UserInfo(null), 'null');
      _same(UserInfo(<User>[]), '[]');
      _same(PostSerializer(null), 'null');
    });

    test('in a map, in a list, and a serializer that uses a member', () {
      Post post = Post('p', <Tag>[Tag('x')]);
      Map<String, dynamic> body = <String, dynamic>{
        'post': PostSerializer(post),
        'labels': <Object>[LabelOnly(Tag('y'), '!'), TagLabel(Tag('z'))],
      };
      String want =
          '{"post":{"title":"p","tags":["x"],"labels":[{"tag":"x"}]},'
          '"labels":[{"label":"!y"},{"tag":"z"}]}';
      _same(body, want);
      expect(jsonEncode(body, toEncodable: advanceEncode), want);
    });

    test('a serializer at the top is found in the container', () {
      TagLabel label = TagLabel(<Tag>[Tag('a')]);
      expect(Dox().ioc.jsonWriterOf(TagLabel), $TagLabelWriter);
      _same(label, '[{"tag":"a"}]');
    });

    test('the template of make:serializer writes {}', () {
      EmptySerializer empty = EmptySerializer(Post('p', <Tag>[]));
      _same(empty, '{}');
      _same(EmptySerializer(<Post>[Post('p', <Tag>[])]), '[{}]');
    });

    test('a serializer with no @Serialize() is not changed', () {
      expect(_SimpleSerializer(Tag('t')), isNot(isA<JsonWritable>()));
      _same(_SimpleSerializer(Tag('t')), '{"t":"t"}');
    });
  });

  group('@Serialize() shapes that keep toJson() |', () {
    String part = File('test/serialize/serialize.g.dart').readAsStringSync();
    Post post = Post('title', <Tag>[Tag('a'), Tag('b')]);
    Map<String, Serializer<Post>> shapes = <String, Serializer<Post>>{
      'WithIf': WithIf(post),
      'WithFor': WithFor(post),
      'WithSpread': WithSpread(post),
      'WithKey': WithKey(post),
      'WithIfStatement': WithIfStatement(post),
      'WithMapVariable': WithMapVariable(post),
    };
    for (MapEntry<String, Serializer<Post>> shape in shapes.entries) {
      test(shape.key, () {
        expect(part, contains('// ${shape.key}: no JSON writer'));
        expect(part, isNot(contains('\$write${shape.key}(')));
        _same(shape.value, _mapJson(shape.value));
      });
    }

    test('a plain class with its own toJson()', () {
      expect(part, contains('// OwnJson: no JSON writer'));
      _same(const OwnJson(4), '{"my_id":4}');
    });
  });

  group('@Serialize() plain class |', () {
    test('the fields with snake_case keys and @Name', () {
      ExtraUserData data = ExtraUserData(
        loginCount: 2,
        lastSeen: DateTime.utc(2024, 1, 2, 3, 4, 5, 6, 7),
        roles: <String>['a', 'b'],
        level: Level.pro,
        levels: <Level>[Level.basic, Level.pro],
        work: const Address(city: 'Mandalay', zipCode: '05'),
        others: const <Address>[Address(city: 'Bago')],
        counts: <String, int>{'x': 1},
        meta: <String, dynamic>{
          'at': DateTime.utc(2024),
          'list': <int>[1],
        },
        ratio: 1.0,
        account: Account(9, 'a@b.c'),
      );
      String want =
          '{"login_count":2,"seen":"2024-01-02T03:04:05.006007Z",'
          '"roles":["a","b"],"level":"pro","levels":["basic","pro"],'
          '"home":{"city":"Yangon","zip_code":null},'
          '"work":{"city":"Mandalay","zip_code":"05"},'
          '"others":[{"city":"Bago","zip_code":null}],"counts":{"x":1},'
          '"meta":{"at":"2024-01-01T00:00:00.000Z","list":[1]},"ratio":1.0,'
          '"account":{"id":9,"email":"a@b.c"}}';
      _same(data, want);
      expect(
        jsonEncode($ExtraUserDataToMap(data), toEncodable: advanceEncode),
        want,
      );
    });

    test('in a list and a map', () {
      List<Address> list = const <Address>[
        Address(city: 'a'),
        Address(city: 'b', zipCode: 'z'),
      ];
      _same(<String, dynamic>{
        'list': list,
      }, '{"list":[{"city":"a","zip_code":null},{"city":"b","zip_code":"z"}]}');
    });

    test('a writer added after an encode is used', () {
      Dox().ioc.clear();
      expect(
        () => JSON.bytes(const Address(city: 'a')),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
      Dox().ioc.jsonWriter($AddressWriter);
      _same(const Address(city: 'a'), '{"city":"a","zip_code":null}');
    });

    test('with no writer in the container it is an error', () {
      Dox().ioc.clear();
      expect(
        () => JSON.bytes(const Address(city: 'a')),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
    });
  });

  group('@Serialize() review cases |', () {
    Tag tag = Tag('t');

    test('a subclass with no @Serialize() writes its own map', () {
      expect(_mapJson(ChildS(tag)), '{"child":"t"}');
      _same(ChildS(tag), '{"child":"t"}');
      _same(ChildS(<Tag>[tag]), '[{"child":"t"}]');
      _same(ParentS(tag), '{"parent":"t"}');
    });

    test('a @Serialize() subclass with no writer writes its own map', () {
      expect(_mapJson(ChildIfS(tag)), '{"child_if":"t"}');
      _same(ChildIfS(tag), '{"child_if":"t"}');
    });

    test('a @Serialize() subclass gets its own writer', () {
      _same(ChildFastS(tag), '{"fast":"t"}');
    });

    test('a class between that changes the data: the object is made', () {
      expect(_mapJson(TagNames(null)), '[]');
      _same(TagNames(null), '[]');
      Post post = Post('p', <Tag>[]);
      String want = _mapJson(PostTags(post));
      expect(want, '{"tags":[],"author":{"name":"a"}}');
      _same(PostTags(post), want);
    });

    test('classes of a file with no part go to the encoder', () {
      BoxSer box = BoxSer(Item('i'));
      String want = _mapJson(box);
      expect(want, '{"item":{"n":"i"},"items":[{"n":"i"}],"p":{"p":{"id":1}}}');
      _same(box, want);
    });

    test('a subclass of a plain class is written by its own class', () {
      Post post = Post('special', <Tag>[tag]);
      String want = _mapJson(PostTags(post));
      expect(want, '{"tags":{"n":"t"},"author":{"name":"b","badge":"gold"}}');
      _same(PostTags(post), want);
    });
  });
}

class _SimpleSerializer extends Serializer<Tag> {
  _SimpleSerializer(super.data);

  @override
  Map<String, dynamic> convert(Tag m) => <String, dynamic>{'t': m.name};
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:dox_socketio/dox_socketio.dart';
import 'package:test/test.dart';

/// What `@socket.io/redis-emitter` publishes (notepack.io bytes) for
/// `emitter.to('r1').except('x').emit('news', {a: 1, bin: Buffer[1,2,3]},
/// 1.5, -5, 300, null, true, 'ü')`.
const String emitterFixture =
    '93a7656d697474657283a47479706502a46461746198a46e65777382a16101a36269'
    '6ec403010203cb3ff8000000000000fbcd012cc0c3a2c3bca36e7370a12f83a57'
    '26f6f6d7391a27231a5666c61677380a665786365707491a178';

Uint8List hex(String text) => Uint8List.fromList(<int>[
  for (int i = 0; i < text.length; i += 2)
    int.parse(text.substring(i, i + 2), radix: 16),
]);

Object fixtureValue() {
  return <Object>[
    'emitter',
    <String, Object>{
      'type': 2,
      'data': <Object?>[
        'news',
        <String, Object>{
          'a': 1,
          'bin': Uint8List.fromList(<int>[1, 2, 3]),
        },
        1.5,
        -5,
        300,
        null,
        true,
        'ü',
      ],
      'nsp': '/',
    },
    <String, Object>{
      'rooms': <String>['r1'],
      'flags': <String, Object>{},
      'except': <String>['x'],
    },
  ];
}

void main() {
  test('decodes the bytes of notepack.io', () {
    expect(MsgPack.decode(hex(emitterFixture)), fixtureValue());
  });

  test('encodes the same bytes as notepack.io', () {
    expect(MsgPack.encode(fixtureValue()), hex(emitterFixture));
  });

  test('round trip of all types', () {
    Object value = <Object?>[
      null,
      true,
      false,
      0,
      127,
      128,
      255,
      256,
      65535,
      65536,
      4294967295,
      4294967296,
      -1,
      -32,
      -33,
      -128,
      -129,
      -32768,
      -32769,
      -2147483648,
      -2147483649,
      0.1,
      -2.5,
      '',
      'a' * 31,
      'b' * 32,
      'c' * 300,
      'd' * 70000,
      'héllo 日本',
      Uint8List(0),
      Uint8List.fromList(List<int>.filled(300, 7)),
      Uint8List.fromList(List<int>.filled(70000, 9)),
      List<int>.filled(20, 1),
      <String, Object?>{for (int i = 0; i < 20; i++) 'k$i': i},
      <String, Object?>{
        'nested': <Object?>[
          <String, Object?>{'x': null},
        ],
      },
      DateTime.fromMillisecondsSinceEpoch(1700000000123, isUtc: true),
      DateTime.fromMillisecondsSinceEpoch(-1500, isUtc: true),
    ];
    expect(MsgPack.decode(MsgPack.encode(value)), value);
  });

  test('timestamp is the same as notepack.io', () {
    DateTime time = DateTime.fromMillisecondsSinceEpoch(
      1700000000123,
      isUtc: true,
    );
    expect(MsgPack.encode(time), hex('d7ff1d5353006553f100'));
    expect(MsgPack.decode(hex('d7ff1d5353006553f100')), time);
  });

  test('a cut message is a FormatException', () {
    Uint8List bytes = MsgPack.encode(<String>['hello']);
    expect(
      () => MsgPack.decode(Uint8List.sublistView(bytes, 0, 3)),
      throwsFormatException,
    );
  });

  test('RedisFormat reads JSON and msgpack', () {
    Uint8List json = RedisFormat.json.encode(<Object>[
      'uid',
      Uint8List.fromList(<int>[1, 2]),
    ]);
    expect(utf8.decode(json), '["uid",{"type":"Buffer","data":[1,2]}]');
    expect(RedisFormat.decode(json), <Object>[
      'uid',
      Uint8List.fromList(<int>[1, 2]),
    ]);
    expect(RedisFormat.decode(hex(emitterFixture)), fixtureValue());
  });
}

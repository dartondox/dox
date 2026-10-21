import 'dart:typed_data';

import 'package:dox_socketio/dox_socketio.dart';
import 'package:test/test.dart';

void main() {
  group('EngineParser', () {
    EngineParser parser = const EngineParser();

    test('encodes text packets', () {
      expect(
        parser.encodeForWebsocket(EnginePacket(EnginePacketType.message, 'hi')),
        '4hi',
      );
      expect(parser.encodeForPolling(EnginePacket(EnginePacketType.ping)), '2');
    });

    test('encodes binary for websocket and polling', () {
      Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3]);
      EnginePacket packet = EnginePacket(EnginePacketType.message, bytes);
      expect(parser.encodeForWebsocket(packet), bytes);
      expect(parser.encodeForPolling(packet), 'bAQID');
    });

    test('encodes and decodes a polling payload', () {
      String payload = parser.encodePayload(<EnginePacket>[
        EnginePacket(EnginePacketType.message, 'hello'),
        EnginePacket(
          EnginePacketType.message,
          Uint8List.fromList(<int>[1, 2, 3, 4]),
        ),
        EnginePacket(EnginePacketType.pong),
      ]);
      expect(payload, '4hello\x1ebAQIDBA==\x1e3');
      List<EnginePacket> packets = parser.decodePayload(payload);
      expect(packets.map((EnginePacket p) => p.type), <EnginePacketType>[
        EnginePacketType.message,
        EnginePacketType.message,
        EnginePacketType.pong,
      ]);
      expect(packets[0].data, 'hello');
      expect(packets[1].data, <int>[1, 2, 3, 4]);
    });

    test('decodes probe and binary frames', () {
      EnginePacket probe = parser.decodeFrame('2probe');
      expect(probe.type, EnginePacketType.ping);
      expect(probe.data, 'probe');
      EnginePacket binary = parser.decodeFrame(<int>[5, 6]);
      expect(binary.type, EnginePacketType.message);
      expect(binary.isBinary, isTrue);
    });

    test('throws on bad packets', () {
      expect(() => parser.decodeText(''), throwsFormatException);
      expect(() => parser.decodeText('9x'), throwsFormatException);
      expect(() => parser.decodeText('bnot base64!'), throwsFormatException);
    });
  });

  group('SocketEncoder', () {
    SocketEncoder encoder = const SocketEncoder();

    test('encodes connect, event, ack in the default namespace', () {
      expect(
        encoder.encode(
          SocketPacket(
            type: SocketPacketType.connect,
            data: <String, String>{'sid': 'abc'},
          ),
        ),
        <Object>['0{"sid":"abc"}'],
      );
      expect(
        encoder.encode(
          SocketPacket(
            type: SocketPacketType.event,
            data: <Object>['chat', 'hi'],
            id: 12,
          ),
        ),
        <Object>['212["chat","hi"]'],
      );
      expect(
        encoder.encode(
          SocketPacket(type: SocketPacketType.ack, id: 3, data: <Object>[1]),
        ),
        <Object>['33[1]'],
      );
    });

    test('adds a custom namespace', () {
      expect(
        encoder.encode(
          SocketPacket(type: SocketPacketType.disconnect, nsp: '/admin'),
        ),
        <Object>['1/admin,'],
      );
      expect(
        encoder.encode(
          SocketPacket(
            type: SocketPacketType.event,
            nsp: '/admin',
            id: 1,
            data: <Object>['x'],
          ),
        ),
        <Object>['2/admin,1["x"]'],
      );
    });

    test('turns binary data into attachments', () {
      Uint8List a = Uint8List.fromList(<int>[1]);
      Uint8List b = Uint8List.fromList(<int>[2]);
      List<Object> parts = encoder.encode(
        SocketPacket(
          type: SocketPacketType.event,
          nsp: '/files',
          data: <Object>[
            'upload',
            <String, Object>{
              'a': a,
              'list': <Object>[b, 'text'],
            },
          ],
        ),
      );
      expect(
        parts.first,
        '52-/files,["upload",{"a":{"_placeholder":true,"num":0},'
        '"list":[{"_placeholder":true,"num":1},"text"]}]',
      );
      expect(parts.sublist(1), <Object>[a, b]);
    });

    test('binary ack', () {
      List<Object> parts = encoder.encode(
        SocketPacket(
          type: SocketPacketType.ack,
          id: 7,
          data: <Object>[
            Uint8List.fromList(<int>[9]),
          ],
        ),
      );
      expect(parts.first, '61-7[{"_placeholder":true,"num":0}]');
    });
  });

  group('SocketDecoder', () {
    test('decodes connect with auth and namespace', () {
      SocketPacket packet = SocketDecoder().add('0/admin,{"token":"x"}')!;
      expect(packet.type, SocketPacketType.connect);
      expect(packet.nsp, '/admin');
      expect(packet.data, <String, Object>{'token': 'x'});
    });

    test('decodes connect without payload', () {
      SocketPacket packet = SocketDecoder().add('0')!;
      expect(packet.nsp, '/');
      expect(packet.data, isNull);
    });

    test('decodes events with ack ids', () {
      SocketPacket packet = SocketDecoder().add('2/chat,42["msg",{"a":1}]')!;
      expect(packet.isEvent, isTrue);
      expect(packet.nsp, '/chat');
      expect(packet.id, 42);
      expect(packet.data, <Object>[
        'msg',
        <String, Object>{'a': 1},
      ]);
    });

    test('decodes acks', () {
      SocketPacket packet = SocketDecoder().add('35["ok"]')!;
      expect(packet.isAck, isTrue);
      expect(packet.id, 5);
    });

    test('waits for binary attachments', () {
      SocketDecoder decoder = SocketDecoder();
      expect(
        decoder.add(
          '52-3["up",{"_placeholder":true,"num":1},'
          '{"_placeholder":true,"num":0}]',
        ),
        isNull,
      );
      expect(decoder.add(Uint8List.fromList(<int>[1])), isNull);
      SocketPacket packet = decoder.add(Uint8List.fromList(<int>[2]))!;
      expect(packet.type, SocketPacketType.binaryEvent);
      expect(packet.id, 3);
      expect(packet.data, <Object>[
        'up',
        <int>[2],
        <int>[1],
      ]);
    });

    test('round trips binary through the encoder', () {
      Uint8List bytes = Uint8List.fromList(<int>[0, 255]);
      List<Object> parts = const SocketEncoder().encode(
        SocketPacket(
          type: SocketPacketType.event,
          data: <Object>[
            'e',
            <String, Object>{'b': bytes},
          ],
        ),
      );
      SocketDecoder decoder = SocketDecoder();
      SocketPacket? packet;
      for (Object part in parts) {
        packet = decoder.add(part);
      }
      expect(packet!.data, <Object>[
        'e',
        <String, Object>{'b': bytes},
      ]);
    });

    test('rejects bad packets', () {
      expect(() => SocketDecoder().add('9'), throwsFormatException);
      expect(() => SocketDecoder().add('2{"a":1}'), throwsFormatException);
      expect(() => SocketDecoder().add('2["connect"]'), throwsFormatException);
      expect(() => SocketDecoder().add('2[]'), throwsFormatException);
      expect(() => SocketDecoder().add('0"text"'), throwsFormatException);
      expect(() => SocketDecoder().add('1{}'), throwsFormatException);
      expect(() => SocketDecoder().add('5x-["a"]'), throwsFormatException);
      expect(() => SocketDecoder().add('2[bad json'), throwsFormatException);
      expect(() => SocketDecoder().add(Uint8List(1)), throwsFormatException);
      SocketDecoder waiting = SocketDecoder()
        ..add('51-["a",{"_placeholder":true,"num":0}]');
      expect(() => waiting.add('2["b"]'), throwsFormatException);
      SocketDecoder badNum = SocketDecoder()
        ..add('51-["a",{"_placeholder":true,"num":4}]');
      expect(() => badNum.add(Uint8List(1)), throwsFormatException);
    });
  });
}

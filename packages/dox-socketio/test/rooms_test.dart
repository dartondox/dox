import 'package:dox_socketio/dox_socketio.dart';
import 'package:test/test.dart';

void main() {
  group('RoomStore', () {
    late RoomStore store;

    setUp(() {
      store = RoomStore()
        ..addAll('a', <String>{'a', 'room1', 'vip'})
        ..addAll('b', <String>{'b', 'room1'})
        ..addAll('c', <String>{'c', 'room2'});
    });

    test('empty rooms means everyone', () {
      expect(store.match(<String>{}, <String>{}), <String>{'a', 'b', 'c'});
    });

    test('rooms are a union', () {
      expect(store.match(<String>{'room1', 'room2'}, <String>{}), <String>{
        'a',
        'b',
        'c',
      });
      expect(store.match(<String>{'room1'}, <String>{}), <String>{'a', 'b'});
    });

    test('except removes sockets in those rooms', () {
      expect(store.match(<String>{'room1'}, <String>{'vip'}), <String>{'b'});
      expect(store.match(<String>{}, <String>{'a'}), <String>{'b', 'c'});
    });

    test('unknown rooms match nobody', () {
      expect(store.match(<String>{'none'}, <String>{}), isEmpty);
    });

    test('del and delAll clean up', () {
      store.del('a', 'room1');
      expect(store.socketRooms('a'), <String>{'a', 'vip'});
      expect(store.match(<String>{'room1'}, <String>{}), <String>{'b'});
      store.delAll('b');
      expect(store.match(<String>{'room1'}, <String>{}), isEmpty);
      expect(store.socketRooms('b'), isEmpty);
    });
  });

  group('BroadcastOptions', () {
    test('JSON shape matches the Node.js redis adapter', () {
      BroadcastOptions options = BroadcastOptions(
        rooms: <String>{'r'},
        except: <String>{'x'},
        local: true,
      );
      expect(options.toJson(), <String, Object>{
        'rooms': <String>['r'],
        'except': <String>['x'],
        'flags': <String, Object>{'local': true},
      });
      BroadcastOptions back = BroadcastOptions.fromJson(<String, dynamic>{
        'rooms': <String>['r'],
        'except': <String>[],
        'flags': <String, dynamic>{},
      });
      expect(back.rooms, <String>{'r'});
      expect(back.local, isFalse);
    });
  });
}

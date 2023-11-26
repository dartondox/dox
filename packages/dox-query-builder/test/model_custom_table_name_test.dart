import 'package:dox_query_builder/dox_query_builder.dart';
import 'package:test/test.dart';

import 'connection.dart';
import 'models/user/user.model.dart';

void main() {
  group('Model with custom table name', () {
    setUp(() async {
      SqlQueryBuilder.initialize(database: poolConnection());
      await Schema.create('users', (Table table) {
        table.id();
        table.string('name');
        table.softDeletes();
      });
    });

    tearDown(() async {
      await Schema.drop('users');
    });

    test('get user list', () async {
      await User().insert(<String, String>{'name': 'dox'});

      List<User> users = await User().get();
      expect(users.length, 1);
      expect(users.first.name, 'dox');
    });
  });
}

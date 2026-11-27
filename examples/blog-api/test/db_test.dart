import 'dart:convert';

import 'package:blog/app/dtos/login_user/login_user.dto.dart';
import 'package:blog/app/models/post/post.model.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox_migration/dox_migration.dart';
import 'package:blog/app/models/user/user.model.dart';
import 'package:blog/config/app.dart';
import 'package:blog/config/database.dart';
import 'package:blog/providers/orm_provider.dart';
import 'package:test/test.dart';

import '../db/migration/migrations.dart';

/// Uses the database of `.env` (SQLite by default, no setup needed).
void main() {
  setUpAll(() async {
    Dox().initialize(appConfig);
    await Migrator(
      migrations: migrations,
      config: databaseConfig.getConnectionConfig(),
    ).migrate();
    await ORMProvider().setup();
  });

  test('user model: save, find, soft delete', () async {
    String email = 'test-${DateTime.now().microsecondsSinceEpoch}@dox.dev';

    User user = User()
      ..name = 'Dox'
      ..email = email
      ..password = 'secret';
    await user.save();
    expect(user.id, isNotNull);

    User? found = await User().where('email', email).getFirst();
    expect(found?.name, 'Dox');
    expect(found?.toJson().containsKey('password'), isFalse);

    await found?.delete();
    expect(await User().where('email', email).getFirst(), isNull);
    expect(
      await User().withTrash().where('email', email).getFirst(),
      isNotNull,
    );

    User? trashed = await User().withTrash().where('email', email).getFirst();
    await trashed?.forceDelete();
    expect(await User().withTrash().where('email', email).getFirst(), isNull);
  });

  /// The generator gives each model a writeJson(). Dox calls it for a
  /// response, and the model makes no Map. The JSON must be the JSON of
  /// toJson().
  test('a model writes its own JSON, the same as toJson()', () async {
    String email = 'json-${DateTime.now().microsecondsSinceEpoch}@dox.dev';
    await (User()
          ..name = 'Dox "é" 😀'
          ..email = email
          ..password = 'secret')
        .save();
    User user = (await User().where('email', email).getFirst())!;
    Post post = Post()
      ..title = 'A title'
      ..body = 'line 1\nline 2';
    await post.save();
    Post saved = (await Post().find(post.id))!;

    expect(user, isA<JsonWritable>());
    expect(saved, isA<JsonWritable>());

    String userJson = utf8.decode(JSON.bytes(user));
    expect(userJson, jsonEncode(user.toJson()));
    expect(userJson, contains('"created_at":"'));
    expect(userJson, isNot(contains('password')));
    expect(utf8.decode(JSON.bytes(saved)), jsonEncode(saved.toJson()));

    /// a list, and models in a map, as a controller returns them
    List<Post> posts = await Post().get();
    expect(
      utf8.decode(JSON.bytes(<String, dynamic>{'data': posts, 'user': user})),
      jsonEncode(<String, dynamic>{
        'data': <Map<String, dynamic>>[for (Post p in posts) p.toJson()],
        'user': user.toJson(),
      }),
    );

    await user.forceDelete();
    await saved.delete();
  });

  /// The schema of a DTO has a writeObject(), so a controller can return
  /// the DTO. The JSON has the keys that the DTO reads.
  test('a DTO writes its JSON', () {
    expect(LoginUser.schema, isA<JsonObjectWriter>());
    LoginUser login = const LoginUser(email: 'a@dox.dev', password: 'secret');
    expect(
      utf8.decode(JSON.bytes(login)),
      '{"email":"a@dox.dev","password":"secret"}',
    );
    expect(
      utf8.decode(JSON.bytes(<LoginUser>[login])),
      jsonEncode(<Map<String, dynamic>>[LoginUser.schema.toMap(login)]),
    );
  });
}

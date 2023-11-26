# Dart SQL Query Builder

## [Documentation](https://dox.zinkyawkyaw.dev/)

## Example Usage

- Install required dependency

```bash
$ dart pub add json_serializable --dev
$ dart pub add build_runner --dev
```

- Setup model

```dart
import 'package:postgres/postgres.dart';
import 'package:dox_query_builder/dox_query_builder.dart';

part 'actor.model.g.dart';

@IsModel()
class Actor extends Model {
  @Column()
  int? id;

  @Column(name: 'name')
  String? actorName;

  @Column()
  int? age;

  @Column(name: 'created_at')
  DateTime? createdAt;

  @Column(name: 'updated_at')
  DateTime? updatedAt;

  @override
  fromJson(Map<String, dynamic> json) => _$ActorFromJson(json);

  @override
  toMap() => _$ActorToJson(this);
}
```

- Run build runner

```bash
$ dart run build_runner build
```

```dart
void main() async {
  // create database connection and open
  PostgreSQLConnection db = PostgreSQLConnection(
    'localhost',
    5432,
    'postgres',
    username: 'admin',
    password: 'password',
  );
  await db.open();

  // initialize SqlQueryBuilder, only once at main function
  SqlQueryBuilder.initialize(database: db, debug: true);

  // and finally use model from anywhere in the project.
  Actor actor = Actor();
  actor.actorName = 'John Wick';
  actor.age = 60;
  actor = await actor.save();

  actor.actorName = "Tom Cruise";
  actor = await actor.save(); // save again

  print(actor.id);

  Actor result = await Actor().where('name', 'Tom Cruise').get();
  print(result.age);
}
```

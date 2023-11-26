<img src="https://raw.githubusercontent.com/dartondox/assets/main/dox-logo.png" width="70" />

# Dox Query Builder

## [Full documentation here](https://www.dartondox.dev/)

### Initialize Query Builder

```dart
PgPool dbPool = PgPool(
    PgEndpoint(
    host: 'localhost',
    port: 5432,
    database: 'postgres',
    username: 'postgres',
    password: 'postgres',
    ),
    settings: PgPoolSettings()
    ..maxConnectionAge = Duration(hours: 1)
    ..concurrency = 4,
);

/// Initialize Sql QueryBuilder
SqlQueryBuilder.initialize(
    database: dbPool,
    debug: true,
    printer: ConsoleQueryPrinter(),
);
```

### Usage

```dart
var result = await QueryBuilder.table('blog')
    .insert({
        'title': 'dox',
    });
```

### Usage with Model

#### make sure you have included `dox_builder` and `build_runner` in dev dependencies

```yaml
dev_dependencies:
  dox_builder: latest
  build_runner: ^2.3.3
```

#### Setup model 
> you can also use [dox-cli](https://pub.dev/packages/dox) to generate model.

```dart
import 'package:dox_query_builder/dox_query_builder.dart';
part 'blog.model.g.dart';

@DoxModel()
class Blog extends BlogGenerator {
  @Column()
  String? title;
  
  @Column(name: 'title', beforeSave: makeSlug)
  String? slug;

  @Column()
  String? status;

  @Column(name: 'body')
  String? description;

  @Column(name: 'created_at')
  DateTime? createdAt;

  @Column(name: 'updated_at')
  DateTime? updatedAt;

  static makeSlug(Map<String, dynamic> map) {
    return Slugify().slugify(map['title']);
  }
}
```

#### Run build runner

```bash
$ dart run build_runner build
```

#### Run query
```dart
Blog blog = Blog();
blog.title = 'dox';
await blog.save();
```

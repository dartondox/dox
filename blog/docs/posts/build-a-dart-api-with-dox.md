---
date:
  created: 2026-11-09
authors:
  - dox
categories:
  - Guides
tags:
  - getting started
  - tutorial
slug: build-a-dart-api-with-dox
---

# Build a Dart API with Dox

This post shows how to go from an empty folder to a tested API with a database, validation and a native binary, in a few short steps.

<!-- more -->

Each step has a small code block and a link to its docs page.
The code comes from the [tutorial](/latest/tutorial/), which builds a small blog API.

## 1. Install the CLI and make a project

You need Dart 3.13 or newer.

```bash
dart pub global activate dox
dox create blog
cd blog
dart pub get
```

`dox create` downloads the starter project and makes a `.env` file with a new random `APP_KEY`.
The starter project uses SQLite, so there is no database to install.

Docs: [Installation](/latest/getting-started/installation/)

## 2. Start the server

```bash
dox s
```

`dox s` is short for `dox serve`.
It runs the code generator and the server.
It restarts the server when you save a `.dart` file.

```bash
curl http://localhost:3000/api/ping
```

```text
pong
```

Docs: [Step 1: Create the project](/latest/tutorial/01-create-project/)

## 3. Make a model and a migration

Stop `dox s` first with `Ctrl+C`.
`dox s` restarts the server when a new file appears, and the server runs new migrations at start.
So it would run the new migration before you add the columns.

One command makes the model and the migration:

```bash
dox make:model Post -m
```

Add the columns to the migration:

```dart title="db/migration/<date>_create_posts_table.dart"
await schema.create('posts', (Table table) {
  table.id();
  table.string('title');
  table.text('body');
  table.timestamps();
});
```

Add the same fields to the model:

```dart title="lib/app/models/post/post.model.dart"
@DoxModel(table: 'posts')
class Post extends PostGenerator {
  @Column()
  String? title;

  @Column()
  String? body;
}
```

Then run the migration:

```bash
dox migration:run
```

Then start `dox s` again.
The server also runs new migrations each time it starts.

Docs: [Step 2: Model and migration](/latest/tutorial/02-model-and-migration/), [Model](/latest/database/model/)

## 4. Add a controller and routes

```bash
dox make:controller Post -r
```

A controller method can return a model or a list of models.
Dox sends it as JSON.

```dart title="lib/app/http/controllers/post.controller.dart"
@Inject()
class PostController {
  Future<List<Post>> index(DoxRequest req) async {
    return Post().all();
  }

  Future<Post> show(int id) async {
    Post? post = await Post().find(id);
    if (post == null) {
      throw NotFoundHttpException();
    }
    return post;
  }
}
```

One line adds the routes:

```dart title="lib/routes/api.dart"
Route.resource('posts', PostController);
```

`Route.resource` makes a route for each method the controller has.
Here that is `GET /api/posts` and `GET /api/posts/{id}`.
Dox makes the controller for you, because it has `@Inject()`.

Docs: [Step 3: Routes and controller](/latest/tutorial/03-routes-and-controller/), [Routing](/latest/the-basic/routing/)

## 5. Check the input with a DTO

```bash
dox make:dto SavePost
```

A DTO is a class with rules on its fields:

```dart title="lib/app/dtos/save_post/save_post.dto.dart"
@Dto()
class SavePost {
  @Trim()
  @Length(min: 3, max: 100)
  final String title;

  @Trim()
  @MinLength(10)
  final String body;

  const SavePost({required this.title, required this.body});

  static const DtoSchema<SavePost> schema = $SavePostDto;
}
```

Ask for it as a parameter in the controller:

```dart
Future<DoxResponse> store(SavePost body) async {
  Post post = Post()
    ..title = body.title
    ..body = body.body;
  await post.save();
  return response(post).statusCode(201);
}
```

Dox checks the body before the method runs.
Your code gets a typed object.
Bad input gets a `422` answer with one message for each field:

```json
{"title":"The title must be between 3 and 100 characters","body":"The body must be at least 10 characters"}
```

Add two lines to `lib/config/app.dart`, so the app knows the DTOs:

```dart title="lib/config/app.dart"
import 'package:blog/generated/dtos.g.dart';

AppConfig appConfig = AppConfig(
  dtos: dtos,
  // ... the rest stays the same
);
```

Docs: [Step 4: Validation](/latest/tutorial/04-validation/), [Validation](/latest/the-basic/validation/)

## 6. Write a test

`DoxTestClient` starts the app inside the test, on a free port.

```dart title="test/http_test.dart"
void main() {
  late DoxTestClient client;

  setUpAll(() async {
    client = await DoxTestClient.start(appConfig);
  });

  tearDownAll(() async {
    await client.close();
  });

  test('GET /api/posts gives a list', () async {
    TestResponse res = await client.get('/api/posts');
    res.expectStatus(200).expectJson(isA<List<dynamic>>());
  });
}
```

```bash
dart test
```

The full test in the tutorial also runs the migrations first, so it works on an empty database.

Docs: [Step 6: Test](/latest/tutorial/06-test/), [Testing](/latest/digging-deeper/testing/)

## 7. Build one binary

```bash
dox build
```

`dox build` runs the code generator, then compiles the app.
The result is in `build/bundle`.
`bin/server` is one native binary. It does not need the Dart SDK.

```bash
cd build/bundle
cp ../../.env .env
./bin/server
```

The project also has a `Dockerfile` that builds the same bundle into a small image.

Docs: [Step 7: Build and deploy](/latest/tutorial/07-build-and-deploy/), [Docker](/latest/guides/docker/)

## What you have now

- A server that restarts when you save a file.
- A database table, a model and a migration.
- Routes and a controller that return JSON.
- Input checks with a typed DTO and a `422` answer for bad input.
- A test that runs the real app.
- One binary for production.

The [tutorial](/latest/tutorial/) does all of this in full, and adds login with `dox_auth` in [step 5](/latest/tutorial/05-auth/).

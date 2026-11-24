---
icon: lucide/share-2
---

# Share code with Flutter

Put a `@Dto` class in a shared Dart package, so the Dox server and the Flutter app check input with the same rules and error messages.

The app checks the form, so the user sees an error at once. The server checks the same input again, because it can not trust the client. The generated [DTO](../the-basic/dto.md) code is pure Dart, so it runs in Flutter and on the web.

## What you need

- A Dox app (`dox create server`). Here it is in the `server` folder.
- A Flutter app (`flutter create app`). Here it is in the `app` folder.

## The layout

The three parts live next to each other in one folder:

```text
my_blog/
  packages/
    blog_shared/     # the DTOs. Pure Dart.
  server/            # the Dox app
  app/               # the Flutter app
```

The app and the server use the same DTO:

<div class="dox-fan dox-fan--via" role="group" aria-label="The app and the server use the shared package">
  <div class="dox-fan__top"><strong>packages/blog_shared</strong><span>SaveBlog and SaveBlog.schema</span></div>
  <div class="dox-fan__cols">
    <ol><li><strong>app: Flutter</strong><span>checks the form</span></li></ol>
    <ol data-via="POST /api/blogs (JSON)"><li><strong>server: Dox</strong><span>checks the request</span></li></ol>
  </div>
</div>

## 1. The shared package

Make a plain Dart package for the DTOs:

```yaml title="packages/blog_shared/pubspec.yaml"
name: blog_shared
description: DTOs shared by the Dox server and the Flutter app.
version: 0.1.0
publish_to: none

environment:
  sdk: ^3.13.0

```

Add the packages:

```bash
cd packages/blog_shared
dart pub add dox_validation
dart pub add dev:dox_builder dev:build_runner
```

Now write the DTO. Import `dox_validation`, not `dox_core`, because `dox_core` does not run in Flutter:

```dart title="packages/blog_shared/lib/src/save_blog.dart"
import 'package:dox_validation/dox_validation.dart';

part 'save_blog.g.dart';

/// A new blog post. The server and the app check it with the same rules.
@Dto()
class SaveBlog {
  @Trim()
  @Length(min: 3, max: 255)
  final String title;

  @Trim()
  @MinLength(10)
  final String description;

  const SaveBlog({required this.title, required this.description});

  static const DtoSchema<SaveBlog> schema = $SaveBlogDto;
}
```

Export the DTOs. Also export `dox_validation`, so the app gets `ParseResult` and `ValidationException` from the same import:

```dart title="packages/blog_shared/lib/blog_shared.dart"
export 'package:dox_validation/dox_validation.dart';

export 'src/save_blog.dart';
```

Generate the code:

```bash
cd packages/blog_shared
dart pub get
dart run build_runner build
```

This writes `lib/src/save_blog.g.dart` and `lib/generated/dtos.g.dart`, the list of every DTO in the package. Commit both files, so the Flutter app does not need to run the generator.

`@Unique` and `@Exists` come from `dox_orm`, which the app can not import. Check them on the server only.

## 2. The Dox server

Add the shared package to the dependencies of the server:

```yaml title="server/pubspec.yaml"
dependencies:
  # ... the packages of the new app stay
  blog_shared:
    path: ../packages/blog_shared
```

Run `dart pub get`.

Add the DTO list of the shared package to the `dtos` list of `AppConfig`:

```dart title="server/lib/config/app.dart"
import 'package:blog_shared/generated/dtos.g.dart' as shared;
import 'package:dox_core/dox_core.dart';
import 'package:server/generated/dtos.g.dart';

AppConfig appConfig = AppConfig(
  // ...
  dtos: <DtoSchema<Object>>[...dtos, ...shared.dtos],
);
```

The controller asks for `SaveBlog` like any other DTO. Bad input gets 422:

```dart title="server/lib/app/http/controllers/blog.controller.dart"
import 'package:blog_shared/blog_shared.dart' show SaveBlog;
import 'package:dox_core/dox_core.dart';

@Inject()
class BlogController {
  Future<Map<String, dynamic>> store(SaveBlog body) async {
    // body.title is already trimmed and checked.
    return <String, dynamic>{'title': body.title, 'saved': true};
  }
}
```

Use `show SaveBlog` in server code, because `dox_core` and `blog_shared` both export a `ValidationException` class.

Add the route:

```dart title="server/lib/routes/api.dart"
Route.post('/blogs', (BlogController c) => c.store);
```

A bad request gets the errors as `{"key": "message"}`:

```text
POST /api/blogs  {"title": "ab", "description": "short"}
422 {"title":"The title must be between 3 and 255 characters",
     "description":"The description must be at least 10 characters"}
```

## 3. The Flutter app

Add the shared package to the app:

```yaml title="app/pubspec.yaml"
name: app
publish_to: none

environment:
  sdk: ^3.13.0

dependencies:
  flutter:
    sdk: flutter
  http: ^1.6.0
  blog_shared:
    path: ../packages/blog_shared
```

The widget checks the form with `SaveBlog.schema.safeParse()`, and sends only good input. `result.errors` has the same shape as the 422 body of the server:

```dart title="app/lib/new_blog_form.dart"
import 'dart:convert';

import 'package:blog_shared/blog_shared.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class NewBlogForm extends StatefulWidget {
  const NewBlogForm({super.key});

  @override
  State<NewBlogForm> createState() {
    return _NewBlogFormState();
  }
}

class _NewBlogFormState extends State<NewBlogForm> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  Map<String, String> _errors = <String, String>{};

  Future<void> _submit() async {
    ParseResult<SaveBlog> result =
        SaveBlog.schema.safeParse(<String, dynamic>{
      'title': _title.text,
      'description': _description.text,
    });
    if (!result.success) {
      setState(() {
        _errors = result.errors;
      });
      return;
    }

    http.Response response = await http.post(
      Uri.parse('https://api.example.com/api/blogs'),
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(SaveBlog.schema.toMap(result.value!)),
    );
    setState(() {
      _errors = response.statusCode == 422
          ? Map<String, String>.from(jsonDecode(response.body) as Map)
          : <String, String>{};
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TextField(
          controller: _title,
          decoration: InputDecoration(
              labelText: 'Title', errorText: _errors['title']),
        ),
        TextField(
          controller: _description,
          decoration: InputDecoration(
              labelText: 'Description',
              errorText: _errors['description']),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
```

## Other schema methods

The schema has more methods than `safeParse`:

- `parse` throws a `ValidationException` when the input is bad.
- `toMap` gives the JSON map to send.
- `toJsonSchema` gives the JSON Schema of the DTO.

If the DTO has an async `validate()` method, use `safeParseAsync` or `parseAsync`.

## Next steps

- [Validation](../the-basic/validation.md): all the rules.
- [dox_validation](../packages/validation.md): all the schema methods.

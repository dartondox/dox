# Build a blog API

This tutorial takes you from an empty folder to a small blog API that runs as one native binary.
Every step has the full code and a `curl` command to check it.

The finished project is on GitHub: [examples/blog-api](https://github.com/dartondox/dox/tree/main/examples/blog-api).
CI builds it and runs its tests on every push, so the code on these pages keeps working.

## What you will build

A JSON API for blog posts.

| Method | Path | Who | What it does |
| --- | --- | --- | --- |
| `GET` | `/api/posts` | anyone | list all posts |
| `GET` | `/api/posts/{id}` | anyone | one post, or `404` |
| `POST` | `/api/posts` | logged in user | make a post (`201`, or `422` on bad input) |
| `PUT` | `/api/posts/{id}` | logged in user | change a post |
| `POST` | `/api/auth/register` | anyone | make an account, get a token |
| `POST` | `/api/auth/login` | anyone | log in, get a token |
| `GET` | `/api/auth/user` | logged in user | the user of the token |

## What you need

- Dart **3.13** or newer: `dart --version`.
- `curl`, to call the API.
- About 15 minutes.

You do not need Docker or a database server. The app uses SQLite, which is one file in your project.

## The steps

1. [Create the project](01-create-project.md)
2. [Model and migration](02-model-and-migration.md)
3. [Routes and controller](03-routes-and-controller.md)
4. [Validation](04-validation.md)
5. [Login with dox_auth](05-auth.md)
6. [Test](06-test.md)
7. [Build and deploy](07-build-and-deploy.md)

## The finished project

Files that you make or change in this tutorial are marked with `*`.

```text
blog/
├── bin/
│   ├── migrate.dart              runs the dox migration:* commands
│   └── server.dart               runs the migrations, starts the server
├── db/migration/
│   ├── ..._create_posts_table.dart   *
│   ├── ..._create_users_table.dart
│   └── migrations.dart           the list of migrations (Dox writes it)
├── lib/
│   ├── app/http/controllers/
│   │   ├── auth.controller.dart  *
│   │   └── post.controller.dart  *
│   ├── app/http/dtos/
│   │   ├── login_user.dto.dart   *
│   │   ├── register_user.dto.dart *
│   │   └── save_post.dto.dart    *
│   ├── app/models/
│   │   ├── post/post.model.dart  *
│   │   └── user/user.model.dart
│   ├── config/
│   │   ├── app.dart              * adds the DTO list
│   │   ├── database.dart
│   │   └── env.dart              the .env keys, typed
│   ├── routes/api.dart           *
│   ├── providers/
│   │   ├── auth_service.dart     *
│   │   └── orm_service.dart
│   └── generated/
│       ├── container.g.dart      * generated
│       └── dtos.g.dart           * generated
├── test/http_test.dart           *
├── .env                          *
├── Dockerfile
└── pubspec.yaml                  * adds dox_auth
```

Start with [step 1: create the project](01-create-project.md).

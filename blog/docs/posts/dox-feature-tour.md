---
date:
  created: 2026-11-09
authors:
  - dox
categories:
  - Introduction
tags:
  - features
  - packages
slug: dox-feature-tour
---

# A tour of Dox features

This post is a short tour of the parts that come with Dox, from routing and validation to the ORM, login, queues, mail and the CLI.

<!-- more -->

Each item has one to three lines and a link to its docs page.
Some parts are in the core package `dox_core`.
Other parts are separate packages. You add only the ones you need.

## Core

- **[Routing](/latest/the-basic/routing/)**: Routes for each HTTP method, route params, groups, resource routes and named routes.
  Signed routes and route model binding are included.
- **[Middleware](/latest/the-basic/middleware/)**: Class or function middleware for one route, a group, a router or all routes.
  Request id, ETag and request timeout middleware come with it.
- **[Request](/latest/the-basic/request/) and [response](/latest/the-basic/response/)**: Read input, headers, files and the client IP.
  Return a model, a map or a list, and Dox sends JSON. Files and big responses are streamed.
- **[DTO validation](/latest/the-basic/validation/)**: Write a `@Dto` class with rules on its fields.
  Dox checks the input and gives your controller a typed object. Bad input gets a `422` answer.
- **[OpenAPI](/latest/packages/openapi/)**: `dox_openapi` makes OpenAPI 3.1 docs from your routes and DTOs.
  It also serves a docs page at `/docs`.
- **[Sessions](/latest/the-basic/session/) and [CSRF](/latest/security/csrf/)**: Sessions with a cookie or cache driver, and flash data.
  CSRF protection for forms.
- **[Cookies](/latest/the-basic/response/#cookie)**: Set cookies on a response and [read them](/latest/the-basic/request/#cookies) from a request.
  Dox encrypts cookies with your `APP_KEY`.
- **[Encryption](/latest/security/encryption/) and [hashing](/latest/security/hashing/)**: `Crypt` encrypts and decrypts text with the app key.
  `Hash` hashes and checks passwords. `Hash.makeAsync` and `Hash.verifyAsync` do not block the server.
- **[Rate limiting](/latest/security/rate-limiting/)**: The `RateLimit` middleware stops a client that sends too many requests.
  With a Redis cache, all servers share the counts.
- **[Security headers](/latest/security/security-headers/)**: The `SecurityHeaders` middleware sets safe default headers.
  You can change or turn off each header.
- **[CORS](/latest/security/cors/)**: Allow one or more origins, and answer preflight requests.
- **[Static files](/latest/guides/static-files/)**: Serve a folder or a storage disk with one line.
  You can also serve a single page app.
- **[Health checks](/latest/digging-deeper/health-check/)**: A health route for a load balancer, Docker or Kubernetes.
  It can check the database and the cache.
- **[IoC container](/latest/the-basic/dependency-injection/)**: Add `@Inject()` to a class, and Dox makes it and its parameters for you.
  The container is generated code. It does not use reflection.
- **[Providers](/latest/digging-deeper/providers/)**: A provider sets up a package or a service when the app starts, and cleans up when it stops.
- **[Exception handler](/latest/the-basic/errors/)**: Every error goes to one handler.
  It logs the error and decides what the client gets.
- **[Logging](/latest/reference/app-config/#loggerconfig)**: The `Logger` prints colored text in development, or one JSON object per line for a log service.

## Data

- **[ORM models](/latest/database/model/)**: A model is a class for one table.
  Save, find, delete, hide fields and mass assignment rules are included.
- **[Relations](/latest/database/model/relationship/has-many/)**: Has one, has many, belongs to, many to many and polymorphic relations.
  You can [query and count](/latest/database/model/relation-queries/) relations too.
- **[Scopes](/latest/database/model/scopes/) and [casts](/latest/database/model/casts/)**: A scope is a query part you use again and again.
  A cast changes a column value between the database and Dart, like JSON or an enum.
- **[Factories](/latest/database/factories/) and [seeders](/latest/database/seeders/)**: A factory makes models with sample data for tests.
  A seeder puts data in your database.
- **[Migrations](/latest/database/migration/)**: Write the schema in Dart, then run, roll back or check migrations with the CLI.
- **[Query builder](/latest/database/query-builder/) and [transactions](/latest/database/transactions/)**: Build SQL from chained methods with bound values. Run many queries in one transaction.
- **[Databases](/latest/database/#supported-databases)**: Postgres, MySQL, MariaDB and SQLite.
  Postgres and MySQL use [native](/latest/database/postgres-native/) [drivers](/latest/database/mysql-native/).

## Auth

- **[Guards](/latest/security/authentication/#more-than-one-guard)**: Use more than one guard in one app, or write your own, like an API key guard.
- **[JWT](/latest/security/authentication/)**: `dox_auth` logs users in with JWT tokens. Tokens can be revoked.
- **[Session login](/latest/security/authentication/#session-login-for-web-pages)**: Log users in with a session cookie for web pages.
- **[Access tokens](/latest/security/authentication/#access-tokens)**: Tokens saved in the database, with abilities. You can revoke them one by one.
- **[Gates and policies](/latest/security/authorization/)**: A gate checks one action. A policy groups the checks for one model.
  Use them in a controller or on a route.

## Packages

- **[Cache](/latest/digging-deeper/cache/)**: `dox_cache` comes with `dox_core`, so there is nothing to add. It has memory, file and Redis stores, with tags and locks.
- **[Queue](/latest/digging-deeper/queue/)**: `dox_queue` runs slow work in the background.
  It has Redis, database and sync drivers, retries, delays and a worker.
- **[Scheduler](/latest/digging-deeper/scheduler/)**: `dox_scheduler` runs tasks on a schedule, like cron.
  You write the schedule in Dart.
- **[Mail](/latest/digging-deeper/mail/) and [notifications](/latest/digging-deeper/notifications/)**: `dox_mailer` sends email with SMTP, Amazon SES, Resend, Mailgun, Postmark and more.
  A notification can go out on more than one channel.
- **[Storage](/latest/packages/storage/)**: `dox_storage` gives one API for local disk, AWS S3 and S3-compatible services, with signed URLs.
- **[Socket.IO](/latest/packages/socketio/)**: `dox_socketio` is a Socket.IO v4 server.
  The official clients connect with no changes.
- **[Views](/latest/the-basic/views/)**: `dox_view` is an HTML template engine. Templates are `.dox.html` files.
- **[Inertia](/latest/the-basic/inertia/)**: `dox_inertia` lets you build a single page app with React, Vue or Svelte, with routes and controllers in Dox.
- **[MCP](/latest/packages/mcp/)**: `dox_mcp` serves tools to MCP clients from a normal Dox route.
  Tool arguments are checked before your code runs.
- **Redis**: Redis is not a separate package to install. It is a driver in the [cache](/latest/packages/cache/), the [queue](/latest/digging-deeper/queue/#redis) and the [Socket.IO adapter](/latest/packages/socketio/#many-servers-redis-adapter).
  These packages bring their own Redis client. Use Redis when you run more than one server.

## Tooling

- **[CLI generators](/latest/reference/cli/)**: `dox make:controller`, `make:model`, `make:dto`, `make:middleware`, `make:migration`, `make:factory`, `make:seeder`, `make:job` and more.
- **[Testing helpers](/latest/digging-deeper/testing/)**: `DoxTestClient` runs the app inside a test.
  It can keep a session and log in as a user.
- **[`dox build`](/latest/reference/cli/#dox-build)**: Builds the app into one native binary. It does not need the Dart SDK.
- **[Docker](/latest/guides/docker/)**: The project has a `Dockerfile` and a compose file.
  The image holds only the binary and the files it needs.
- **[App template](https://github.com/dartondox/dox-sample)**: `dox create` starts from this template.
  It has an `AGENTS.md` file and a skill with step-by-step recipes for AI coding tools.

## Get started

Install the CLI and make your first project: [Installation](/latest/getting-started/installation/).

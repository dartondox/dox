---
title: "Dart ORM with migrations in Dox: models and relations"
date:
  created: 2026-11-27
authors:
  - aj
categories:
  - Guides
tags:
  - orm
  - database
  - tutorial
slug: dart-orm-models-relations-migrations
description: "A Dart ORM tutorial with Dox: make two tables with migrations, write the models, connect them with relations, and read and save rows with typed queries."
---

# Dart ORM with migrations: models, relations and queries

This post shows how to use the Dart ORM in Dox: make two tables with migrations, write the models, connect them with relations, and read and save rows with typed queries.

<!-- more -->

A backend needs more than a database driver.
It needs a way to change the tables with time, a class for each table, and a safe way to load related rows.
In Dox, these parts come in two packages, [`dox_orm`](https://pub.dev/packages/dox_orm) and [`dox_migration`](https://pub.dev/packages/dox_migration), and a new project has both from the start.

The example is a team app with projects and tasks.
A project has many tasks, and a task belongs to one project.
All code in this post was tested with `dox_orm` 3.2.4 and `dox_migration` 3.2.4 on SQLite.

> **Key takeaways**
>
> - **One command makes the model and the migration.** `dox make:model Task -m` writes both files.
> - **Migrations are Dart code.** Each one has an `up` and a `down`, and `dox migrate` runs the new ones.
> - **Relations are fields.** `@HasMany(Task)` on a list field connects the two models.
> - **No N+1 queries.** `preload('tasks')` loads the tasks of all projects with one more query.
> - **Four databases.** The same code runs on Postgres, MySQL, MariaDB and SQLite.

## What you need

- Dart 3.13 or newer.
- The `dox` CLI and a Dox app:

```bash
dart pub global activate dox
dox create team_app
cd team_app
dart pub get
```

A new app uses SQLite, so you do not install a database.
If you are new to Dox, read [Build a Dart API with Dox](build-a-dart-api-with-dox.md) first.

## 1. Make the models and the migrations

Make a model for each table.
The `-m` option also makes the migration:

```bash
dox make:model Project -m
dox make:model Task -m
```

Each command makes two files:

| File | What it is |
| --- | --- |
| `lib/app/models/task/task.model.dart` | the model |
| `db/migration/<date>_create_tasks_table.dart` | the migration |

The date in the file name keeps the migrations in the right order.

## 2. Write the migrations

A **migration** is a small class that changes the database.
`up` makes the change, and `down` undoes it.
Open the new file of the projects table and add a name column:

```dart title="db/migration/2026_11_27_145046_create_projects_table.dart"
// ignore_for_file: file_names
import 'package:dox_migration/dox_migration.dart';

class CreateProjectsTable extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await schema.create('projects', (Table table) {
      table.id();
      table.string('name');
      table.timestamps();
    });
  }

  @override
  Future<void> down(Schema schema) async {
    await schema.dropIfExists('projects');
  }
}
```

Then open the file of the tasks table.
It has a foreign key to the projects table:

```dart title="db/migration/2026_11_27_145047_create_tasks_table.dart"
// ignore_for_file: file_names
import 'package:dox_migration/dox_migration.dart';

class CreateTasksTable extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await schema.create('tasks', (Table table) {
      table.id();
      table.foreignId('project_id').constrained().cascadeOnDelete();
      table.string('title');
      table.boolean('done').defaultTo(false);
      table.timestamps();
    });
  }

  @override
  Future<void> down(Schema schema) async {
    await schema.dropIfExists('tasks');
  }
}
```

Three lines do most of the work:

- `table.id()` makes an auto increment primary key.
- `table.timestamps()` makes the created_at and updated_at columns, and the model fills them.
- `foreignId('project_id').constrained()` makes the column and the foreign key. The table name comes from the column name: project_id gives projects.

With `cascadeOnDelete()`, the database deletes the tasks of a project when you delete the project.
See [Schema](/latest/database/schema/) for all column types.

## 3. Write the models

A **model** is a Dart class for one table.
Each `@Column()` field is one column, and each object is one row:

```dart title="lib/app/models/project/project.model.dart"
import 'package:dox_orm/dox_orm.dart';

import '../task/task.model.dart';

part 'project.model.g.dart';

@DoxModel(table: 'projects')
class Project extends ProjectGenerator {
  @override
  List<String> get fillable => <String>['name'];

  @Column()
  String? name;

  @HasMany(Task)
  List<Task> tasks = <Task>[];
}
```

```dart title="lib/app/models/task/task.model.dart"
import 'package:dox_orm/dox_orm.dart';

import '../project/project.model.dart';

part 'task.model.g.dart';

@DoxModel(table: 'tasks')
class Task extends TaskGenerator {
  @override
  List<String> get fillable => <String>['title', 'done'];

  @Column()
  int? projectId;

  @Column()
  String? title;

  @Column()
  bool? done;

  @BelongsTo(Project)
  Project? project;
}
```

Some things to know:

- The column name is the field name in snake_case, so `projectId` is the column project_id.
- Each column field is nullable, because a new `Task()` has no values.
- The id and the timestamps come from the generated class, `TaskGenerator`.
- `@HasMany(Task)` and `@BelongsTo(Project)` are the two sides of one relation. Both use the column project_id by default.

### What `fillable` is for

`fillable` lists the keys that a model takes from a map.
A map often comes from the client, and a client can send keys that you do not expect.
So a model takes no key from a map until you list it.
Fields that you set in code are always saved.

## 4. Run the migrations

Run the new migrations, then the code generator:

```bash
dox migrate
dart run build_runner build
```

```text
Migrating: 2026_11_27_145046_create_projects_table
Migrated: 2026_11_27_145046_create_projects_table
Migrating: 2026_11_27_145047_create_tasks_table
Migrated: 2026_11_27_145047_create_tasks_table
```

`dox migrate` runs only the migrations that did not run yet.
The server of a new Dox app also runs them at the start.
With many machines, run them in one place only.
See [Deploy a Dart server to production with Dox](deploy-dart-server-to-production.md).

## 5. Save rows

Make a model, set its fields and call `save()`:

```dart
Project project = Project()..name = 'Website';
await project.save();
print(project.id); // 1
```

`createRelated()` saves a task of this project and sets the foreign key for you:

```dart
Task task = await project.createRelated<Task>('tasks',
    <String, dynamic>{'title': 'Write the home page'});
print(task.projectId); // 1
```

`'tasks'` is the name of the relation field in `Project`.

To change a row, set a field and save again.
Dox sends only the fields that changed:

```dart
task.done = true;
await task.save();
```

```sql
UPDATE "tasks" SET "done" = TRUE,"updated_at" = '...' WHERE "id" = 1;
```

## 6. Read rows

A model has all the query builder methods.
The result is a typed object or a typed list, not a map:

```dart
Project? found = await Project().find(1);

List<Task> open = await Task()
    .where('project_id', 1)
    .where('done', false)
    .orderBy('id', 'desc')
    .get();
```

Values go to the database as parameters of the query, so user input in a `where` is safe.

For a long list, `paginate` returns one page and the page info:

```dart
Pagination<Task> page =
    await Task().paginate(currentPage: 1, perPage: 10);
print(page.total); // the number of rows that match
```

A controller can return a model, a list of models or a page, and Dox sends it as JSON.
See [Query builder](/latest/database/query-builder/) for joins, groups, raw SQL and more.

## 7. Load relations with no N+1 queries

A relation is not loaded by default.
`preload()` loads it for all rows of the query:

```dart
List<Project> projects = await Project().preload('tasks').get();
print(projects.first.tasks.length);
```

Dox runs two queries, for any number of projects:

```sql
SELECT * FROM "projects";
SELECT *,"project_id" as "_owner_id" FROM "tasks"
  WHERE "project_id" IN (1);
```

The loaded tasks are also in the JSON of the project, with the key tasks.

The other side works the same way:

```dart
List<Task> tasks = await Task().preload('project').get();
print(tasks.first.project?.name); // Website
```

### Count the related rows

`withCount()` adds the number of tasks to each project and does not load the tasks:

```dart
List<Project> projects = await Project().withCount('tasks').get();
print(projects.first.countOf('tasks')); // 2
```

In JSON, the key is tasks_count.

### Filter by the related rows

`whereHas()` keeps only the projects that have a task that matches:

```dart
List<Project> busy = await Project().whereHas('tasks',
    (QueryBuilder<dynamic> q) {
  q.where('done', false);
}).get();
```

Dox also has one-to-one, many-to-many, through and polymorphic relations.
See [HasMany](/latest/database/model/relationship/has-many/) and the other relation pages.

## 8. Keep related writes together

A **transaction** runs many queries as one unit.
If the function throws, the database saves none of them:

```dart
await QueryBuilder.transaction(() async {
  Project project = Project()..name = 'Mobile app';
  await project.save();
  await project.createRelated<Task>('tasks',
      <String, dynamic>{'title': 'Set up the project'});
});
```

All models and queries inside the function use the transaction.
See [Transactions](/latest/database/transactions/).

## 9. Change a table later

Do not edit a migration that already ran on a server.
Make a new one.
The name tells Dox which table it changes:

```bash
dox make:migration add_due_date_to_tasks_table
```

```dart title="db/migration/2026_11_27_145102_add_due_date_to_tasks_table.dart"
// ignore_for_file: file_names
import 'package:dox_migration/dox_migration.dart';

class AddDueDateToTasksTable extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await schema.table('tasks', (Table table) {
      table.date('due_date').nullable();
    });
  }

  @override
  Future<void> down(Schema schema) async {
    await schema.table('tasks', (Table table) {
      table.dropColumn('due_date');
    });
  }
}
```

Add the field to the `Task` model:

```dart title="lib/app/models/task/task.model.dart"
@Column()
DateTime? dueDate;
```

Then run `dox migrate` and the generator again.

To see which migrations ran, and to undo the last one:

```bash
dox migration:status
dox migration:rollback --step=1
```

See [Migration](/latest/database/migration/) for SQL migrations and the other commands.

## Which databases work

The code in this post ran on SQLite, the default of a new app.
The same models, queries and migrations run on four databases:

| Database | Good for |
| --- | --- |
| SQLite | development, tests and small apps. No install |
| Postgres | production |
| MySQL 8+ and MariaDB | production |

To change the database, set `DB_CONNECTION` and the other `DB_*` keys in `.env`.
A new app skips the Postgres and MySQL drivers, so also remove the skip lines of your driver in `pubspec.yaml`.
See [Skip unused drivers](/latest/database/#skip-unused-drivers).

On MySQL and MariaDB, a failed migration can not undo a `CREATE`, `ALTER` or `DROP`.
So make one table change in each migration.
Dox does not support MongoDB or other databases that are not SQL.
See [Database](/latest/database/).

## FAQ

### Is there an ORM for Dart?

Yes.
Dox has one with models, relations, migrations, soft deletes and transactions, and a new Dox project includes it.
Some other Dart backends have an ORM too.
[Dart backend frameworks: how to choose](dart-backend-frameworks-how-to-choose.md) lists them.

### Do I write SQL for a migration?

No, a migration is Dart code with a schema builder.
You can also write a migration as a plain `.sql` file if your team prefers SQL.

### How do I stop N+1 queries?

Use `preload()`.
It loads a relation for all rows of a query with one more query.
Use `withCount()` when you need only the number of related rows.

### Can I use the ORM in tests?

Yes.
A new app has a database test that runs the migrations on SQLite and then saves and reads a model.

## Summary

- `dox make:model Task -m` makes a model and its migration.
- A migration changes the tables. `dox migrate` runs the new ones, and the server runs them at the start.
- `@HasMany` and `@BelongsTo` connect two models, and `preload()` loads the related rows with one more query.

Next, put these models behind an API.
[Build a Dart API with Dox](build-a-dart-api-with-dox.md) adds routes, a controller and typed validation.
For every model method, read [Model](/latest/database/model/) in the docs.

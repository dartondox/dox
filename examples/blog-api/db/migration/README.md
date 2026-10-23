# Migrations

- `dox make:migration create_posts_table` makes a Dart migration here and
  updates `migrations.dart`, the list the app imports. Do not edit that list.
- `dox migration:run`, `migration:rollback`, `migration:status` run them.
- `bin/server.dart` also runs them once at start.
- A `.sql` file with `-- up` and `-- down` parts works too. Keep both comments.

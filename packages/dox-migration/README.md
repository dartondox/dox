# Dox Migration

Database migration package for Postgres SQL.

# Usage

## Create migration file

### `.sql` file

```bash
dox_migration create CreateUserTable --sql 
```

### `.dart` file

```bash
dox_migration create CreateUserTable --dart 
```

> `.dart` file required [dox query builder](https://pub.dev/packages/dox_query_builder)

## Run migration and rollback

### `.env` sample

```bash
DB_HOST=localhost
DB_PORT=5432
DB_NAME=dox_example_app
DB_USERNAME=admin
DB_PASSWORD=password

```

###  Migrate

```dart
await Migration().migrate();
```

### Rollback

```dart
await Migration().rollback();
```

### Without using `.env`

```dart
PgEndpoint endPoint = PgEndpoint(
    host: 'localhost',
    port: 5432,
    database: 'postgres',
    username: 'postgres',
    password: 'postgres',
);
await Migration().migrate(endPoint: endPoint);
```
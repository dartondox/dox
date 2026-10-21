# Environment Variables

`Env.get()` reads a value from the environment or from the `.env` file.

!!! info "The environment wins"
    A real environment variable (set in the shell, Docker or systemd) wins over the `.env` file.
    So you can keep `.env` for development and use real variables in production.
    Before 3.x, only the `.env` file was read.

=== "Example"

    ```dart
    Env.get('APP_KEY');

    // With default values
    Env.get('APP_KEY', 'default_value');
    ```

## With type

=== "Int"

    ```dart
    Env.get<int>('APP_PORT', 3000)
    ```

=== "String"

    ```dart
    Env.get<String>('APP_KEY')
    ```
=== "Bool"

    ```dart
    Env.get<bool>('SOCKETIO_ENABLED', false) // true, 1, yes, on
    ```

=== "Nullable"

    ```dart
    Env.get<String?>('AWS_BUCKET') // null when it is not set
    ```

## Missing values

A missing or empty key gives the default. With no default:

- `String` gives an empty string `''`. It is never the text `"null"`.
- `String?` and `dynamic` give `null`.
- `int`, `num`, `double` and `bool` throw an `ArgumentError` with the key name. A value that is not a number throws too.

!!! warning "APP_KEY"
    When `APP_KEY` is empty and `APP_ENV=production`, `Dox().startServer()` stops with an error.
    In other environments it logs a warning. Make a key with `dox key:generate`.

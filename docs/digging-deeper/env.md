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
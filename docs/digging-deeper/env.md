# Environment Variables

Dox allows you to access the environment variables from `.env` using `Env` class.

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
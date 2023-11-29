# Environment Variables

Dox allows you to access the environment variables from `.env` using `Env` class.

=== "Example"

    ```dart
    Evn.get('APP_KEY');

    // With default values
    Evn.get('APP_KEY', 'default_value');
    ```
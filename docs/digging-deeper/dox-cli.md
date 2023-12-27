# Dox CLI

Dox has a CLI tool to generate migration, model and to handle database migration which support up and down methods to control migration version.

## Installation

```py
dart pub global activate dox
```

!!! warning "Export bin path"
    Please make sure you have included `bin` path to your profile. If you did not added path to your profile yet, open `~/.bashrc` or `~/.zshrc` and paste below line.
    
    ```bash
    export PATH="$PATH":"~/.pub-cache/bin"
    ```

## Update package

```py
dox update
```

## Crete new project

```py
dox create new_blog
```

## Serve project

Run http server.

```py
dox serve 
or 
dox s

dox s --ignore-build-runner // ignore build runner watch
```

## Run build runner

```py
dox build_runner:watch
dox build_runner:build
```

## Build project for production

```py
dox build (compile into machine code)
bin/server (run exec file to serve http server)
```

## Generate app key

```py
dox key:generate
```

## Create controller

=== "Default"

    ```py
    dox create:controller admin_controller
    ```

=== "Resource controller"

    ```py
    dox create:controller admin_controller -r
    ```

=== "Websocket controller"

    ```py
    dox create:controller admin_controller -ws
    ```

## Create middleware

```py
dox create:middleware auth_middleware
```

## Create migration

```py
dox create:migration create_foo_table
```

## Create model

=== "Default"

    ```py
    dox create:model ModelName
    ```

=== "With migration"

    ```py
    dox create:model ModelName -m
    ```

## Run migration

```py
dox migrate
```

!!! info 
    To run migration, make sure that you have create `.env` file with with below variable names.

```py
DB_HOST=localhost
DB_PORT=5432
DB_NAME=postgres
DB_USERNAME=admin
DB_PASSWORD=password
```

## Rollback migration

```py
dox migrate:rollback
```

## Deactivate CLI

```py
dart pub global deactivate dox
```
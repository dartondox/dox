# Contribute 

Want to contribute? Great! Fork the repo and create PR to us.

# Setting up local development

#### 1. Clone repo

```py
git clone git@github.com:dartondox/dox.git
```

#### 2. Install melos if not installed 

```py
dart pub global activate melos
```

#### 3. Run melos bootstrap

```py
melos bs
```

#### 4. Other Useful Commands

```py
# Run all tests
melos run test

# Run tests for dox_query_builder with postgres
melos run test_query_builder_postgres

# Run tests for dox_query_builder with mysql
melos run test_query_builder_mysql

# Generate dox cli executable file
cd packages/dox-cli
dart compile exe bin/dox.dart -o bin/dox

# Run dox cli executable file
bin/dox --version
```

#### If failed to run the project

- remove all pubspec.lock files
- and run `melos bs` again

# Query builder

### v1.1.15

- Bug fixed on toMap

### v1.1.14

- Bug fixed on eager/preload data missing in `toMap` response.
- Bug fixed on `deleted_at` column conflict.
- Support for `withTrash` chain on any query builder function.

### v1.1.13

- Update readme
- bug fixed on count() with order by

### v1.1.12

- Add support for paginate() function
- Add support for query printer, file printer, consoler printer and pretty printer.

### v1.1.11

- Add missing types on function and arguments
- Bug fixed on count, custom query

### v1.1.10

- Remove hidden fields on toJson

### v1.1.9

- Bug fixed on jsonEncode(Model)

### v1.1.8

- Update readme

### v1.1.7

- Add option in `toMap()` to remove hidden fields

### v1.1.6

- Create own annotation and builder
- Added belongsTo support
- Added hasOne support
- Added hasMany support
- Added manyToMany support
- Added eager loading support

### v1.0.11

- Bug fixed id null on save

### v1.0.10

- Bug fixed on debug option in model
- Bug fixed on debug query param missing
- Support Postgres Pool
- Support hidden fields in model

### v1.0.1

- Update documentation

### v1.0.0

- Initial release

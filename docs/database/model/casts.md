# Attribute casts

A cast changes a column value between the database and Dart.
For example, it reads JSON text as a map, or saves an enum by its name.
Casts work the same on Postgres, MySQL, MariaDB and SQLite.

Set a cast with `cast` on `@Column()`. Then run `dart run build_runner build`.

```dart
enum Status { draft, live }

enum Level { low, mid, high }

@DoxModel()
class Item extends ItemGenerator {
  @Column(cast: JsonCast())
  Map<String, dynamic>? meta;

  @Column(cast: ListCast<String>())
  List<String>? tags;

  @Column()
  bool? active; // gets BoolCast()

  @Column()
  Status? status; // gets EnumCast(Status.values)

  @Column(cast: EnumCast<Level>(Level.values, byIndex: true))
  Level? level;
}
```

The cast runs when a row is read (`get()`, `find()` and others),
when the model is saved, and in `toJson()`.

## Built-in casts

| Cast | Dart value | Database value |
|---|---|---|
| `JsonCast()` | a map or a list | JSON, or JSON in a text column |
| `ListCast<E>()` | a typed list, like `List<String>` | JSON, or JSON in a text column |
| `BoolCast()` | `bool` | boolean, or a number like `tinyint` (0 is false), or the text `1`, `0`, `true`, `false`, `t`, `f` |
| `EnumCast<E>(E.values)` | an enum | text with the enum name |
| `EnumCast<E>(E.values, byIndex: true)` | an enum | a number, the enum index |

You do not need `cast` for two field types:

- A `bool` field gets `BoolCast()`.
- An enum field gets `EnumCast(values)`, so it is saved by its name.

`DateTime` fields need no cast either. Dox reads them on every database.

!!! info
    A cast changes the values of a model. It does not change a `where()` value.
    Use the database value there, like `where('status', Status.live.name)`.

## Your own cast

Extend `Cast<T>`. `get()` gets the database value and returns the Dart value.
`set()` gets the Dart value and returns the value to save.
The class needs a const constructor.

```dart
class Money {
  final int cents;
  const Money(this.cents);
}

class MoneyCast extends Cast<Money> {
  const MoneyCast();

  @override
  Money? get(dynamic value) => value == null ? null : Money(value as int);

  @override
  dynamic set(Money? value) => value?.cents;
}

@DoxModel()
class Product extends ProductGenerator {
  @Column(cast: MoneyCast())
  Money? price;
}
```

A cast can take const arguments, like `EnumCast` does.
The generator copies the `cast` code into the generated file,
so the names in it must be imported in the model file.

A column with `beforeGet` does not use its cast.

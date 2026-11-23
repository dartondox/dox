---
icon: lucide/replace
---

# Attribute casts

A cast changes a column value between the database and Dart, for example to read JSON text as a map or to save an enum by its name.

Casts work the same on Postgres, MySQL, MariaDB and SQLite. A cast runs when a row is read (`get()`, `find()` and others), when the model is saved, and in `toJson()`.

## Defining casts

Set a cast with `cast` on `@Column()`, then run `dart run build_runner build`:

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

A `bool` field gets `BoolCast()` and an enum field gets `EnumCast(values)` by itself, so you do not need `cast` for them. `DateTime` fields need no cast either.

A cast does not change a `where()` value, so use the database value there:

```dart
where('status', Status.live.name)
```

## Built-in casts

| Cast | Dart value | Database value |
|---|---|---|
| `JsonCast()` | a map or a list | JSON, or JSON in a text column |
| `ListCast<E>()` | a typed list, like `List<String>` | JSON, or JSON in a text column |
| `BoolCast()` | `bool` | boolean, or a number like `tinyint` (0 is false), or the text `1`, `0`, `true`, `false`, `t`, `f` |
| `EnumCast<E>(E.values)` | an enum | text with the enum name |
| `EnumCast<E>(E.values, byIndex: true)` | an enum | a number, the enum index |

## Unknown enum values

A row can hold a value that the enum does not have, like an old name `archived`, or an index out of range. One such row does not fail the query.

- A nullable field reads it as `null`. The ORM logs one `[db]` warning for each table, column and value.
- A field that can not be null throws a `StateError` that names the column and the stored value.

To get a value of your own instead of `null`, give `unknown`. It works for a field that can not be null too:

```dart
@Column(cast: EnumCast(Status.values, unknown: Status.draft))
Status status = Status.draft;
```

Saving the model does not overwrite the stored value. Setting the field back to the value it read (`null`, or the `unknown` value) does not change it either. To replace a bad stored value, set a real enum value.

This is only for rows from the database. A value you give to `create()`, `firstOrNew()` or `updateOrCreate()` must be a name (or an index) of the enum, or it throws an `ArgumentError`.

## Custom casts

If no built-in cast fits, write your own. Extend `Cast<T>`: `get()` gets the database value and returns the Dart value, and `set()` gets the Dart value and returns the value to save. The class needs a const constructor:

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

A cast can take const arguments, like `EnumCast` does. The generator copies the `cast` code into the generated file, so the names in it must be imported in the model file.

## Details

- A column with `beforeGet` does not use its cast.

## See also

- [Model](index.md): the model basics.
- [Serializer](../../the-basic/serializer.md): set the JSON shape of a model.

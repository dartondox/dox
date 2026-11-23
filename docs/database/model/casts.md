---
icon: lucide/replace
---

# Attribute casts

A cast changes a column value between the database and Dart, for example to read JSON text as a map or to save an enum by its name.

A cast runs when a row is read, when the model is saved, and in `toJson()`. Casts work the same on Postgres, MySQL, MariaDB and SQLite.

## Defining casts

Set a cast with `cast` on `@Column()`, then run `dart run build_runner build`:

```dart
@DoxModel()
class Item extends ItemGenerator {
  @Column(cast: JsonCast())
  Map<String, dynamic>? meta;

  @Column(cast: ListCast<String>())
  List<String>? tags;

  @Column(cast: EnumCast<Level>(Level.values, byIndex: true))
  Level? level;
}
```

A bool field gets `BoolCast()` and an enum field gets `EnumCast(values)` by itself. A column with `beforeGet` does not use its cast.

A cast does not change a `where()` value, so use the database value there:

```dart
where('status', Status.live.name)
```

## Built-in casts

| Cast | Dart value | Database value |
|---|---|---|
| `JsonCast()` | a map or a list | JSON, or JSON in a text column |
| `ListCast<E>()` | a typed list, like `List<String>` | JSON, or JSON in a text column |
| `BoolCast()` | a bool | boolean, a number (0 is false), or the text 1, 0, true, false, t, f |
| `EnumCast<E>(E.values)` | an enum | text with the enum name |
| `EnumCast<E>(E.values, byIndex: true)` | an enum | a number, the enum index |

## Unknown enum values

A stored value that the enum does not have reads as null, with one warning in the log. Give `unknown` to read it as a value of your own:

```dart
@Column(cast: EnumCast(Status.values, unknown: Status.draft))
Status status = Status.draft;
```

A field that can not be null and has no `unknown` throws a `StateError`. A save does not overwrite the stored value, unless you set a real enum value.

## Custom casts

Extend `Cast<T>`. `get()` changes the database value to the Dart value, and `set()` changes it back. The class needs a const constructor:

```dart
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

The generator copies the `cast` code into the generated file, so import the names it uses in the model file.

## Next steps

- [Model](index.md): the column types of a model.
- [Serializer](../../the-basic/serializer.md): set the JSON shape of a model.

---
icon: lucide/workflow
---

# ManyToMany

Use `ManyToMany` when rows on both sides can have many rows on the other side.

For example, an artist has many songs, and a song has many artists.

The link is kept in a third table, the pivot table.
It has one foreign key to each side.

## Tables

| Table | Columns |
|---|---|
| `artist` | `id`, `name` |
| `song` | `id`, `title` |
| `artist_song` (pivot) | `id`, `artist_id`, `song_id` |

A migration for the pivot table:

```dart
await schema.create('artist_song', (Table table) {
  table.id();
  table.foreignId('artist_id').constrained('artist').cascadeOnDelete();
  table.foreignId('song_id').constrained('song').cascadeOnDelete();
});
```

## Define it

Add a field with `@ManyToMany(...)` to each model that needs it.
The field type is a list of the related model. Start it as an empty list.

```dart title="lib/app/models/artist/artist.model.dart"
import 'package:dox_orm/dox_orm.dart';

import '../song/song.model.dart';

part 'artist.model.g.dart';

@DoxModel()
class Artist extends ArtistGenerator {
  @Column()
  String? name;

  @ManyToMany(Song)
  List<Song> songs = <Song>[];
}
```

```dart title="lib/app/models/song/song.model.dart"
import 'package:dox_orm/dox_orm.dart';

import '../artist/artist.model.dart';

part 'song.model.g.dart';

@DoxModel()
class Song extends SongGenerator {
  @Column()
  String? title;

  @ManyToMany(Artist)
  List<Artist> artists = <Artist>[];
}
```

Run `dart run build_runner build` after you add a relationship.

## Load it

The relation is not loaded by default. Load it in one of these ways.
Use the field name (`'songs'`) as the relation name.

### `preload`

Use it when you load the models with a query.

```dart
Artist? artist = await Artist().preload('songs').find(1);
print(artist?.songs.length);

List<Song> songs = await Song().preload('artists').get();
```

`preload` works with `find`, `get`, `all` and `getFirst`.
For a list of models, it runs one query for all of them.
A model without links gets an empty list.

### `$getRelation`

Use it when you already have the model.

```dart
Artist? artist = await Artist().find(1);
await artist?.$getRelation('songs');
print(artist?.songs.length);
```

### `related`

Use it when you need more conditions on the related rows.

```dart
Artist? artist = await Artist().find(1);
List<Song> songs = await artist
        ?.related<Song>('songs')
        ?.orderBy('song.title')
        .get() ??
    <Song>[];
```

It does not set `artist.songs`.
The query joins the pivot table, so write `table.column` for column names.

### `eager`

Use it when every query of `Artist` should load the relation.

```dart
@ManyToMany(Song, eager: true)
List<Song> songs = <Song>[];
```

You do not call `preload`.
Do not set `eager: true` on both sides. Each side would load the other side again and again.

The load runs this SQL:

```sql
SELECT "song".*, "artist_song"."artist_id" as "_owner_id" FROM "song"
  LEFT JOIN "artist_song" on "artist_song"."song_id" = "song"."id"
  WHERE "artist_song"."artist_id" IN (@artist_songartist_id_p0, ...)
```

With `withPivot` or `withTimestamps`, it also selects those pivot columns, like `"artist_song"."role" as "_pivot_role"`.

## Read pivot columns

The pivot table can have more columns, like a `role`.
List them in `withPivot`.
Read them with `pivot` on each related model.

```dart
@ManyToMany(Song, withPivot: <String>['role'])
List<Song> songs = <Song>[];
```

```dart
Artist? artist = await Artist().preload('songs').find(1);
for (Song song in artist!.songs) {
  print(song.pivot['role']);
}
```

- `pivot` has the two pivot keys, like `artist_id` and `song_id`, when the rows are loaded by the relation:
  with `preload`, `$getRelation`, `eager` or `related('songs')!.get()`.
  They are read from the loaded rows, so a relation without `withPivot` runs no extra SQL.
- `withTimestamps: true` adds `created_at` and `updated_at` to `pivot`.
  `attach()`, `sync()` and `toggle()` then set them.
  `updateExistingPivot()` sets `updated_at`.
  The pivot table needs both columns (`table.timestamps()`).
- A model that was not loaded by a ManyToMany relation has an empty `pivot`.
- `pivot` is not in `toJson()`. Read it in Dart and add it to your response yourself.

## Change the links

These methods add and remove rows in the pivot table.
The first argument is the relation name, like `'songs'`.
Save the model first. A model without an id throws a `StateError`.

The ids can be:

- one id: `1`
- a model: `song`
- a list of ids or models: `[1, 2, song]`
- a map of `id => pivot values`: `{1: {'role': 'singer'}, 2: {}}`

`null` means no ids. So `attach('songs', null)` and `detach('songs', null)` change nothing, and `sync('songs', null)` deletes every link, like `sync('songs', [])`.
Ids match with one rule:

- Two texts only match when the text is the same.
  So on a text key column, `'007'` and `'7'` are two ids.
  The ORM does not know the type of the key column, so `attach('songs', ['1', '01'])` adds two rows.
- When one id is a number (`int` or `double`), Dart reads the other one as a number.
  It trims the text, drops a `.0` end, and tries `int.tryParse` (`' 1'`, `'+1'`, `'01'`, `'1.0'`), then `double.tryParse` (`'1.'`, `'1e0'`).
  They match when the two numbers are the same.
  Rows of a number key column come back as numbers, so `sync('songs', ['01'])` keeps the row of song `1`.
- This is only how Dart matches ids. The databases read some texts in other ways.
  For example, `'0x1'` is `1` in Dart and on Postgres, `0` on MariaDB, and an error on MySQL.
  Postgres throws for `'1.0'`, `'1.'` and `'1e0'` on an integer column.
- A given text that only reads as a number at or past ±2^53, like `'1e20'` or `'9007199254740993.'`, is not exact.
  It throws an `ArgumentError` when it is matched to a number.
  `sync` checks every id before its first write.
- A stored value never throws. A value in the table that can not be read exactly does not match a number.
  So a long digit text in a text key column does not stop `sync`.
- A bool id is `1` or `0`, like the databases read it. So `sync('songs', true)` keeps the row of song `1`.
- A `BigInt` id is an `int` when it fits, else it throws an `ArgumentError`. Any other id type that is not an `int`, a `String`, a `bool`, a `double` or a model throws an `ArgumentError`.
- Each id finds its own stored row when it can. A row with the same text wins, so on a text key `1` finds `'1'`, not `'01'`.
  A stored row is matched once, so on a number key `toggle('songs', ['1', '01'])` detaches song `1` once.
- `detach` and `updateExistingPivot` send every given id.
  So on a text key, `detach('songs', [1, '01'])` deletes both rows.
- `sync` deletes a stored row only when none of the given ids matches it.
  So on a text key, `sync('songs', [1, '01'])` keeps the rows `'1'` and `'01'`.
- A new row is added once for ids that are the same by this rule, and the first id wins.
  So on a number key `attach('songs', [1, '01'])` adds one row. On a text key it adds only the row `1`.
- A whole double within ±2^53, like `2.0`, is sent as the int `2`.
  Any other double, like `1.5`, NaN, infinity or `1e20`, throws an `ArgumentError`.
- Text ids are sent to the database as they are.

A `null` id or a model that is not saved is skipped by `attach`, `detach`, `toggle`, `syncWithoutDetaching` and `updateExistingPivot`.
`sync` throws an `ArgumentError` for one, before it changes anything, because it would delete every other link.
Each id is used once: `[1, 1, '1']` adds one row.

### `attach`

Adds a pivot row for each id.
The third argument has the pivot values for every new row.

```dart
await artist.attach('songs', 1);
await artist.attach('songs', <int>[2, 3], <String, dynamic>{'role': 'singer'});
await artist.attach('songs', <int, Map<String, dynamic>>{
  4: <String, dynamic>{'role': 'writer'},
});
```

`attach` does not check for a row that is already there.
Use `sync` or `syncWithoutDetaching` when the row may be there.

### `detach`

Deletes the pivot rows of the ids.
With no ids argument, it deletes every pivot row of the model.
`detach('songs', null)` deletes nothing.
It returns how many rows it deleted.
The songs stay in the `song` table.

```dart
await artist.detach('songs', <int>[1, 2]);
await artist.detach('songs');
```

### `sync`

Makes the pivot rows match the ids.

- It adds a row for each new id.
- It deletes the rows of the ids that are not in the list.
- It sets the pivot values of the rows that are already there, when a value changed. `updated` has those ids.

It returns a `PivotSyncResult` with the ids of each change.
A number id is an `int` in the result, also when you gave `'3'`.
A text that is not the plain text of an int, like `'03'` or `'007'`, stays text.

```dart
PivotSyncResult result = await artist.sync('songs', <int>[1, 2, 3]);
print(result.attached); // ids that got a new row
print(result.detached); // ids whose row was deleted
print(result.updated);  // ids whose pivot values changed
```

`syncWithoutDetaching` does the same, but it does not delete rows.

```dart
await artist.syncWithoutDetaching('songs', <int>[4]);
```

### `toggle`

Adds a row for each id that has none.
Deletes the row of each id that has one.
It returns a `PivotSyncResult` with `attached` and `detached`.

```dart
await artist.toggle('songs', <int>[1, 2]);
```

### `updateExistingPivot`

Sets pivot values on the rows of one id or a list of ids.
It returns how many rows changed.

```dart
await artist.updateExistingPivot('songs', 1, <String, dynamic>{'role': 'writer'});
```

## Filter by it

`whereHas()` keeps the artists that have a song.
It checks the pivot table `artist_song` for you.
It does not load the songs.

```dart
List<Artist> artists = await Artist().whereHas('songs', (QueryBuilder<dynamic> q) {
  q.where('title', 'Yesterday');
}).get();

List<Artist> noSongs = await Artist().whereDoesntHave('songs').get();
```

See [Query by relations](../relation-queries.md).

## Options

The examples are for `@ManyToMany(Song)` in the `Artist` model.

| Option | Default | Example value | What it is |
|---|---|---|---|
| `pivotTable` | the two model names in A-Z order, joined with `_` | `artist_song` | The pivot table. |
| `pivotForeignKey` | `{this model}_id` | `artist_id` | The pivot column that points to this model. |
| `pivotRelatedForeignKey` | `{related model}_id` | `song_id` | The pivot column that points to the related model. |
| `localKey` | the primary key of this model | `id` | The column in `artist` that `pivotForeignKey` points to. |
| `relatedKey` | the primary key of the related model | `id` | The column in `song` that `pivotRelatedForeignKey` points to. |
| `withPivot` | none | `['role']` | Extra pivot columns to read. See [Read pivot columns](#read-pivot-columns). |
| `withTimestamps` | `false` | `true` | Read and set `created_at` and `updated_at` in the pivot table. |
| `onQuery` | none | | A static function that changes the query. |
| `eager` | `false` | | Load the relation on every query. |

The defaults use the class names in snake_case, not the table names.
So `@DoxModel(table: 'artists')` does not change them.

- `Artist` and `Song` give `artist_song`.
- `Blog` and `Category` give `blog_category`.
- `BlogPost` and `Tag` give `blog_post_tag`.

### Set all keys

```dart
@ManyToMany(
  Song,
  pivotTable: 'artist_song',
  pivotForeignKey: 'artist_id',
  pivotRelatedForeignKey: 'song_id',
  localKey: 'id',
  relatedKey: 'id',
)
List<Song> songs = <Song>[];
```

### `onQuery`

`onQuery` is a static function in the same model class.
It gets the query of the related model and returns it.

```dart
@DoxModel()
class Artist extends ArtistGenerator {
  @ManyToMany(Song, onQuery: onlyPublished)
  List<Song> songs = <Song>[];

  static QueryBuilder<Song> onlyPublished(Song q) {
    return q.where('song.status', 'published');
  }
}
```

## In JSON

- A relation with `eager: true` is always in `toJson()`.
- A relation loaded with `preload` is in `toJson()` of that query.
- The JSON key is the field name in snake_case: `songs`.

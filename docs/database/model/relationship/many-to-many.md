---
icon: lucide/workflow
---

# ManyToMany

Use `ManyToMany` when rows on both sides can have many rows on the other side.

For example, an artist has many songs, and a song has many artists. The link is kept in a third table, the pivot table. It has one foreign key to each side.

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

By default the pivot table name is the two class names in snake_case, in A-Z order, joined with `_`. So `Artist` and `Song` give `artist_song`, and `BlogPost` and `Tag` give `blog_post_tag`. The table names of the models do not change this.

## Defining the relation

Add a field with `@ManyToMany(...)` to each model that needs it. The field type is a list of the related model. Start it as an empty list:

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

### Custom keys

If your pivot table or columns have other names, set them:

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

## Loading the relation

The relation is not loaded by default. Use the field name (`'songs'`) as the relation name.

### Preloading

Use `preload` when you load the models with a query. For a list of models, it runs one query for all of them. A model without links gets an empty list:

```dart
Artist? artist = await Artist().preload('songs').find(1);
print(artist?.songs.length);

List<Song> songs = await Song().preload('artists').get();
```

`preload` works with `find`, `get`, `all` and `getFirst`.

### Loading on a model you have

If you already have the model, use `$getRelation`:

```dart
Artist? artist = await Artist().find(1);
await artist?.$getRelation('songs');
print(artist?.songs.length);
```

### Querying the relation

Sometimes you need more conditions on the related rows. `related` gives you a query for them. It does not set `artist.songs`.

The query joins the pivot table, so write `table.column` for column names:

```dart
Artist? artist = await Artist().find(1);
List<Song> songs = await artist
        ?.related<Song>('songs')
        ?.orderBy('song.title')
        .get() ??
    <Song>[];
```

### Always loading the relation

If every query of `Artist` should load the relation, set `eager: true`. Then you do not call `preload`. Do not set `eager: true` on both sides, because each side would load the other side again and again:

```dart
@ManyToMany(Song, eager: true)
List<Song> songs = <Song>[];
```

## Reading pivot columns

The pivot table can have more columns, like a `role`. List them in `withPivot`:

```dart
@ManyToMany(Song, withPivot: <String>['role'])
List<Song> songs = <Song>[];
```

Then read them with `pivot` on each related model:

```dart
Artist? artist = await Artist().preload('songs').find(1);
for (Song song in artist!.songs) {
  print(song.pivot['role']);
}
```

`pivot` also has the two pivot keys, like `artist_id` and `song_id`. It is filled when the rows are loaded by the relation: with `preload`, `$getRelation`, `eager` or `related('songs')!.get()`. A model that was not loaded by the relation has an empty `pivot`.

### Pivot timestamps

If you want `created_at` and `updated_at` on the pivot rows, set `withTimestamps: true`. The pivot table needs both columns (`table.timestamps()`). Then `attach()`, `sync()` and `toggle()` set them, and `updateExistingPivot()` sets `updated_at`.

## Changing the links

These methods add and remove rows in the pivot table. The first argument is the relation name, like `'songs'`. Save the model first, because a model without an id throws a `StateError`.

The ids can be:

- one id: `1`
- a model: `song`
- a list of ids or models: `[1, 2, song]`
- a map of `id => pivot values`: `{1: {'role': 'singer'}, 2: {}}`

Each id is used once, so `[1, 1, '1']` adds one row.

### Attaching

`attach` adds a pivot row for each id. The third argument has the pivot values for every new row:

```dart
await artist.attach('songs', 1);
await artist.attach('songs', <int>[2, 3], <String, dynamic>{'role': 'singer'});
await artist.attach('songs', <int, Map<String, dynamic>>{
  4: <String, dynamic>{'role': 'writer'},
});
```

`attach` does not check for a row that is already there. If the row may be there, use `sync` or `syncWithoutDetaching`.

### Detaching

`detach` deletes the pivot rows of the ids and returns how many rows it deleted. With no ids argument, it deletes every pivot row of the model. The songs stay in the `song` table:

```dart
await artist.detach('songs', <int>[1, 2]);
await artist.detach('songs');
```

### Syncing

`sync` makes the pivot rows match the ids. It adds a row for each new id, deletes the rows of the ids that are not in the list, and sets changed pivot values on the rows that are already there.

It returns a `PivotSyncResult` with the ids of each change:

```dart
PivotSyncResult result = await artist.sync('songs', <int>[1, 2, 3]);
print(result.attached); // ids that got a new row
print(result.detached); // ids whose row was deleted
print(result.updated);  // ids whose pivot values changed
```

If you only want to add links and never delete, use `syncWithoutDetaching`:

```dart
await artist.syncWithoutDetaching('songs', <int>[4]);
```

### Toggling

`toggle` adds a row for each id that has none, and deletes the row of each id that has one. It returns a `PivotSyncResult` with `attached` and `detached`:

```dart
await artist.toggle('songs', <int>[1, 2]);
```

### Updating pivot values

`updateExistingPivot` sets pivot values on the rows of one id or a list of ids. It returns how many rows changed:

```dart
await artist.updateExistingPivot('songs', 1, <String, dynamic>{'role': 'writer'});
```

## Filtering by the relation

`whereHas()` keeps the artists that have a song. It checks the pivot table `artist_song` for you, and it does not load the songs:

```dart
List<Artist> artists = await Artist().whereHas('songs', (QueryBuilder<dynamic> q) {
  q.where('title', 'Yesterday');
}).get();

List<Artist> noSongs = await Artist().whereDoesntHave('songs').get();
```

See [Query by relations](../relation-queries.md).

## Changing the relation query

Sometimes the relation should only load some rows. Give `onQuery` a static function in the same model class. It gets the query of the related model and returns it. Write `table.column`, because the query joins the pivot table:

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

## Details

### All options

The examples are for `@ManyToMany(Song)` in the `Artist` model.

| Option | Default | Example value | What it is |
|---|---|---|---|
| `pivotTable` | the two model names in A-Z order, joined with `_` | `artist_song` | The pivot table. |
| `pivotForeignKey` | `{this model}_id` | `artist_id` | The pivot column that points to this model. |
| `pivotRelatedForeignKey` | `{related model}_id` | `song_id` | The pivot column that points to the related model. |
| `localKey` | the primary key of this model | `id` | The column in `artist` that `pivotForeignKey` points to. |
| `relatedKey` | the primary key of the related model | `id` | The column in `song` that `pivotRelatedForeignKey` points to. |
| `withPivot` | none | `['role']` | Extra pivot columns to read. See [Reading pivot columns](#reading-pivot-columns). |
| `withTimestamps` | `false` | `true` | Read and set `created_at` and `updated_at` in the pivot table. |
| `onQuery` | none | | A static function that changes the query. |
| `eager` | `false` | | Load the relation on every query. |

### Null and unsaved ids

- `null` means no ids. So `attach('songs', null)` and `detach('songs', null)` change nothing, and `sync('songs', null)` deletes every link, like `sync('songs', [])`.
- In a list, a `null` id or a model that is not saved is skipped by `attach`, `detach`, `toggle`, `syncWithoutDetaching` and `updateExistingPivot`.
- `sync` throws an `ArgumentError` for one, before it changes anything, because it would delete every other link.

### How ids match

- Two texts only match when the text is the same. So on a text key column, `'007'` and `'7'` are two ids.
- When one id is a number, Dart reads the other one as a number too. So on a number key column, `'01'` matches song `1`.
- A bool id is `1` or `0`. A whole double like `2.0` is sent as the int `2`. A `BigInt` that fits is an `int`.
- Other doubles (like `1.5`), a text number at or past ±2^53, a `BigInt` that does not fit, and any other type throw an `ArgumentError`. `sync` checks every id before its first write.
- In `PivotSyncResult`, a number id is an `int`, also when you gave `'3'`. A text like `'03'` stays text.
- On a text key that ignores case (MySQL and MariaDB by default, SQLite with `COLLATE NOCASE`), `sync` and `toggle` also ask the database about text ids that Dart did not match. So with a stored `'ABC'`, `sync('songs', ['abc'])` keeps that row.
- Text ids are sent to the database as they are. The database may read some texts in its own way, for example `'0x1'`.

### Other cases

- `toJson()` of a model loaded by a ManyToMany relation has a `pivot` key. Dates are ISO text. Put `'pivot'` in `hidden` to leave it out. If the model has its own `pivot` column, the key keeps the column value.
- A relation with `eager: true` is always in `toJson()`. A relation loaded with `preload` is in `toJson()` of that query. The JSON key is the field name in snake_case: `songs`.
- `reload()` and a preload set the relation fields again, also when there is no related row. See [Relationships](../index.md#relationships).
- The load runs one query like this. With `withPivot` or `withTimestamps`, it also selects those pivot columns, like `"artist_song"."role" as "_pivot_role"`:

```sql
SELECT "song".*, "artist_song"."artist_id" as "_owner_id" FROM "song"
  LEFT JOIN "artist_song" on "artist_song"."song_id" = "song"."id"
  WHERE "artist_song"."artist_id" IN (@artist_songartist_id_p0, ...)
```

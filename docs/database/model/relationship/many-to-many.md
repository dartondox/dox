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

`null` means no ids, and a `null` id is skipped. So `attach('songs', null)` adds nothing, and `sync('songs', null)` deletes every link, like `sync('songs', [])`.
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
With no ids, it deletes every pivot row of the model.
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

It returns a `SyncResult` with the ids of each change.

```dart
SyncResult result = await artist.sync('songs', <int>[1, 2, 3]);
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
It returns a `SyncResult` with `attached` and `detached`.

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

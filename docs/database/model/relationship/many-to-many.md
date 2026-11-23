---
icon: lucide/workflow
---

# ManyToMany

Use `ManyToMany` when rows on both sides can have many rows on the other side.

For example, an artist has many songs, and a song has many artists. A third table, the **pivot table**, keeps the links. It has one foreign key to each side.

## Setup

### Tables

| Table | Columns |
|---|---|
| `artist` | `id`, `name` |
| `song` | `id`, `title` |
| `artist_song` (pivot) | `id`, `artist_id`, `song_id` |

The default pivot table name is the two class names in snake_case, in A-Z order, joined with `_`. A migration for it:

```dart
await schema.create('artist_song', (Table table) {
  table.id();
  table.foreignId('artist_id').constrained('artist').cascadeOnDelete();
  table.foreignId('song_id').constrained('song').cascadeOnDelete();
});
```

### Defining the relation

Add a list field with `@ManyToMany()` to each model that needs it, and start it as an empty list:

```dart title="lib/app/models/artist/artist.model.dart"
@DoxModel()
class Artist extends ArtistGenerator {
  @ManyToMany(Song)
  List<Song> songs = <Song>[];
}

@DoxModel()
class Song extends SongGenerator {
  @ManyToMany(Artist)
  List<Artist> artists = <Artist>[];
}
```

Run `dart run build_runner build` after you add a relation.

### Options

Set the names when your pivot table or columns have other names:

```dart
@ManyToMany(
  Song,
  pivotTable: 'artist_song',
  pivotForeignKey: 'artist_id',
  pivotRelatedForeignKey: 'song_id',
)
List<Song> songs = <Song>[];
```

The examples are for `@ManyToMany(Song)` in the `Artist` model:

| Option | Default | What it is |
|---|---|---|
| `pivotTable` | the two class names in A-Z order, like `artist_song` | The pivot table. |
| `pivotForeignKey` | `{this model}_id`, like `artist_id` | The pivot column that points to this model. |
| `pivotRelatedForeignKey` | `{related model}_id`, like `song_id` | The pivot column that points to the related model. |
| `localKey` | the primary key of this model | The column in `artist` that `pivotForeignKey` points to. |
| `relatedKey` | the primary key of the related model | The column in `song` that `pivotRelatedForeignKey` points to. |
| `withPivot` | none | More pivot columns to read, like `['role']`. |
| `withTimestamps` | `false` | Read and set `created_at` and `updated_at` in the pivot table. |
| `onQuery` | none | A static function that changes the query. |
| `eager` | `false` | Load the relation on every query. |

## Loading the relation

The relation is not loaded by default. Use the field name, `'songs'`, as the relation name.

### Preloading

`preload()` loads the relation for all models of a query, with one more query. A model with no links gets an empty list:

```dart
Artist? artist = await Artist().preload('songs').find(1);
print(artist?.songs.length);
```

The relation is then in `toJson()`, with the field name in snake_case as the key.

### Loading on a model you have

`$getRelation()` loads the relation into the field:

```dart
await artist.$getRelation('songs');
```

### Querying the relation

`related()` gives a query for the related rows. It does not set the field. The query joins the pivot table, so write `table.column`:

```dart
List<Song> songs = await artist
        .related<Song>('songs')
        ?.orderBy('song.title')
        .get() ??
    <Song>[];
```

### Always loading the relation

Set `eager: true` to load the relation on every query of the model. Do not set it on both sides, because each side then loads the other side again and again:

```dart
@ManyToMany(Song, eager: true)
List<Song> songs = <Song>[];
```

### Reading pivot columns

List the pivot columns in `withPivot`, then read them with `pivot` on each related model:

```dart
@ManyToMany(Song, withPivot: <String>['role'])
List<Song> songs = <Song>[];

for (Song song in artist.songs) {
  print(song.pivot['role']);
}
```

`pivot` is empty on a model that the relation did not load. `toJson()` has a `pivot` key. Put `'pivot'` in `hidden` to leave it out.

## Saving related models

These methods add and remove pivot rows. Save the model first, because a model with no key throws a `StateError`.

The ids can be one id, a model, a list of ids or models, or a map of `id => pivot values`. Each id is used once.

### Attaching

`attach()` adds a pivot row for each id. The third argument has the pivot values for each new row:

```dart
await artist.attach('songs', 1);
await artist.attach('songs', <int>[2, 3],
    <String, dynamic>{'role': 'singer'});
await artist.attach('songs', <int, Map<String, dynamic>>{
  4: <String, dynamic>{'role': 'writer'},
});
```

`attach()` does not check for a row that is already there. Use `sync()` or `syncWithoutDetaching()` when it can be there.

### Detaching

`detach()` deletes the pivot rows of the ids and returns the number of deleted rows. With no ids, it deletes every pivot row of the model:

```dart
await artist.detach('songs', <int>[1, 2]);
await artist.detach('songs');
```

### Syncing

`sync()` makes the pivot rows match the ids. It returns a `PivotSyncResult` with the ids of each change:

```dart
PivotSyncResult result = await artist.sync('songs', <int>[1, 2, 3]);
print(result.attached); // ids that got a new row
print(result.detached); // ids whose row was deleted
print(result.updated);  // ids whose pivot values changed
```

A null id or an unsaved model in the list makes `sync()` throw an `ArgumentError`, because it would delete every other link. A null list deletes every link.

`syncWithoutDetaching()` adds links and never deletes:

```dart
await artist.syncWithoutDetaching('songs', <int>[4]);
```

### Toggling

`toggle()` adds a row for each id that has none, and deletes the row of each id that has one:

```dart
await artist.toggle('songs', <int>[1, 2]);
```

### Updating pivot values

`updateExistingPivot()` sets pivot values on the rows of one id or a list of ids. It returns the number of changed rows:

```dart
await artist.updateExistingPivot('songs', 1,
    <String, dynamic>{'role': 'writer'});
```

With `withTimestamps`, `attach()`, `sync()` and `toggle()` set the pivot timestamps, and `updateExistingPivot()` sets `updated_at`.

## Filtering by the relation

`whereHas()` keeps the artists that have a song. It checks the pivot table for you:

```dart
List<Artist> artists = await Artist().whereHas('songs',
    (QueryBuilder<dynamic> q) {
  q.where('title', 'Yesterday');
}).get();

List<Artist> noSongs = await Artist().whereDoesntHave('songs').get();
```

See [Query by relations](../relation-queries.md).

## Changing the relation query

Give `onQuery` a static function of the model. It gets the query of the related model and returns it. Write `table.column`, because the query joins the pivot table:

```dart
@ManyToMany(Song, onQuery: onlyPublished)
List<Song> songs = <Song>[];

static QueryBuilder<Song> onlyPublished(Song q) {
  return q.where('song.status', 'published');
}
```

## Next steps

- [HasMany](has-many.md): a relation with no pivot table.
- [Schema](../../schema.md): make the pivot table.
- [Counting relations](../counting-relations.md): count the related rows.

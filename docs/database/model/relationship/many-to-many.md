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

=== "Artist"

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

=== "Song"

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

=== "preload"

    ```dart
    Artist? artist = await Artist().preload('songs').find(1);
    print(artist?.songs.length);

    List<Song> songs = await Song().preload('artists').get();
    ```

    `preload` works with `find`, `get`, `all` and `getFirst`.
    For a list of models, it runs one query for all of them.
    A model without links gets an empty list.

=== "$getRelation"

    ```dart
    Artist? artist = await Artist().find(1);
    await artist?.$getRelation('songs');
    print(artist?.songs.length);
    ```

    Use it when you already have the model.

=== "related"

    ```dart
    Artist? artist = await Artist().find(1);
    List<Song> songs = await artist
            ?.related<Song>('songs')
            ?.orderBy('song.title')
            .get() ??
        <Song>[];
    ```

    `related` gives a query. You can add more conditions before you run it.
    It does not set `artist.songs`.
    The query joins the pivot table, so write `table.column` for column names.

=== "eager"

    ```dart
    @ManyToMany(Song, eager: true)
    List<Song> songs = <Song>[];
    ```

    With `eager: true`, every query of `Artist` loads the relation.
    You do not call `preload`.
    Do not set `eager: true` on both sides. Each side would load the other side again and again.

The load runs this SQL:

```sql
SELECT "song".*, "artist_song"."artist_id" as "_owner_id" FROM "song"
  LEFT JOIN "artist_song" on "artist_song"."song_id" = "song"."id"
  WHERE "artist_song"."artist_id" IN (@artist_songartist_id_p0, ...)
```

## Options

The examples are for `@ManyToMany(Song)` in the `Artist` model.

| Option | Default | Example value | What it is |
|---|---|---|---|
| `pivotTable` | the two table names in A-Z order, joined with `_` | `artist_song` | The pivot table. |
| `pivotForeignKey` | `{this table}_id` | `artist_id` | The pivot column that points to this model. |
| `pivotRelatedForeignKey` | `{related table}_id` | `song_id` | The pivot column that points to the related model. |
| `localKey` | the primary key of this model | `id` | The column in `artist` that `pivotForeignKey` points to. |
| `relatedKey` | the primary key of the related model | `id` | The column in `song` that `pivotRelatedForeignKey` points to. |
| `onQuery` | none | | A static function that changes the query. |
| `eager` | `false` | | Load the relation on every query. |

Default pivot table names:

- `artist` and `song` give `artist_song`.
- `blog` and `category` give `blog_category`.

!!! warning "Custom table names"
    The defaults use the table names, not the class names.
    With `@DoxModel(table: 'artists')`, the default pivot table is `artists_song`
    and the default `pivotForeignKey` is `artists_id`.
    Then set the options yourself.

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

!!! warning "Known issue: names with more than one word"
    For a relation without `eager: true`, `toJson()` looks for the snake_case name in the preload list.
    But `preload` needs the field name, like `'topSongs'`.
    So a preloaded `topSongs` is on the model, but it is not in `toJson()`.
    Use a one word field name, or `eager: true`, when you need it in JSON.

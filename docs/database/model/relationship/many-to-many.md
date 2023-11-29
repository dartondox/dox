# ManyToMany

A "many-to-many" relationship is a powerful concept in database design, often used to represent complex associations between entities. Consider a scenario where we have an `Artist` model and a `Song` model. To represent the fact that each artist can have multiple songs, and each song can have multiple artists, we establish a "many-to-many" relationship.

To achieve this, we typically create an intermediary table, often referred to as a "pivot" or "junction" table, which contains foreign keys referencing both the `Artist` and `Song` models. This table captures the relationships between artists and songs.

=== "ManyToMany Class Structure"

    ```dart
    class ManyToMany {
        final Type model;
        final Function? onQuery;
        final bool? eager;
        final String? localKey;
        final String? relatedKey;
        final String? pivotForeignKey;
        final String? pivotRelatedForeignKey;
        final String? pivotTable;

        const ManyToMany(
            this.model, {
            this.eager,
            this.onQuery,
            this.localKey,
            this.relatedKey,
            this.pivotForeignKey,
            this.pivotRelatedForeignKey,
            this.pivotTable,
        });
    }
    ```

#####
=== "Artist Model"

    ```dart
    @DoxModel()
    class Artist extends ArtistGenerator {
        @column()
        String name;

        @ManyToMany(Song)
        List<Song> songs = [];
    }
    ```

=== "Song Model"

    ```dart
    @DoxModel()
    class Song extends SongGenerator {
        @column()
        String name;

        @ManyToMany(Artist)
        List<Artist> artists = [];
    }
    ```

=== "Pivot table"

    ```
    Table Name -> artist_song

    ----------------------
    Columns
    ----------------------
    id               int
    artist_id        int
    song_id          int
    ----------------------
    ```


## Usage

#### `$getRelation`

=== "Artist"

    ```dart
    Artist? artist = await Artist().find(1);
    await artist?.$getRelation('songs')

    List<Song> songs = artist?.songs;
    ```

=== "Song"

    ```dart
    Song? song = await Song().find(1);
    await song?.$getRelation('artists')

    List<Artist> artists = song?.artists;
    ```

!!! info
    When `eager` is `true` the `$getRelation` do not need to call.

#### `preload`

=== "Artist"

    ```dart
    Artist? artist = await Artist().preload('songs').find(1);
    List<Song> songs = artist?.songs;
    ```

=== "Song"

    ```dart
    Song? song = await Song().preload('artists').find(1);
    List<Artist> artists = song?.artists;
    ```

!!! info
    When `eager` is `true` the `preload` do not need to call.

#### `related`

=== "Artist"

    ```dart
    Artist? artist = await Artist().find(1);
    List<Song> songs = await artist?
        .related<Song>('songs')
        .where('status', 'active').get();
    ```

=== "Song"

    ```dart
    Song? song = await Song().find(1);
    List<Artist> artist = await song?
        .related<Artist>('artists')
        .orderBy('name').get();
    ```

## Options

#### `model`

```dart
@ManyToMany(Song)
List<Song> songs;
```

#### `localKey` 

Model primary key.

=== "Artist Model"

    ```dart
    @ManyToMany(Song, localKey: 'id') // primary key of artist table
    List<Song> songs;
    ```

=== "Song Model"

    ```dart
    @ManyToMany(Artist, localKey: 'id') // primary key of song table
    List<Artist> artists;
    ```

#### `relatedKey`

Related model primary key.

=== "Artist Model"

    ```dart
    @ManyToMany(Song, relatedKey: 'id') // primary key of song table
    List<Song> songs;
    ```

=== "Song Model"

    ```dart
    @ManyToMany(Artist, relatedKey: 'id') // primary key of artist table
    List<Artist> artists;
    ```

#### `pivotForeignKey`

=== "Artist Model"

    ```dart
    @ManyToMany(Song, pivotForeignKey: 'artist_id')
    List<Song> songs;
    ```

=== "Song Model"

    ```dart
    @ManyToMany(Artist, pivotForeignKey: 'song_id')
    List<Artist> artists;
    ```

!!! info
    If model is Artist, `artist_id` from pivot table. If model is Song, `song_id` from pivot table.

#### `pivotRelatedForeignKey`

=== "Artist Model"

    ```dart
    @ManyToMany(Song, pivotRelatedForeignKey: 'song_id')
    List<Song> songs;
    ```

=== "Song Model"

    ```dart
    @ManyToMany(Artist, pivotRelatedForeignKey: 'artist_id')
    List<Artist> artists;
    ```

!!! info
    If model is artist, song_id from pivot table. If model is song, artist_id from pivot table.

#### `pivotTable`

```dart
@ManyToMany(Song, pivotTable: 'artist_song')
List<Song> songs;
```

!!!info 
    By default, the pivot table will be named alphabetically, as demonstrated by these examples:
    
    1. For tables named `song` and `artist`, the pivot table would be named `artist_song`.
    2. In the case of tables named `blog` and `category`, the default pivot table name would be `blog_category`.

    However, you have the flexibility to provide a custom name to the `pivotTable` parameter if needed.

#### `onQuery`

=== "Artist Model"

    ```dart
    @ManyToMany(Song, onQuery: onQueryActiveCategory)
    List<Song> songs;

    static QueryBuilder<Category> onQueryActiveCategory(Category q) {
        return q.where('status', 'active');
    }
    ```

=== "Song Model"

    ```dart
    @ManyToMany(Artist, onQuery: onQueryActiveArtist)
    List<Artist> artists;

    static QueryBuilder<Artist> onQueryActiveArtist(Artist q) {
        return q.where('status', 'active');
    }
    ```

!!! info
    `onQuery` method must be a static method inside the model.

#### `eager`

=== "Artist Model"

    ```dart
    @ManyToMany(Song, eager: true)
    List<Song> songs;
    ```

=== "Song Model"

    ```dart
    @ManyToMany(Artist, eager: true)
    List<Artist> artists;
    ```



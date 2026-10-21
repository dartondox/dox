class Column {
  final String? name;
  final Function? beforeSave;
  final Function? beforeGet;

  const Column({this.name, this.beforeSave, this.beforeGet});
}

class HasOne {
  final Type model;
  final String? foreignKey;
  final String? localKey;
  final Function? onQuery;
  final bool? eager;

  const HasOne(this.model,
      {this.foreignKey, this.localKey, this.onQuery, this.eager});
}

class HasMany {
  final Type model;
  final String? foreignKey;
  final String? localKey;
  final Function? onQuery;
  final bool? eager;

  const HasMany(this.model,
      {this.foreignKey, this.localKey, this.onQuery, this.eager});
}

class BelongsTo {
  final Type model;
  final String? foreignKey;
  final String? localKey;
  final Function? onQuery;
  final bool? eager;

  const BelongsTo(this.model,
      {this.foreignKey, this.localKey, this.onQuery, this.eager});
}

class ManyToMany {
  final Type model;
  final Function? onQuery;
  final bool? eager;

  /// id column on artist table
  final String? localKey;

  /// id column on song table
  final String? relatedKey;

  /// artist_id column on related table
  final String? pivotForeignKey;

  /// artist_id column on related table
  final String? pivotRelatedForeignKey;

  /// song_artist table
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

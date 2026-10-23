class DoxModel {
  final String? table;
  final String primaryKey;

  /// Dart type of the primary key, like `String` for a UUID key.
  /// The default is `int`.
  final Type primaryKeyType;
  /// column of the create time. null turns it off.
  final String? createdAt;

  /// column of the last update time. null turns it off.
  final String? updatedAt;

  /// false turns off both createdAt and updatedAt,
  /// like `$timestamps = false` in Laravel
  final bool timestamps;
  final bool softDelete;

  const DoxModel({
    this.table,
    this.primaryKey = 'id',
    this.primaryKeyType = int,
    this.createdAt = 'created_at',
    this.updatedAt = 'updated_at',
    this.softDelete = false,
    this.timestamps = true,
  });
}

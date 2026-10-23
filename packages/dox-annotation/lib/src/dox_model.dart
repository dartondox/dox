class DoxModel {
  final String? table;
  final String primaryKey;

  /// Dart type of the primary key, like `String` for a UUID key.
  /// The default is `int`.
  final Type primaryKeyType;
  final String createdAt;
  final String updatedAt;
  final bool softDelete;

  const DoxModel({
    this.table,
    this.primaryKey = 'id',
    this.primaryKeyType = int,
    this.createdAt = 'created_at',
    this.updatedAt = 'updated_at',
    this.softDelete = false,
  });
}

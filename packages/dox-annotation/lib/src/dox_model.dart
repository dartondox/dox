class DoxModel {
  final String? table;
  final String primaryKey;
  final String createdAt;
  final String updatedAt;
  final bool softDelete;

  const DoxModel({
    this.table,
    this.primaryKey = 'id',
    this.createdAt = 'created_at',
    this.updatedAt = 'updated_at',
    this.softDelete = false,
  });
}

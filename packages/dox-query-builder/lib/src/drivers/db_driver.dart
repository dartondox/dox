enum Driver { postgres, mysql }

/// interface for database driver
abstract class DBDriver {
  Driver getName();

  /// run query and return map result
  Future<T> execute<T>(String query,
      {Map<String, dynamic>? substitutionValues});

  /// run query and return map result
  Future<List<Map<String, dynamic>>> mappedResultsQuery(
    String query, {
    String? primaryKey,
    Map<String, dynamic>? substitutionValues,
  });

  /// run query, this function do not return any value
  Future<void> query(String query, {Map<String, dynamic>? substitutionValues});
}

/// interface for database driver
abstract class DBDriver {
  /// run query and return map result
  Future<List<Map<String, Map<String, dynamic>>>> mappedResultsQuery(
      String query,
      {Map<String, dynamic>? substitutionValues});

  /// run query, this function do not return any value
  Future<void> query(String query, {Map<String, dynamic>? substitutionValues});
}

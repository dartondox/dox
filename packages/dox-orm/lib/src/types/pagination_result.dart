/// pagination result
class Pagination {
  /// total records
  final int total;

  /// record per page
  final int perPage;

  /// last page of the pagination
  final int lastPage;

  /// current page of pagination
  final int currentPage;

  // ignore: always_specify_types
  List data;

  /// constructor
  Pagination({
    required this.total,
    required this.perPage,
    required this.lastPage,
    required this.currentPage,
    required this.data,
  });

  /// get list of data
  List<T> getData<T>() {
    return data as List<T>;
  }

  /// support json encode
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'total': total,
      'per_page': perPage,
      'last_page': lastPage,
      'current_page': currentPage,
      'data': data,
    };
  }
}

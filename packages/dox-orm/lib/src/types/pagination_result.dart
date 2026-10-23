/// pagination result
class Pagination<T> {
  /// total records
  final int total;

  /// record per page
  final int perPage;

  /// last page of the pagination
  final int lastPage;

  /// current page of pagination
  final int currentPage;

  List<T> data;

  /// constructor
  Pagination({
    required this.total,
    required this.perPage,
    required this.lastPage,
    required this.currentPage,
    required this.data,
  });

  /// get list of data
  List<R> getData<R>() {
    return data as List<R>;
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

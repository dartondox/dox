import 'package:dox_core/dox_core.dart';

/// Page of the blog list.
@Dto()
class ListBlogs {
  /// Page number, from 1.
  @Min(1)
  final int page;

  /// Blogs per page.
  @Min(1)
  @Max(100)
  final int limit;

  const ListBlogs({this.page = 1, this.limit = 20});
}

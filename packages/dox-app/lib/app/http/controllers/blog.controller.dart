import 'package:dox_app/app/http/dto/blog.dto.dart';
import 'package:dox_app/app/http/requests/blog.request.dart';
import 'package:dox_app/app/http/services/blog.service.dart';
import 'package:dox_app/app/models/blog/blog.model.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox_orm/dox_orm.dart';

class BlogController {
  /// List blogs
  ///
  /// One page of blogs, oldest first.
  @Query(ListBlogs)
  Future<Pagination> index(DoxRequest req) async {
    req.validate(<String, String>{
      'page': 'required|integer',
      'limit': 'required|integer',
    });
    bool withTrashed = req.input('with_trashed').toString() == '1';
    return BlogService().listing(
      req.input('limit'),
      req.input('page'),
      withTrashed: withTrashed,
    );
  }

  /// Create a blog
  Future<Blog> store(BlogRequest req) async {
    return BlogService().create(req);
  }

  /// Get one blog
  Future<Blog?> show(DoxRequest req, String id) async {
    return BlogService().findById(id);
  }

  /// Update a blog
  Future<Blog?> update(BlogRequest req, String id) async {
    return BlogService().update(req, id);
  }

  /// Delete a blog
  Future<Map<String, String>> destroy(DoxRequest req, String id) async {
    await BlogService().delete(id);
    return <String, String>{
      'status': 'success',
      'message': 'Blog deleted successfully',
    };
  }
}

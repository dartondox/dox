import 'package:dox_app/app/http/requests/blog.request.dart';
import 'package:dox_app/app/http/services/blog.service.dart';
import 'package:dox_core/dox_core.dart';

class BlogController {
  /// GET /blogs
  Future<dynamic> index(DoxRequest req) async {
    req.validate(
      <String, String>{
        'page': 'required|integer',
        'limit': 'required|integer',
      },
    );
    bool withTrashed = req.input('with_trashed').toString() == '1';
    return BlogService().listing(
      req.input('limit'),
      req.input('page'),
      withTrashed: withTrashed,
    );
  }

  /// POST /blogs
  Future<dynamic> store(BlogRequest req) async {
    return BlogService().create(req);
  }

  /// GET /blogs/{id}
  Future<dynamic> show(DoxRequest req, String id) async {
    return BlogService().findById(id);
  }

  /// PUT|PATCH /blogs/{id}
  Future<dynamic> update(BlogRequest req, String id) async {
    return BlogService().update(req, id);
  }

  /// DELETE /blogs/{id}
  Future<dynamic> destroy(DoxRequest req, String id) async {
    await BlogService().delete(id);
    return <String, String>{
      'status': 'success',
      'message': 'Blog deleted successfully',
    };
  }
}

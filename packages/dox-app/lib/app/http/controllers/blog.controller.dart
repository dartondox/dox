import 'package:dox_app/app/http/dtos/blog.dto.dart';
import 'package:dox_app/app/http/services/blog.service.dart';
import 'package:dox_app/app/models/blog/blog.model.dart';
import 'package:dox_orm/dox_orm.dart';

class BlogController {
  /// List blogs
  ///
  /// One page of blogs, oldest first.
  Future<Pagination> index(ListBlogs query) async {
    return BlogService().listing(query);
  }

  /// Create a blog
  Future<Blog> store(SaveBlog body) async {
    return BlogService().create(body);
  }

  /// Get one blog
  Future<Blog?> show(int id) async {
    return BlogService().findById(id);
  }

  /// Update a blog
  Future<Blog?> update(int id, SaveBlog body) async {
    return BlogService().update(body, id);
  }

  /// Delete a blog
  Future<Map<String, String>> destroy(int id) async {
    await BlogService().delete(id);
    return <String, String>{
      'status': 'success',
      'message': 'Blog deleted successfully',
    };
  }
}

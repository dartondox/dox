import 'package:dox_app/app/http/dtos/blog.dto.dart';
import 'package:dox_app/app/http/services/blog.service.dart';
import 'package:dox_app/app/models/blog/blog.model.dart';
import 'package:dox_orm/dox_orm.dart';

@Inject()
class BlogController {
  BlogController(this.blogs);

  final BlogService blogs;

  /// List blogs
  ///
  /// One page of blogs, oldest first.
  Future<Pagination<Blog>> index(ListBlogs query) async {
    return blogs.listing(query);
  }

  /// Create a blog
  Future<Blog> store(SaveBlog body) async {
    return blogs.create(body);
  }

  /// Get one blog
  Future<Blog?> show(int id) async {
    return blogs.findById(id);
  }

  /// Update a blog
  Future<Blog?> update(int id, SaveBlog body) async {
    return blogs.update(body, id);
  }

  /// Delete a blog
  Future<Map<String, String>> destroy(int id) async {
    await blogs.delete(id);
    return <String, String>{
      'status': 'success',
      'message': 'Blog deleted successfully',
    };
  }
}

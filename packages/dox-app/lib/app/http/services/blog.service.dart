import 'package:dox_app/app/http/dtos/blog.dto.dart';
import 'package:dox_app/app/models/blog/blog.model.dart';
import 'package:dox_orm/dox_orm.dart';

class BlogService {
  BlogService();

  Future<Pagination<Blog>> listing(ListBlogs query) async {
    int offset = (query.page - 1) * query.limit;
    return Blog()
        .withTrash(query.withTrashed)
        .limit(query.limit)
        .offset(offset)
        .orderBy('id')
        .paginate(currentPage: query.page, perPage: query.limit);
  }

  Future<Blog?> findById(int id) async {
    return Blog().find(id);
  }

  Future<void> delete(int id) async {
    return Blog().where('id', id).delete();
  }

  Future<Blog> create(SaveBlog input) async {
    Blog blog = Blog();
    blog.title = input.title;
    blog.description = input.description;
    await blog.save();
    return blog;
  }

  Future<Blog?> update(SaveBlog input, int id) async {
    Blog? blog = await Blog().find(id);
    blog?.title = input.title;
    blog?.description = input.description;
    await blog?.save();
    return blog;
  }
}

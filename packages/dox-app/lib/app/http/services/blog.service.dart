import 'package:dox_app/app/http/requests/blog.request.dart';
import 'package:dox_app/app/models/blog/blog.model.dart';
import 'package:dox_app/app/models/category/category.model.dart';
import 'package:dox_query_builder/dox_query_builder.dart';

class BlogService {
  BlogService();

  Future<Pagination> listing(dynamic limit, dynamic page,
      {bool withTrashed = false}) async {
    int limitValue = int.parse(limit.toString());
    int pageValue = int.parse(page.toString());
    int offset = (pageValue - 1) * limitValue;
    return Blog()
        .withTrash(withTrashed)
        .limit(limitValue)
        .offset(offset)
        .orderBy('id')
        .paginate(
          currentPage: int.parse(page.toString()),
          perPage: int.parse(limit.toString()),
        );
  }

  Future<dynamic> findById(dynamic id) async {
    Category? cat = await Category().preload('blogs').find(1);
    return cat;
  }

  Future<void> delete(dynamic id) async {
    return Blog().where('id', id).delete();
  }

  Future<Blog> create(BlogRequest req) async {
    Blog blog = Blog();
    blog.title = req.title;
    blog.description = req.description;
    await blog.save();
    return blog;
  }

  Future<Blog?> update(BlogRequest req, dynamic id) async {
    Blog? blog = await Blog().find(id);
    blog?.title = req.title;
    blog?.description = req.description;
    await blog?.save();
    return blog;
  }
}

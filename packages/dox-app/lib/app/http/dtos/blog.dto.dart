import 'package:dox_core/dox_core.dart';

part 'blog.dto.g.dart';

/// Page of the blog list.
@Dto()
class ListBlogs {
  /// Page number, from 1.
  @Min(1)
  final int page;

  /// Blogs per page.
  @Range(1, 100)
  final int limit;

  const ListBlogs({this.page = 1, this.limit = 20});

  static const DtoSchema<ListBlogs> schema = $ListBlogsDto;
}

/// A new blog, or all fields of a blog to update.
@Dto()
class SaveBlog {
  @Trim()
  @MaxLength(255)
  final String title;

  @Trim()
  final String description;

  const SaveBlog({required this.title, required this.description});

  static const DtoSchema<SaveBlog> schema = $SaveBlogDto;
}

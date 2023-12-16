import 'package:dox_app/app/models/blog/blog.model.dart';
import 'package:dox_query_builder/dox_query_builder.dart';

part 'category.model.g.dart';

@DoxModel()
class Category extends CategoryGenerator {
  @override
  List<String> get hidden => <String>[];

  @Column()
  String? name;

  @ManyToMany(
    Blog,
    localKey: 'id',
    relatedKey: 'id',
    pivotForeignKey: 'category_id',
    pivotRelatedForeignKey: 'blog_id',
    onQuery: onQueryActiveUser,
  )
  List<Blog> blogs = <Blog>[];

  static QueryBuilder<Blog> onQueryActiveUser(Blog q) {
    return q.debug(true).where('user_id', 1);
  }
}

import 'package:dox_app/models/category/category.model.dart';
import 'package:dox_app/models/user/user.model.dart';
import 'package:dox_app/utils/extensions.dart';
import 'package:dox_query_builder/dox_query_builder.dart';

part 'blog.model.g.dart';

@DoxModel(softDelete: true)
class Blog extends BlogGenerator {
  @override
  List<String> get hidden => <String>[];

  @Column()
  int? userId;

  @Column()
  String? title;

  @Column(beforeSave: makeSlug)
  String? slug;

  @Column()
  String? description;

  @BelongsTo(User, eager: false, foreignKey: 'user_id', localKey: 'id')
  User? user;

  @ManyToMany(
    Category,
    localKey: 'id',
    relatedKey: 'id',
    pivotForeignKey: 'blog_id',
    pivotRelatedForeignKey: 'category_id',
    onQuery: onQueryActiveUser,
  )
  List<Category> categories = <Category>[];

  static String makeSlug(Map<String, dynamic> map) {
    return map['title'].toString().slugify();
  }

  static QueryBuilder<Category> onQueryActiveUser(Category q) {
    return q.debug(true).where('user_id', 1);
  }
}

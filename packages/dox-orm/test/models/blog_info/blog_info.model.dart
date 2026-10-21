import 'package:dox_orm/dox_orm.dart';

import '../blog/blog.model.dart';

part 'blog_info.model.g.dart';

@DoxModel()
class BlogInfo extends BlogInfoGenerator {
  @Column()
  Map<String, dynamic>? info;

  @Column(name: 'blog_id')
  int? blogId;

  @BelongsTo(Blog, onQuery: onQuery)
  Blog? blog;

  @Computed()
  bool get hasInfo => info != null;

  static Model<Blog> onQuery(Blog q) {
    return q.debug(false);
  }
}

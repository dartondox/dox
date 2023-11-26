import 'package:dox_query_builder/dox_query_builder.dart';

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

  static Model<Blog> onQuery(Blog q) {
    return q.debug(false);
  }
}

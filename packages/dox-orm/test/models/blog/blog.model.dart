import 'package:dox_orm/dox_orm.dart';

import '../blog_info/blog_info.model.dart';

part 'blog.model.g.dart';

@DoxModel(primaryKey: 'uid', softDelete: true)
class Blog extends BlogGenerator {
  @override
  List<String> get hidden => <String>['status', 'secret_note'];

  @Column(beforeSave: slugTitle, beforeGet: beforeGet)
  String? title;

  @Column()
  String? status;

  @Column()
  String? slug;

  @Column(name: 'body')
  String? description;

  @Column(name: 'deleted_at')
  DateTime? deletedAt;

  @HasOne(BlogInfo, eager: true, onQuery: onQuery)
  BlogInfo? blogInfo;

  @HasMany(BlogInfo, eager: true, onQuery: onQuery)
  List<BlogInfo> blogInfos = <BlogInfo>[];

  @Computed()
  int get titleLength => title?.length ?? 0;

  @Computed(name: 'secret_note')
  String get secret => 'hidden';

  static String? slugTitle(Map<String, dynamic> map) {
    return map['title'];
  }

  static String? beforeGet(Map<String, dynamic> map) {
    return map['title'];
  }

  static Model<BlogInfo> onQuery(BlogInfo q) {
    return q.debug(false);
  }
}

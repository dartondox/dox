import 'package:dox_orm/dox_orm.dart';

part 'scoped_post.model.g.dart';

/// a model with local and global scopes
@DoxModel(timestamps: false)
class ScopedPost extends ScopedPostGenerator {
  @Column()
  String? title;

  @Column()
  bool? published;

  @Column()
  bool? archived;

  @Column()
  int? views;

  @Scope()
  static QueryBuilder<ScopedPost> isPublished(QueryBuilder<ScopedPost> q) {
    return q.where('published', true);
  }

  @Scope()
  static QueryBuilder<ScopedPost> minViews(
    QueryBuilder<ScopedPost> q,
    int views, [
    String op = '>=',
  ]) {
    return q.where('views', op, views);
  }

  @Scope()
  static QueryBuilder<ScopedPost> titled(
    QueryBuilder<ScopedPost> q, {
    required String title,
    bool exact = true,
  }) {
    return exact
        ? q.where('title', title)
        : q.where('title', 'like', '%$title%');
  }

  /// every query leaves out archived posts, unless removed
  @Scope(global: true)
  static QueryBuilder<ScopedPost> visible(QueryBuilder<ScopedPost> q) {
    return q.where('archived', false).orWhereNull('archived');
  }
}

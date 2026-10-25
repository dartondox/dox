import 'package:blog/app/http/dtos/save_post/save_post.dto.dart';
import 'package:blog/app/models/post/post.model.dart';
import 'package:dox_core/dox_core.dart';

@Inject()
class PostController {
  /// GET /api/posts
  Future<List<Post>> index(DoxRequest req) async {
    return Post().all();
  }

  /// POST /api/posts
  Future<DoxResponse> store(SavePost body) async {
    Post post = Post()
      ..title = body.title
      ..body = body.body;
    await post.save();
    return response(post).statusCode(201);
  }

  /// GET /api/posts/{id}
  Future<Post> show(int id) async {
    return _find(id);
  }

  /// PUT /api/posts/{id}
  Future<Post> update(int id, SavePost body) async {
    Post post = await _find(id);
    post
      ..title = body.title
      ..body = body.body;
    await post.save();
    return post;
  }

  Future<Post> _find(int id) async {
    Post? post = await Post().find(id);
    if (post == null) {
      throw NotFoundHttpException();
    }
    return post;
  }
}

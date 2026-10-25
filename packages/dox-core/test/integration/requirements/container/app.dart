import 'package:dox_core/dox_core.dart';

/// a small app wired like `lib/generated/container.g.dart` wires a real one

class UserRepository {
  String find(int id) => 'user $id';
}

class FakeUserRepository extends UserRepository {
  @override
  String find(int id) => 'fake $id';
}

class UserService {
  UserService(this.users);
  final UserRepository users;

  String show(int id) => users.find(id);
}

/// a new one on each request
class RequestCounter {
  static int made = 0;
  RequestCounter() {
    made++;
  }
}

class Post {
  Post(this.id);
  final int id;
}

class UserController {
  UserController(this.service);
  final UserService service;

  String show(int id) => service.show(id);

  String hash(DoxRequest req) => '${Dox().isolateId}:${identityHashCode(this)}';

  Map<String, Object> post(Post post, UserService service) {
    return <String, Object>{
      'post': post.id,
      'same': identical(service, this.service),
    };
  }

  int count(RequestCounter counter) => RequestCounter.made;
}

class BlogController {
  BlogController(this.service);
  final UserService service;

  String index(DoxRequest req) => 'blogs';
  String show(int id) => 'blog $id';
}

class ApiRouter extends Router {
  ApiRouter(this.service);
  final UserService service;

  @override
  String get prefix => 'api';

  @override
  void register() {
    Route.get<UserController>('users/{id}', (UserController c) => c.show);
    Route.get('untyped/{id}', (UserController c) => c.show);
    Route.get<UserController>('hash', (UserController c) => c.hash);
    Route.get<UserController>(
      'posts/{post}',
      (UserController c) => c.post,
    ).name('posts.show');
    Route.get<UserController>('count', (UserController c) => c.count);
    Route.get('service/{id}', (UserService s, int id) => s.show(id));
    Route.resource('blogs', BlogController);
  }
}

class SetupProvider extends DoxProvider {
  bool ran = false;

  @override
  void setup() {
    ran = true;
  }
}

void registerContainer(IocContainer c) {
  c.singleton<UserRepository>((IocContainer c) => UserRepository());
  c.singleton<UserService>(
    (IocContainer c) => UserService(c.get<UserRepository>()),
  );
  c.singleton<UserController>(
    (IocContainer c) => UserController(c.get<UserService>()),
  );
  c.singleton<BlogController>(
    (IocContainer c) => BlogController(c.get<UserService>()),
  );
  c.factory<RequestCounter>((IocContainer c) => RequestCounter());
  c.router<ApiRouter>((IocContainer c) => ApiRouter(c.get<UserService>()));
  c.provider<SetupProvider>((IocContainer c) => SetupProvider());
  c.bindModel<Post>((String id) {
    int? key = int.tryParse(id);
    if (key == null || key > 100) return null;
    return Post(key);
  });
}

AppConfig containerConfig({int port = 0, int isolates = 1}) {
  return AppConfig(
    appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
    serverPort: port,
    totalIsolate: isolates,
    container: registerContainer,
  );
}

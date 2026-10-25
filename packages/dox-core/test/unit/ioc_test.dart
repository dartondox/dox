import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

class Repo {
  String name() => 'real';
}

class FakeRepo extends Repo {
  @override
  String name() => 'fake';
}

class Service {
  Service(this.repo);
  final Repo repo;
}

class A {
  A(this.b);
  final B b;
}

class B {
  B(this.a);
  final A a;
}

class Config {
  const Config(this.host);
  final String host;
}

class Api extends Router {
  @override
  void register() {}
}

class Setup implements DoxService {
  @override
  void setup() {}
}

void register(IocContainer c) {
  c.singleton<Repo>((IocContainer c) => Repo());
  c.singleton<Service>((IocContainer c) => Service(c.get<Repo>()));
}

void main() {
  group('IocContainer |', () {
    test('singleton gives one instance, made on first use', () {
      IocContainer c = IocContainer();
      int made = 0;
      c.singleton<Repo>((IocContainer c) {
        made++;
        return Repo();
      });
      expect(made, 0);
      expect(identical(c.get<Repo>(), c.get<Repo>()), isTrue);
      expect(made, 1);
    });

    test('factory gives a new instance each time', () {
      IocContainer c = IocContainer();
      c.factory<Repo>((IocContainer c) => Repo());
      expect(identical(c.get<Repo>(), c.get<Repo>()), isFalse);
      expect(c.isShared(Repo), isFalse);
    });

    test('constructor dependencies come from the container', () {
      IocContainer c = IocContainer();
      register(c);
      expect(identical(c.get<Service>().repo, c.get<Repo>()), isTrue);
    });

    test('instance and has', () {
      IocContainer c = IocContainer();
      expect(c.has<Config>(), isFalse);
      c.instance<Config>(const Config('localhost'));
      expect(c.has<Config>(), isTrue);
      expect(c.get<Config>().host, 'localhost');
    });

    test('a missing type says how to fix it', () {
      IocContainer c = IocContainer();
      expect(
        () => c.get<Repo>(),
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            contains('Add @Inject()'),
          ),
        ),
      );
    });

    test('a cycle shows the chain', () {
      IocContainer c = IocContainer();
      c.singleton<A>((IocContainer c) => A(c.get<B>()));
      c.singleton<B>((IocContainer c) => B(c.get<A>()));
      expect(
        () => c.get<A>(),
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            contains('A -> B -> A'),
          ),
        ),
      );
    });

    test('override stays when the app registers again', () {
      IocContainer c = IocContainer();
      register(c);
      Service before = c.get<Service>();
      c.override<Repo>(FakeRepo());
      register(c);
      expect(c.get<Repo>().name(), 'fake');
      expect(c.get<Service>().repo.name(), 'fake');
      expect(identical(before, c.get<Service>()), isFalse);

      c.clearOverrides();
      expect(c.has<Repo>(), isFalse);
      register(c);
      expect(c.get<Service>().repo.name(), 'real');
    });

    test('clear keeps the overrides', () {
      IocContainer c = IocContainer();
      register(c);
      c.override<Repo>(FakeRepo());
      c.clear();
      expect(c.has<Service>(), isFalse);
      expect(c.get<Repo>().name(), 'fake');
    });

    test('routers, services and model binders', () async {
      IocContainer c = IocContainer();
      c.router<Api>((IocContainer c) => Api());
      c.service<Setup>((IocContainer c) => Setup());
      c.bindModel<Config>((String id) => Config(id));
      expect(c.routers.single, same(c.get<Api>()));
      expect(c.services.single, same(c.get<Setup>()));
      Object? found = await c.modelBinderNamed('Config')!('db');
      expect((found as Config).host, 'db');
      expect(c.modelBinderNamed('Repo'), isNull);
    });

    test('adopt puts a listed service in place of its type', () {
      IocContainer c = IocContainer();
      c.service<Setup>((IocContainer c) => Setup());
      Setup listed = Setup();
      c.adopt(listed);
      expect(c.get<Setup>(), same(listed));
      c.adopt(Repo()); // not registered: nothing changes
      expect(c.has<Repo>(), isFalse);
    });

    test('typeNamed finds a type by its name', () {
      IocContainer c = IocContainer();
      register(c);
      expect(c.typeNamed('Service'), Service);
      expect(c.typeNamed('Nope'), isNull);
    });
  });
}

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

class ABC {
  ABC();

  String sayHello() {
    return 'hello';
  }
}

void main() {
  group('IOC Container |', () {
    test('register', () {
      IocContainer ioc = IocContainer();
      ioc.register<ABC>((IocContainer i) => ABC());

      ABC abc = ioc.get<ABC>();
      expect(abc.sayHello(), 'hello');
    });

    test('register by name', () {
      IocContainer ioc = IocContainer();
      ioc.registerByName('ABC', (IocContainer i) => ABC());

      ABC abc = ioc.get<ABC>();
      expect(abc.sayHello(), 'hello');
    });

    test('get by name', () {
      IocContainer ioc = IocContainer();
      ioc.registerByName('ABC', (IocContainer i) => ABC());

      ABC abc = ioc.getByName('ABC');
      expect(abc.sayHello(), 'hello');
    });

    test('register singleton', () {
      IocContainer ioc = IocContainer();
      ioc.registerSingleton<ABC>((IocContainer i) => ABC());

      ABC abc = ioc.get<ABC>();
      ABC newAbc = ioc.get<ABC>();
      expect(abc, newAbc);
    });

    test('register singleton and get by name', () {
      IocContainer ioc = IocContainer();
      ioc.registerSingleton<ABC>((IocContainer i) => ABC());

      ABC abc = ioc.getByName('ABC');
      ABC newAbc = ioc.getByName('ABC');
      expect(abc, newAbc);
    });

    test('register request', () {
      IocContainer ioc = IocContainer();
      ioc.registerRequest('ABC', () => ABC());

      ABC abc = ioc.get<ABC>();
      expect(abc.sayHello(), 'hello');
    });

    test('register should not equal 2 instance', () {
      IocContainer ioc = IocContainer();
      ioc.register<ABC>((IocContainer i) => ABC());

      ABC abc = ioc.get<ABC>();
      ABC newAbc = ioc.get<ABC>();
      expect(abc != newAbc, true);
    });
  });
}

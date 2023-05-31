import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

class ABC {
  ABC();

  sayHello() {
    return 'hello';
  }
}

void main() {
  group('IOC Container |', () {
    test('register', () {
      var ioc = IocContainer();
      ioc.register<ABC>((i) => ABC());

      ABC abc = ioc.get<ABC>();
      expect(abc.sayHello(), 'hello');
    });

    test('register by name', () {
      var ioc = IocContainer();
      ioc.registerByName('ABC', (i) => ABC());

      ABC abc = ioc.get<ABC>();
      expect(abc.sayHello(), 'hello');
    });

    test('get by name', () {
      var ioc = IocContainer();
      ioc.registerByName('ABC', (i) => ABC());

      ABC abc = ioc.getByName('ABC');
      expect(abc.sayHello(), 'hello');
    });

    test('register singleton', () {
      var ioc = IocContainer();
      ioc.registerSingleton<ABC>((i) => ABC());

      ABC abc = ioc.get<ABC>();
      ABC newAbc = ioc.get<ABC>();
      expect(abc, newAbc);
    });

    test('register singleton and get by name', () {
      var ioc = IocContainer();
      ioc.registerSingleton<ABC>((i) => ABC());

      ABC abc = ioc.getByName('ABC');
      ABC newAbc = ioc.getByName('ABC');
      expect(abc, newAbc);
    });

    test('register request', () {
      var ioc = IocContainer();
      ioc.registerRequest('ABC', () => ABC());

      ABC abc = ioc.get<ABC>();
      expect(abc.sayHello(), 'hello');
    });

    test('register should not equal 2 instance', () {
      var ioc = IocContainer();
      ioc.register<ABC>((i) => ABC());

      ABC abc = ioc.get<ABC>();
      ABC newAbc = ioc.get<ABC>();
      expect(abc != newAbc, true);
    });
  });
}

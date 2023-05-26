import 'package:dox_core/dox_core.dart';

IocContainer _ioc = IocContainer();

class Global {
  static IocContainer get ioc => _ioc;
}

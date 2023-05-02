import 'package:dox_core/dox_core.dart';

class SubRoute {
  final String prefix;

  const SubRoute(this.prefix);

  get(route, controllers) {
    Route.get('$prefix/$route', controllers);
  }

  post(route, controllers) {
    Route.post('$prefix/$route', controllers);
  }

  put(route, controllers) {
    Route.put('$prefix/$route', controllers);
  }

  delete(route, controllers) {
    Route.delete('$prefix/$route', controllers);
  }

  group(p, Function(SubRoute) callback) {
    callback(SubRoute('$prefix/$p'));
  }

  purge(route, controllers) {
    Route.purge('$prefix/$route', controllers);
  }

  patch(route, controllers) {
    Route.patch('$prefix/$route', controllers);
  }

  options(route, controllers) {
    Route.options('$prefix/$route', controllers);
  }

  copy(route, controllers) {
    Route.copy('$prefix/$route', controllers);
  }

  view(route, controllers) {
    Route.view('$prefix/$route', controllers);
  }

  link(route, controllers) {
    Route.link('$prefix/$route', controllers);
  }

  unlink(route, controllers) {
    Route.unlink('$prefix/$route', controllers);
  }

  lock(route, controllers) {
    Route.lock('$prefix/$route', controllers);
  }

  unlock(route, controllers) {
    Route.unlock('$prefix/$route', controllers);
  }

  propfind(route, controllers) {
    Route.propfind('$prefix/$route', controllers);
  }
}

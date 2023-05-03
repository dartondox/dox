import 'package:dox_core/dox_core.dart';

class SubRoute {
  final String prefix;

  const SubRoute(this.prefix);

  resource(route, controller) {
    Route.resource('$prefix/$route', controller);
  }

  get(route, controller) {
    Route.get('$prefix/$route', controller);
  }

  post(route, controller) {
    Route.post('$prefix/$route', controller);
  }

  put(route, controller) {
    Route.put('$prefix/$route', controller);
  }

  delete(route, controller) {
    Route.delete('$prefix/$route', controller);
  }

  group(p, Function(SubRoute) callback) {
    callback(SubRoute('$prefix/$p'));
  }

  purge(route, controller) {
    Route.purge('$prefix/$route', controller);
  }

  patch(route, controller) {
    Route.patch('$prefix/$route', controller);
  }

  options(route, controller) {
    Route.options('$prefix/$route', controller);
  }

  copy(route, controller) {
    Route.copy('$prefix/$route', controller);
  }

  view(route, controller) {
    Route.view('$prefix/$route', controller);
  }

  link(route, controller) {
    Route.link('$prefix/$route', controller);
  }

  unlink(route, controller) {
    Route.unlink('$prefix/$route', controller);
  }

  lock(route, controller) {
    Route.lock('$prefix/$route', controller);
  }

  unlock(route, controller) {
    Route.unlock('$prefix/$route', controller);
  }

  propfind(route, controller) {
    Route.propfind('$prefix/$route', controller);
  }
}

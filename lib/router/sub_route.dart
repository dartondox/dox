import 'package:dox_core/dox_core.dart';

class SubRoute {
  final String prefix;

  const SubRoute(this.prefix);

  group(p, Function(SubRoute) callback) {
    callback(SubRoute('$prefix/$p'));
  }

  Route resource(route, controller) {
    return Route.resource('$prefix/$route', controller);
  }

  Route get(route, controller) {
    return Route.get('$prefix/$route', controller);
  }

  Route post(route, controller) {
    return Route.post('$prefix/$route', controller);
  }

  Route put(route, controller) {
    return Route.put('$prefix/$route', controller);
  }

  Route delete(route, controller) {
    return Route.delete('$prefix/$route', controller);
  }

  Route purge(route, controller) {
    return Route.purge('$prefix/$route', controller);
  }

  Route patch(route, controller) {
    return Route.patch('$prefix/$route', controller);
  }

  Route options(route, controller) {
    return Route.options('$prefix/$route', controller);
  }

  Route copy(route, controller) {
    return Route.copy('$prefix/$route', controller);
  }

  Route view(route, controller) {
    return Route.view('$prefix/$route', controller);
  }

  Route link(route, controller) {
    return Route.link('$prefix/$route', controller);
  }

  Route unlink(route, controller) {
    return Route.unlink('$prefix/$route', controller);
  }

  Route lock(route, controller) {
    return Route.lock('$prefix/$route', controller);
  }

  Route unlock(route, controller) {
    return Route.unlock('$prefix/$route', controller);
  }

  Route propfind(route, controller) {
    return Route.propfind('$prefix/$route', controller);
  }
}

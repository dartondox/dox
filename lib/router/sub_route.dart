import 'package:dox_core/dox_core.dart';

class SubRoute {
  final String prefix;

  const SubRoute(this.prefix);

  resource(route, controller, {FormRequest? request}) {
    Route.resource('$prefix/$route', controller, request: request);
  }

  get(route, controller, {FormRequest? request}) {
    Route.get('$prefix/$route', controller, request: request);
  }

  post(route, controller, {FormRequest? request}) {
    Route.post('$prefix/$route', controller, request: request);
  }

  put(route, controller, {FormRequest? request}) {
    Route.put('$prefix/$route', controller, request: request);
  }

  delete(route, controller, {FormRequest? request}) {
    Route.delete('$prefix/$route', controller, request: request);
  }

  group(p, Function(SubRoute) callback) {
    callback(SubRoute('$prefix/$p'));
  }

  purge(route, controller, {FormRequest? request}) {
    Route.purge('$prefix/$route', controller, request: request);
  }

  patch(route, controller, {FormRequest? request}) {
    Route.patch('$prefix/$route', controller, request: request);
  }

  options(route, controller, {FormRequest? request}) {
    Route.options('$prefix/$route', controller, request: request);
  }

  copy(route, controller, {FormRequest? request}) {
    Route.copy('$prefix/$route', controller, request: request);
  }

  view(route, controller, {FormRequest? request}) {
    Route.view('$prefix/$route', controller, request: request);
  }

  link(route, controller, {FormRequest? request}) {
    Route.link('$prefix/$route', controller, request: request);
  }

  unlink(route, controller, {FormRequest? request}) {
    Route.unlink('$prefix/$route', controller, request: request);
  }

  lock(route, controller, {FormRequest? request}) {
    Route.lock('$prefix/$route', controller, request: request);
  }

  unlock(route, controller, {FormRequest? request}) {
    Route.unlock('$prefix/$route', controller, request: request);
  }

  propfind(route, controller, {FormRequest? request}) {
    Route.propfind('$prefix/$route', controller, request: request);
  }
}

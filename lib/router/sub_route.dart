import 'package:dox_core/dox_core.dart';

class SubRoute {
  final String _prefix;

  const SubRoute(this._prefix);

  /// group route
  /// ```
  /// route.group('blog', (r) {
  ///   r.get('/', controller);
  /// });
  /// ```
  group(prefix, Function(SubRoute) callback) {
    callback(SubRoute('$_prefix/$prefix'));
  }

  /// resource route
  /// ```
  /// Route.resource('blog', BlogController());
  ///
  Route resource(route, controller) {
    return Route.resource('$_prefix/$route', controller);
  }

  /// get route
  /// ```
  /// Route.get('path', controller);
  ///
  Route get(route, controller) {
    return Route.get('$_prefix/$route', controller);
  }

  /// post route
  /// ```
  /// Route.post('path', controller);
  ///
  Route post(route, controller) {
    return Route.post('$_prefix/$route', controller);
  }

  /// put route
  /// ```
  /// Route.put('path', controller);
  ///
  Route put(route, controller) {
    return Route.put('$_prefix/$route', controller);
  }

  /// delete route
  /// ```
  /// Route.delete('path', controller);
  ///
  Route delete(route, controller) {
    return Route.delete('$_prefix/$route', controller);
  }

  /// purge route
  /// ```
  /// Route.purge('path', controller);
  ///
  Route purge(route, controller) {
    return Route.purge('$_prefix/$route', controller);
  }

  /// patch route
  /// ```
  /// Route.patch('path', controller);
  ///
  Route patch(route, controller) {
    return Route.patch('$_prefix/$route', controller);
  }

  /// options route
  /// ```
  /// Route.options('path', controller);
  ///
  Route options(route, controller) {
    return Route.options('$_prefix/$route', controller);
  }

  /// copy route
  /// ```
  /// Route.copy('path', controller);
  ///
  Route copy(route, controller) {
    return Route.copy('$_prefix/$route', controller);
  }

  /// view route
  /// ```
  /// Route.view('path', controller);
  ///
  Route view(route, controller) {
    return Route.view('$_prefix/$route', controller);
  }

  /// link route
  /// ```
  /// Route.link('path', controller);
  ///
  Route link(route, controller) {
    return Route.link('$_prefix/$route', controller);
  }

  /// unlink route
  /// ```
  /// Route.unlink('path', controller);
  ///
  Route unlink(route, controller) {
    return Route.unlink('$_prefix/$route', controller);
  }

  /// lock route
  /// ```
  /// Route.lock('path', controller);
  ///
  Route lock(route, controller) {
    return Route.lock('$_prefix/$route', controller);
  }

  /// unlock route
  /// ```
  /// Route.unlock('path', controller);
  ///
  Route unlock(route, controller) {
    return Route.unlock('$_prefix/$route', controller);
  }

  /// propfind route
  /// ```
  /// Route.propfind('path', controller);
  ///
  Route propfind(route, controller) {
    return Route.propfind('$_prefix/$route', controller);
  }
}

import 'package:dox_core/router/route_data.dart';

import 'src/fuzz_target.dart';

/// The path of a request, matched with a route that has params.
/// The match with no regex (`matchSegments`) must give the same answer
/// as the regex of the route.
class RouteMatchTarget extends FuzzTarget {
  RouteMatchTarget();

  final List<RouteData> routes = <RouteData>[
    for (String path in const <String>[
      '/users/{id}',
      '/users/{id}/posts/{slug}',
      '/{a}/b/{c}',
    ])
      RouteData(method: 'GET', path: path, controllers: const <dynamic>[]),
  ];

  @override
  String get name => 'route_match';

  @override
  String get library => 'package:dox_core/router/route_data.dart';

  @override
  List<String> get seeds => const <String>[
    '/users/5',
    '/users/5/posts/hello-world',
    '/x/b/y',
    '/users/a%2Fb/posts/c',
    '/users//posts/x',
  ];

  @override
  void check(String input) {
    for (RouteData route in routes) {
      if (!route.hasSegments) throw StateError('${route.path}: no segments');
      List<String>? fast = route.matchSegments(input);
      RegExpMatch? match = route.pattern!.firstMatch(input);
      List<String>? slow = match == null
          ? null
          : <String>[
              for (int i = 1; i <= match.groupCount; i++) match.group(i)!,
            ];
      if ('$fast' != '$slow') {
        throw StateError('${route.path}: $fast with no regex, $slow with it');
      }
    }
  }
}

Future<void> main(List<String> args) => RouteMatchTarget().run(args);

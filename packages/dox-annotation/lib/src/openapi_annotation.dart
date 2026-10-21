// OpenAPI annotations for controllers. They are all optional.
// The `dox_builder` openapi builder reads them at build time.
// Without them, the docs still come from the route, the validator and
// the controller method (its doc comment, arguments and return type).

/// Marks a class as a controller for the OpenAPI docs.
///
/// You only need it when the builder can not see the class in a
/// `Route.get(...)` call, for example when routes are made in a loop.
/// [tag] groups its routes in the docs page. The default is the class
/// name without `Controller`.
class DoxController {
  /// Tag for all routes of this controller.
  final String? tag;

  const DoxController({this.tag});
}

/// Short title of the route in the docs.
/// The default is the first line of the `///` doc comment.
class Summary {
  final String text;

  const Summary(this.text);
}

/// Longer text of the route in the docs.
/// The default is the rest of the `///` doc comment.
class Description {
  final String text;

  const Description(this.text);
}

/// Tags that group the route in the docs page.
class Tags {
  final List<String> names;

  const Tags(this.names);
}

/// The request class of the route: a `@Dto` class,
/// for example `@Request(CreateUser)`. It goes in the body for POST,
/// PUT and PATCH, and in the query for the other methods.
/// Use it when the builder can not find it by itself.
class Request {
  final Type type;

  const Request(this.type);
}

/// Like [Request], but always the request body.
class Body {
  final Type type;

  const Body(this.type);
}

/// Like [Request], but always the query. Each field is one parameter.
class Query {
  final Type type;

  const Query(this.type);
}

/// One response of the route. Add it more than once for more status codes.
///
/// ```
/// @Response(200, User)
/// @Response(200, List<User>, description: 'All users')
/// @Response(204, null, description: 'Deleted')
/// ```
/// [type] can be a model, a `List` of models, a `Serializer`, or a
/// basic type like `String` or `Map`. A [Response] for a status code
/// replaces the one the builder found for that code.
class Response {
  final int status;
  final Type? type;
  final String? description;

  const Response(this.status, this.type, {this.description});
}

/// Marks the route as deprecated in the docs.
/// The Dart `@Deprecated` and `@deprecated` work too.
class ApiDeprecated {
  const ApiDeprecated();
}

/// Leaves this method (or all methods of this class) out of the docs.
class ApiIgnore {
  const ApiIgnore();
}

// Lower case names for the same annotations, so `@summary('Get users')`
// works. `response` is not here: it is the `response()` helper of
// dox_core, so use `@Response(...)`.

// ignore: camel_case_types
typedef doxController = DoxController;
// ignore: camel_case_types
typedef summary = Summary;
// ignore: camel_case_types
typedef description = Description;
// ignore: camel_case_types
typedef tags = Tags;
// ignore: camel_case_types
typedef request = Request;
// ignore: camel_case_types
typedef body = Body;
// ignore: camel_case_types
typedef query = Query;
// ignore: camel_case_types
typedef apiDeprecated = ApiDeprecated;
// ignore: camel_case_types
typedef apiIgnore = ApiIgnore;

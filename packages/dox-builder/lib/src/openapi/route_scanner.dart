import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// One `Route.get('path', controller.method)` call.
class RouteCall {
  const RouteCall(this.method, this.path, this.controller, this.action);

  /// HTTP method in upper case.
  final String method;

  /// The path as written, or null when it is not a plain string.
  final String? path;

  /// The class of the handler method.
  final ClassElement controller;

  /// The handler method name.
  final String action;
}

/// Finds `Route.<method>(path, handler)` and `Route.resource(path, c)`
/// calls in a library, and the controller method each one points to.
///
/// The path has the prefixes of `Route.group('/users', ...)` and of the
/// `prefix` getter of a `Router` class, when they are plain strings,
/// the same way the router joins them at runtime. So two `'/'` routes in
/// two groups get two full paths.
class RouteScanner extends RecursiveAstVisitor<void> {
  final List<RouteCall> calls = <RouteCall>[];

  /// the prefix of the current router class and groups, or null when one
  /// of them is not a plain string
  String? _prefix = '';

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    String? old = _prefix;
    _prefix = _routerPrefix(node);
    super.visitClassDeclaration(node);
    _prefix = old;
  }

  /// `String get prefix => 'api';` of a Router: `api/`, like
  /// `Route.prefix()` does at runtime
  String? _routerPrefix(ClassDeclaration node) {
    for (ClassMember member in node.body.members) {
      if (member is! MethodDeclaration || !member.isGetter) continue;
      if (member.name.lexeme != 'prefix') continue;
      FunctionBody body = member.body;
      Expression? value;
      if (body is ExpressionFunctionBody) value = body.expression;
      if (body is BlockFunctionBody) {
        for (Statement statement in body.block.statements) {
          if (statement is ReturnStatement) value = statement.expression;
        }
      }
      String? text = value == null ? null : _path(value);
      return text == null ? null : '$text/';
    }
    return '';
  }

  static const Set<String> _methods = <String>{
    'get',
    'post',
    'put',
    'patch',
    'delete',
    'options',
  };

  /// The methods of `Route.resource` and their routes, by method name.
  static const Map<String, List<List<String>>> _resource =
      <String, List<List<String>>>{
        'index': <List<String>>[
          <String>['GET', ''],
        ],
        'create': <List<String>>[
          <String>['GET', '/create'],
        ],
        'store': <List<String>>[
          <String>['POST', ''],
        ],
        'show': <List<String>>[
          <String>['GET', '/{id}'],
        ],
        'edit': <List<String>>[
          <String>['GET', '/{id}/edit'],
        ],
        'update': <List<String>>[
          <String>['PUT', '/{id}'],
          <String>['PATCH', '/{id}'],
        ],
        'destroy': <List<String>>[
          <String>['DELETE', '/{id}'],
        ],
      };

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isGroup(node)) {
      String? old = _prefix;
      Expression first = node.argumentList.arguments.first.argumentExpression;
      String? group = _path(first);
      _prefix = old == null || group == null ? null : '$old/$group';
      super.visitMethodInvocation(node);
      _prefix = old;
      return;
    }
    super.visitMethodInvocation(node);
    Expression? target = node.target;
    if (target is! SimpleIdentifier || target.name != 'Route') return;
    Element? route = target.element;
    if (route is! ClassElement) return;
    List<Expression> args = <Expression>[
      for (Argument arg in node.argumentList.arguments)
        if (arg is! NamedArgument) arg.argumentExpression,
    ];
    if (args.length < 2) return;
    String name = node.methodName.name;
    String? written = _path(args[0]);
    String? prefix = _prefix;
    String? path = written == null || prefix == null || prefix.isEmpty
        ? written
        : '$prefix/$written'.replaceAll(RegExp('/+'), '/');
    if (name == 'resource') {
      _addResource(path, args[1]);
    } else if (_methods.contains(name)) {
      _addRoute(name.toUpperCase(), path, args[1]);
    }
  }

  void _addRoute(String method, String? path, Expression handler) {
    Expression plain = handler.unParenthesized;
    if (plain is ListLiteral && plain.elements.isNotEmpty) {
      CollectionElement last = plain.elements.last;
      if (last is! Expression) return;
      plain = last.unParenthesized;
    }
    Element? element = _element(plain);
    if (element is! MethodElement || element.isStatic) return;
    Element? owner = element.enclosingElement;
    if (owner is! ClassElement) return;
    calls.add(RouteCall(method, path, owner, element.displayName));
  }

  void _addResource(String? path, Expression controller) {
    DartType? type = controller.staticType;
    if (type is! InterfaceType) return;
    InterfaceElement element = type.element;
    if (element is! ClassElement) return;
    for (MethodElement method in element.methods) {
      List<List<String>>? routes = _resource[method.displayName];
      if (routes == null || method.isStatic) continue;
      for (List<String> route in routes) {
        calls.add(
          RouteCall(
            route[0],
            path == null ? null : '$path${route[1]}',
            element,
            method.displayName,
          ),
        );
      }
    }
  }

  bool _isGroup(MethodInvocation node) {
    Expression? target = node.target;
    return target is SimpleIdentifier &&
        target.name == 'Route' &&
        node.methodName.name == 'group' &&
        node.argumentList.arguments.isNotEmpty;
  }

  Element? _element(Expression node) {
    if (node is SimpleIdentifier) return node.element;
    if (node is PrefixedIdentifier) return node.identifier.element;
    if (node is PropertyAccess) return node.propertyName.element;
    return null;
  }

  String? _path(Expression node) {
    return node is StringLiteral ? node.stringValue : null;
  }
}

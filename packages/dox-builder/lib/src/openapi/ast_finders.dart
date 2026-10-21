import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Collects the `return` expressions of one function body.
/// Returns inside inner closures are left out.
class ReturnCollector extends RecursiveAstVisitor<void> {
  final List<Expression> expressions = <Expression>[];

  /// The return expressions of [body].
  static List<Expression> of(FunctionBody? body) {
    ReturnCollector collector = ReturnCollector();
    if (body is ExpressionFunctionBody) {
      collector.expressions.add(body.expression);
    } else {
      body?.accept(collector);
    }
    return collector.expressions;
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    Expression? expression = node.expression;
    if (expression != null) expressions.add(expression);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    /// a closure has its own returns
  }
}

/// Collects method calls by name, like `req.validate(...)`.
class CallCollector extends RecursiveAstVisitor<void> {
  CallCollector(this.names);

  final Set<String> names;
  final List<MethodInvocation> calls = <MethodInvocation>[];

  /// Calls with one of [names] inside [node].
  static List<MethodInvocation> of(AstNode? node, Set<String> names) {
    CallCollector collector = CallCollector(names);
    node?.accept(collector);
    return collector.calls;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (names.contains(node.methodName.name)) calls.add(node);
    super.visitMethodInvocation(node);
  }
}

/// Collects the plain strings inside list literals, like the
/// `<String>['password']` of a model `hidden` getter.
class StringListCollector extends RecursiveAstVisitor<void> {
  final List<String> values = <String>[];

  /// The strings of the list literals inside [node].
  static List<String> of(AstNode? node) {
    StringListCollector collector = StringListCollector();
    node?.accept(collector);
    return collector.values;
  }

  @override
  void visitListLiteral(ListLiteral node) {
    for (CollectionElement item in node.elements) {
      if (item is SimpleStringLiteral) values.add(item.value);
    }
  }
}

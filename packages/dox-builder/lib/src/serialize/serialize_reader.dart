import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

import '../dto/dto_model.dart';
import '../schema/json_schema_reader.dart';
import '../util.dart';

/// The `convert()` of a `@Serialize()` serializer, read for its JSON
/// writer: the local variables, then one map literal.
class SerializerPlan {
  SerializerPlan({
    required this.element,
    required this.itemType,
    required this.payloadType,
    required this.itemName,
    required this.locals,
    required this.map,
    required this.taken,
    required this.payload,
    required this.inline,
  });

  /// the `T` of `Serializer<T>`
  final DartType payload;

  /// `true` when a value `Name(x)` in another serializer can skip the
  /// object: `convert()` uses no member of the class, the constructor
  /// only passes `data` on (`Name(super.data)`), and the class has no
  /// field that is set when it is made. The other serializer then calls
  /// `$writeNameItem(x, writer)` directly.
  final bool inline;

  /// the serializer class
  final ClassElement element;

  /// the type of the `convert()` parameter, in code
  final String itemType;

  /// the `T` of `Serializer<T>`, in code
  final String payloadType;

  /// the name of the `convert()` parameter
  final String itemName;

  /// the local variable statements before the `return`
  final List<VariableDeclarationStatement> locals;

  /// the map literal that `convert()` returns
  final SetOrMapLiteral map;

  /// every name in `convert()`: a generated name must not be one of them
  final Set<String> taken;

  String get name => element.displayName;
}

/// What [SerializeReader.serializer] found: a [plan], or the [problem]
/// that keeps the serializer on its `toJson()` map.
class SerializerRead {
  const SerializerRead.plan(SerializerPlan this.plan) : problem = null;

  const SerializerRead.problem(String this.problem) : plan = null;

  final SerializerPlan? plan;
  final String? problem;
}

/// Reads `@Serialize()` classes. A serializer gets a JSON writer only
/// when its `convert()` has a shape that the writer can copy with no
/// guess. Every other shape keeps the map of `toJson()`.
class SerializeReader {
  SerializeReader(this.ast, {this.reader = const DtoReader()});

  final AstLoader ast;
  final DtoReader reader;

  final Map<ClassElement, Future<SerializerRead>> _done =
      <ClassElement, Future<SerializerRead>>{};

  /// The plan of the `@Serialize()` serializer [element], or why it has
  /// none. Each class is read once.
  Future<SerializerRead> serializer(ClassElement element) {
    return _done[element] ??= _read(element);
  }

  /// `true` when [element] is a `@Serialize()` class that gets a JSON
  /// writer: a plain class, or a serializer with a plan.
  Future<bool> hasWriter(ClassElement element) async {
    if (!reader.isSerialize(element)) return false;
    if (!DtoReader.isSerializer(element)) {
      return reader.plainProblem(element) == null;
    }
    return (await serializer(element)).plan != null;
  }

  Future<SerializerRead> _read(ClassElement element) async {
    SerializerRead problem(String text) => SerializerRead.problem(text);
    InterfaceType? parent = DtoReader.serializerType(element);
    if (parent == null) return problem('it is not a Serializer');
    if (element.isAbstract) return problem('it is abstract');
    if (element.typeParameters.isNotEmpty) return problem('it is generic');
    if (element.isPrivate) return problem('it is private');
    MethodElement? toJson = element.lookUpMethod(
      name: 'toJson',
      library: element.library,
    );
    if (toJson != null && toJson.enclosingElement != parent.element) {
      return problem('it has its own toJson()');
    }
    MethodElement? method = element.getMethod('convert');
    if (method == null) return problem('the class has no convert() of its own');
    AstNode? node = await ast.of(method);
    if (node is! MethodDeclaration) return problem('convert() has no code');
    List<FormalParameter> params =
        node.parameters?.parameters ?? const <FormalParameter>[];
    FormalParameterElement? param = method.formalParameters.firstOrNull;
    String? itemName = params.firstOrNull?.name?.lexeme;
    if (params.length != 1 || param == null || itemName == null) {
      return problem('convert() does not have one parameter');
    }
    DartType payload = parent.typeArguments.first;
    if (!element.library.typeSystem.isAssignableTo(payload, param.type)) {
      return problem('convert() takes another type than the Serializer');
    }
    FunctionBody body = node.body;
    List<VariableDeclarationStatement> locals =
        <VariableDeclarationStatement>[];
    Expression? returned;
    if (body is ExpressionFunctionBody) {
      returned = body.expression;
    } else if (body is BlockFunctionBody) {
      NodeList<Statement> statements = body.block.statements;
      for (int i = 0; i < statements.length; i++) {
        Statement statement = statements[i];
        bool last = i == statements.length - 1;
        if (statement is VariableDeclarationStatement && !last) {
          locals.add(statement);
        } else if (statement is ReturnStatement && last) {
          returned = statement.expression;
        } else if (statement is ReturnStatement) {
          return problem('convert() has code after its return');
        } else {
          return problem(
            'convert() has ${_kind(statement)}. Only local variables can '
            'come before the return',
          );
        }
      }
    }
    if (returned == null) return problem('convert() has no return');
    Expression map = returned.unParenthesized;
    if (map is! SetOrMapLiteral || !map.isMap) {
      return problem('convert() does not return a map literal');
    }
    String? bad = mapProblem(map);
    if (bad != null) return problem(bad);
    _SuperFinder supers = _SuperFinder();
    node.body.accept(supers);
    if (supers.found) return problem('convert() uses super');
    _Names names = _Names();
    node.accept(names);
    bool usesThis = false;
    for (AstNode part in <AstNode>[...locals, map]) {
      usesThis = usesThis || CodeCopier.usesReceiver(element, part);
    }
    bool inline =
        !usesThis &&
        payload.nullabilitySuffix == NullabilitySuffix.none &&
        await _forwards(element);
    return SerializerRead.plan(
      SerializerPlan(
        element: element,
        itemType: typeCode(param.type, element.library),
        payloadType: typeCode(payload, element.library),
        itemName: itemName,
        locals: locals,
        map: map,
        taken: names.names,
        payload: payload,
        inline: inline,
      ),
    );
  }

  /// `true` when making [element] only keeps its data: the unnamed
  /// constructor is `Name(super.data);`, and no field gets a value.
  Future<bool> _forwards(ClassElement element) async {
    for (FieldElement field in element.fields) {
      if (!field.isStatic && field.isOriginDeclaration) return false;
    }
    ConstructorElement? constructor = element.unnamedConstructor;
    if (constructor == null) return false;
    AstNode? node = await ast.of(constructor);
    if (node is! ConstructorDeclaration) return false;
    NodeList<FormalParameter> params = node.parameters.parameters;
    return node.factoryKeyword == null &&
        node.redirectedConstructor == null &&
        node.initializers.isEmpty &&
        node.body is EmptyFunctionBody &&
        params.length == 1 &&
        params.first is SuperFormalParameter &&
        params.first.isRequiredPositional;
  }

  /// Why the map literal [map] (and each map literal value in it) can not
  /// be written with fixed keys, or null.
  static String? mapProblem(SetOrMapLiteral map) {
    Set<String> keys = <String>{};
    for (CollectionElement item in map.elements) {
      if (item is! MapLiteralEntry) {
        return 'a map in convert() has a collection if, for or spread';
      }
      Expression key = item.key;
      String? text = key is StringLiteral && key is! StringInterpolation
          ? key.stringValue
          : null;
      if (text == null) {
        return 'a map in convert() has a key that is not a constant '
            'string: ${key.toSource()}';
      }
      if (!keys.add(text)) {
        return 'a map in convert() has the key "$text" twice';
      }
      Expression value = item.value.unParenthesized;
      if (value is SetOrMapLiteral && value.isMap) {
        String? inner = mapProblem(value);
        if (inner != null) return inner;
      }
    }
    return null;
  }

  static String _kind(Statement statement) {
    return switch (statement) {
      IfStatement() => 'an if statement',
      ForStatement() => 'a for loop',
      WhileStatement() || DoStatement() => 'a loop',
      SwitchStatement() => 'a switch',
      TryStatement() => 'a try',
      FunctionDeclarationStatement() => 'a local function',
      PatternVariableDeclarationStatement() => 'a pattern variable',
      _ => 'a statement that is not a local variable',
    };
  }
}

class _SuperFinder extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitSuperExpression(SuperExpression node) {
    found = true;
  }
}

class _Names extends RecursiveAstVisitor<void> {
  final Set<String> names = <String>{};

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    names.add(node.name);
  }

  @override
  void visitFormalParameterList(FormalParameterList node) {
    for (FormalParameter param in node.parameters) {
      String? name = param.name?.lexeme;
      if (name != null) names.add(name);
    }
    super.visitFormalParameterList(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    names.add(node.name.lexeme);
    super.visitVariableDeclaration(node);
  }

  @override
  void visitDeclaredIdentifier(DeclaredIdentifier node) {
    names.add(node.name.lexeme);
    super.visitDeclaredIdentifier(node);
  }

  @override
  void visitDeclaredVariablePattern(DeclaredVariablePattern node) {
    names.add(node.name.lexeme);
    super.visitDeclaredVariablePattern(node);
  }
}

/// Copies code of `convert()` to a function outside the class. A name of
/// a member of the class (a field, a getter, a method, a tear-off) gets
/// the [receiver] in front, `this` becomes the [receiver], and a static
/// member gets the class name.
class CodeCopier {
  CodeCopier(this.element, this.receiver);

  final ClassElement element;
  final String receiver;

  /// `true` when [node] uses a member of [element] or `this`.
  static bool usesReceiver(ClassElement element, AstNode node) {
    _Edits edits = _Edits(element, '');
    node.accept(edits);
    return edits.edits.isNotEmpty;
  }

  /// The code of [node], with the names changed.
  String copy(AstNode node) {
    _Edits edits = _Edits(element, receiver);
    node.accept(edits);
    StringBuffer out = StringBuffer();
    Token token = node.beginToken;
    Token end = node.endToken;
    int last = -1;
    while (true) {
      if (last >= 0 && token.offset > last) out.write(' ');
      _Edit? edit = edits.edits[token.offset];
      if (edit != null) {
        out.write(edit.text);
        // skip the tokens that the edit takes the place of
        while (token.end < edit.end && token != end) {
          token = token.next!;
        }
      } else {
        out.write(token.lexeme);
      }
      last = token.end;
      if (token == end || token.next == null) break;
      token = token.next!;
    }
    return out.toString();
  }
}

class _Edit {
  const _Edit(this.end, this.text);

  final int end;
  final String text;
}

class _Edits extends RecursiveAstVisitor<void> {
  _Edits(this.element, this.receiver);

  final ClassElement element;
  final String receiver;

  /// by the offset of the first token
  final Map<int, _Edit> edits = <int, _Edit>{};

  @override
  void visitCommentReference(CommentReference node) {}

  @override
  void visitThisExpression(ThisExpression node) {
    _replace(node, receiver);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.inDeclarationContext()) return;
    AstNode? parent = node.parent;
    if (parent is PrefixedIdentifier && parent.identifier == node) return;
    if (parent is PropertyAccess && parent.propertyName == node) return;
    if (parent is MethodInvocation &&
        parent.methodName == node &&
        (parent.target != null || parent.isCascaded)) {
      return;
    }
    if (parent is Label) return;
    Element? target = node.element;
    if (parent is CompoundAssignmentExpression) {
      target ??= parent.writeElement;
    }
    // `DateTime.utc(...)`: a constructor is not a member to change
    if (target is! ExecutableElement || target is ConstructorElement) return;
    Element? owner = target.enclosingElement;
    if (owner is! InterfaceElement && owner is! ExtensionElement) return;
    String text = target.isStatic
        ? '${prefixOf(owner!, element.library)}${owner.displayName}.${node.name}'
        : '$receiver.${node.name}';
    _replace(node, text);
  }

  void _replace(Expression node, String text) {
    AstNode? parent = node.parent;
    // `'$name'` becomes `'${o.name}'`
    if (parent is InterpolationExpression && parent.rightBracket == null) {
      edits[parent.offset] = _Edit(parent.end, '\${$text}');
      return;
    }
    edits[node.offset] = _Edit(node.end, text);
  }
}

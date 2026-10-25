import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

/// model hook methods, see Model.onSaving() in dox_orm
const List<String> _hookNames = <String>[
  'onSaving',
  'onSaved',
  'onCreating',
  'onCreated',
  'onUpdating',
  'onUpdated',
  'onDeleting',
  'onDeleted',
  'onRestoring',
  'onRestored',
  'onForceDeleting',
  'onForceDeleted',
];

const List<String> _relationTypes = <String>[
  'HasOne',
  'HasMany',
  'BelongsTo',
  'ManyToMany',
];

/// Reads the columns, relations and computed getters of a model class.
class ModelVisitor {
  String className = '';
  Map<String, Map<String, dynamic>> columns = {};

  Map<String, Map<String, dynamic>> relations = {};

  /// getter name => json key
  Map<String, String> computed = {};

  /// true when the class declares a model hook like onCreating()
  bool hasHooks = false;

  /// field name => source of the `cast:` argument of its @Column.
  /// the builder reads it from the source file before visitClass().
  Map<String, String> castSources = {};

  /// static methods with @Scope: name => (global, method)
  Map<String, (bool, MethodElement)> scopes = {};

  void visitClass(ClassElement element) {
    className = element.displayName;
    hasHooks = element.methods.any(
      (MethodElement m) => !m.isStatic && _hookNames.contains(m.displayName),
    );
    for (FieldElement field in element.fields) {
      if (field.isOriginDeclaration && !field.isStatic) {
        _visitField(field);
      }
    }
    for (MethodElement method in element.methods) {
      if (method.isStatic) _visitMethod(method);
    }
    for (GetterElement getter in element.getters) {
      if (getter.isOriginDeclaration && !getter.isStatic) {
        _visitGetter(getter);
      }
    }
  }

  void _visitGetter(GetterElement element) {
    ElementAnnotation? computedMeta = _findAnnotation(
      element.metadata,
      <String>['Computed'],
    );
    if (computedMeta == null) return;
    String name = element.displayName;
    String? key = computedMeta
        .computeConstantValue()
        ?.getField('name')
        ?.toStringValue();
    computed[name] = key ?? name;
  }

  void _visitMethod(MethodElement element) {
    ElementAnnotation? meta = _findAnnotation(element.metadata, <String>[
      'Scope',
    ]);
    if (meta == null) return;
    bool global =
        meta.computeConstantValue()?.getField('global')?.toBoolValue() ?? false;
    scopes[element.displayName] = (global, element);
  }

  /// the cast of a column: the `cast:` argument, or a default cast for
  /// a bool or an enum field, or null
  String? _castOf(FieldElement element) {
    String? source = castSources[element.displayName];
    if (source != null) return source;
    DartType type = element.type;
    if (type.isDartCoreBool) return 'BoolCast()';
    Element? typeElement = type.element;
    if (typeElement is EnumElement) {
      return 'EnumCast(${typeElement.displayName}.values)';
    }
    return null;
  }

  void _visitField(FieldElement element) {
    String name = element.displayName;

    ElementAnnotation? relationMeta = _findAnnotation(
      element.metadata,
      _relationTypes,
    );
    if (relationMeta != null) {
      DartObject? object = relationMeta.computeConstantValue();
      String? model = object
          ?.getField('model')
          ?.toTypeValue()
          ?.getDisplayString();

      relations[name] = {
        'relationType': _annotationName(relationMeta),
        'model': model?.replaceFirst('?', ''),
        'dataType': element.type.getDisplayString(),
        'localKey': object?.getField('localKey')?.toStringValue(),
        'foreignKey': object?.getField('foreignKey')?.toStringValue(),
        'onQuery': _functionName(object, 'onQuery'),
        'eager': object?.getField('eager')?.toBoolValue() ?? false,
        'relatedKey': object?.getField('relatedKey')?.toStringValue(),
        'pivotForeignKey': object?.getField('pivotForeignKey')?.toStringValue(),
        'pivotRelatedForeignKey': object
            ?.getField('pivotRelatedForeignKey')
            ?.toStringValue(),
        'pivotTable': object?.getField('pivotTable')?.toStringValue(),
      };
    }

    ElementAnnotation? columnMeta = _findAnnotation(element.metadata, <String>[
      'Column',
    ]);
    if (columnMeta != null) {
      DartObject? object = columnMeta.computeConstantValue();
      columns[name] = {
        'type': element.type.getDisplayString(),
        'jsonKey': object?.getField('name')?.toStringValue() ?? name,
        'beforeSave': _functionName(object, 'beforeSave'),
        'beforeGet': _functionName(object, 'beforeGet'),
        'cast': _castOf(element),
        'nullable': element.type.nullabilitySuffix != NullabilitySuffix.none,
      };
    }
  }

  String? _functionName(DartObject? object, String field) {
    // toFunctionValue is marked experimental in analyzer 7, and it is
    // the stable toFunctionValue in analyzer 8+.
    // ignore: experimental_member_use
    return object?.getField(field)?.toFunctionValue()?.displayName;
  }

  ElementAnnotation? _findAnnotation(Metadata metadata, List<String> names) {
    for (ElementAnnotation m in metadata.annotations) {
      if (names.contains(_annotationName(m))) return m;
    }
    return null;
  }

  /// class name of the annotation, `@Column()` => `Column`
  String? _annotationName(ElementAnnotation m) {
    Element? e = m.element;
    if (e is ConstructorElement) return e.enclosingElement.displayName;
    return e?.displayName;
  }
}

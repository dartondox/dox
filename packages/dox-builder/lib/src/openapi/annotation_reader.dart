import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// Finds annotations by their class name, like the model builder does.
/// A lower case alias (`@summary`) gives the same class (`Summary`).
class AnnotationReader {
  const AnnotationReader();

  /// The first annotation of class [name] on [element], or null.
  DartObject? first(Element element, String name) {
    List<DartObject> found = all(element, name);
    return found.isEmpty ? null : found.first;
  }

  /// All annotations of class [name] on [element], in order.
  List<DartObject> all(Element element, String name) {
    List<DartObject> found = <DartObject>[];
    for (ElementAnnotation annotation in element.metadata.annotations) {
      DartObject? value = annotation.computeConstantValue();
      DartType? type = value?.type;
      if (value != null && type is InterfaceType && type.element.name == name) {
        found.add(value);
      }
    }
    return found;
  }

  /// True when [element] has an annotation of class [name].
  bool has(Element element, String name) {
    return first(element, name) != null;
  }
}

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/validation/type.dart';

class NestedValidationVisitor {
  final String field;
  final Map<String, dynamic> data;
  final String rule;

  final List<ValidationItem> fieldsToValidate = [];

  NestedValidationVisitor({
    required this.data,
    required this.field,
    required this.rule,
  }) {
    _process();
  }

  _process() {
    var parts = field.split('.*.');

    /// eg. from products.*.{field} to products
    var mainField = parts[0];

    /// getting list of products from data.
    var list = data.getParam(mainField);

    /// remove main filed to loop and get final field to validate
    List fieldsExceptMainField = parts.sublist(1);

    _processNestedField(mainField, fieldsExceptMainField, rule, list);
  }

  _processNestedField(
    mainField,
    List fields,
    String rule,
    List<Map<String, dynamic>> items,
  ) {
    items.asMap().forEach((index, item) {
      String field = fields.first;
      String fieldNameWithPositionIndex = '$mainField.$index.$field';

      /// this mean we already get field value to validate
      if (fields.length == 1) {
        var value = item.getParam(field);

        fieldsToValidate.add(ValidationItem(
          field: fieldNameWithPositionIndex,
          name: field.split('.').last,
          value: value,
          rule: rule,
        ));
      }

      /// this mean we still need to get the actual field value
      else if (fields.length >= 2) {
        List fieldsExceptMainField = fields.sublist(1);
        List<Map<String, dynamic>> newItems = item.getParam(field);

        _processNestedField(
          fieldNameWithPositionIndex,
          fieldsExceptMainField,
          rule,
          newItems,
        );
      }
    });
  }
}

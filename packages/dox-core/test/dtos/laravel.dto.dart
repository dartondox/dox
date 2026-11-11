import 'package:dox_core/dox_core.dart';

part 'laravel.dto.g.dart';

/// Options and Laravel rules of dox_validation, built by dox_builder.
@Dto(
  trim: true,
  coerce: true,
  attributes: <String, String>{'first_name': 'first name'},
)
class LaravelRules {
  final String firstName;

  final int age;

  @Accepted()
  final bool terms;

  final DateTime start;

  @After('start')
  final DateTime end;

  final String? type;

  @RequiredUnless('type', 'person')
  final String? company;

  @ExcludeIf('type', 'person')
  @MinLength(3)
  final String? vat;

  @Prohibited()
  final String? debug;

  @Different('first_name')
  final String? nick;

  @Ulid()
  final String? id;

  @GreaterThanField('age')
  final int? max;

  const LaravelRules({
    required this.firstName,
    required this.age,
    required this.terms,
    required this.start,
    required this.end,
    this.type,
    this.company,
    this.vat,
    this.debug,
    this.nick,
    this.id,
    this.max,
  });

  static const DtoSchema<LaravelRules> schema = $LaravelRulesDto;
}

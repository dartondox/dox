import 'package:dox_core/dox_core.dart';

import 'rules.dto.dart' show Role;

part 'response.dto.g.dart';

/// A DTO with its own toJson(): a response has the map of that method.
@Dto()
class OwnJson {
  final int id;

  const OwnJson({required this.id});

  Map<String, dynamic> toJson() => <String, dynamic>{'my_id': id};
}

/// A plain DTO for a response.
@Dto()
class ProductView {
  final int id;
  final String productName;
  final double price;
  final bool inStock;
  final DateTime? soldAt;

  const ProductView({
    required this.id,
    required this.productName,
    required this.price,
    required this.inStock,
    this.soldAt,
  });
}

/// Values that toMap() changes before they are JSON: dates and enums in
/// lists and maps, and a nested DTO with its own toJson().
@Dto()
class MixedView {
  final List<DateTime> dates;
  final List<Role> roles;
  final Map<String, DateTime> days;
  final List<List<Role>> grid;
  final OwnJson own;
  final List<OwnJson> owns;
  final ProductView? product;
  final List<ProductView> products;
  final Map<String, ProductView> byName;

  const MixedView({
    required this.dates,
    required this.roles,
    required this.days,
    required this.grid,
    required this.own,
    required this.owns,
    required this.products,
    required this.byName,
    this.product,
  });
}

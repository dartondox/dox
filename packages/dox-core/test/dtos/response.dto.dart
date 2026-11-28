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

/// A [ProductView] with one more field. In a field declared as
/// [ProductView], only the fields of [ProductView] are in the JSON.
@Dto()
class SecretProductView implements ProductView {
  @override
  final int id;
  @override
  final String productName;
  @override
  final double price;
  @override
  final bool inStock;
  @override
  final DateTime? soldAt;
  final String secret;

  const SecretProductView({
    required this.id,
    required this.productName,
    required this.price,
    required this.inStock,
    required this.secret,
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
  final List<ProductView>? maybeProducts;
  final Map<String, ProductView>? maybeByName;
  final List<DateTime>? maybeDates;
  final Map<String, ProductView?> sparse;
  final Map<String, DateTime?> sparseDays;
  final Map<String, XRay> xrays;

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
    this.maybeProducts,
    this.maybeByName,
    this.maybeDates,
    this.sparse = const <String, ProductView?>{},
    this.sparseDays = const <String, DateTime?>{},
    this.xrays = const <String, XRay>{},
  });
}

/// A name with a capital X, in a map of [MixedView].
@Dto()
class XRay {
  final int id;
  const XRay({required this.id});
}

/// Lists and a nested DTO that the generated code writes directly, and a
/// key that JSON must escape.
@Dto()
class RunsView {
  final int id;
  final List<String> tags;
  final List<String?> notes;
  final List<int> numbers;
  final List<bool> flags;
  final ProductView main;
  final List<ProductView> products;
  @Name('a "key" é \\ \$x')
  final String odd;
  final bool active;

  const RunsView({
    required this.id,
    required this.tags,
    required this.notes,
    required this.numbers,
    required this.flags,
    required this.main,
    required this.products,
    required this.odd,
    required this.active,
  });
}

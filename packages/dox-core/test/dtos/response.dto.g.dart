// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'response.dto.dart';

// **************************************************************************
// DoxDtoGenerator
// **************************************************************************

// ignore_for_file: type=lint

/// The checks, the converter and the JSON Schema of [OwnJson].
const DtoSchema<OwnJson> $OwnJsonDto = _$OwnJsonDto();

class _$OwnJsonDto extends DtoSchema<OwnJson> {
  const _$OwnJsonDto();

  static const Map<String, String> _m = <String, String>{};

  @override
  Type get type => OwnJson;

  @override
  String get name => 'OwnJson';

  @override
  bool get usesRequiredWhen => false;

  @override
  OwnJson? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // id: int
    Object? c0;
    c0 = s.integer(s.read(input, 'id'), p, 'id', _m);
    if (c0 == null || c0 is Undefined) s.required(p, 'id', _m);
    if (s.issues.length != e && !s.allErrors) return null;
    if (s.issues.length != e) return null;
    return OwnJson(id: c0 as int);
  }

  @override
  OwnJson fromMap(Map<String, dynamic> m) {
    return OwnJson(id: (m['id'] as num).toInt());
  }

  @override
  Map<String, dynamic> toMap(OwnJson o) {
    int f0 = o.id;
    return <String, dynamic>{'id': f0};
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'OwnJson',
      'properties': <String, dynamic>{
        'id': <String, dynamic>{'type': 'integer'},
      },
      'required': <dynamic>['id'],
    };
  }
}

/// The checks, the converter and the JSON Schema of [ProductView].
const DtoSchema<ProductView> $ProductViewDto = _$ProductViewDto();

class _$ProductViewDto extends DtoSchema<ProductView>
    implements JsonObjectWriter {
  const _$ProductViewDto();

  static const Map<String, String> _m = <String, String>{};

  static final JsonRun _j0 = JsonRun('{"id":');
  static final JsonRun _j1 = JsonRun(',"product_name":');
  static final JsonRun _j2 = JsonRun(',"price":');
  static final JsonRun _j3 = JsonRun(',"in_stock":');
  static final JsonRun _j4 = JsonRun(',"sold_at":');
  static final JsonRun _j5 = JsonRun('}');

  @override
  Type get type => ProductView;

  @override
  String get name => 'ProductView';

  @override
  bool get usesRequiredWhen => false;

  @override
  ProductView? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // id: int
    Object? c0;
    c0 = s.integer(s.read(input, 'id'), p, 'id', _m);
    if (c0 == null || c0 is Undefined) s.required(p, 'id', _m);
    // productName: String
    Object? c1;
    c1 = s.string(s.read(input, 'product_name'), p, 'product_name', _m);
    if (c1 == null || c1 is Undefined) s.required(p, 'product_name', _m);
    // price: double
    Object? c2;
    c2 = s.decimal(s.read(input, 'price'), p, 'price', _m);
    if (c2 == null || c2 is Undefined) s.required(p, 'price', _m);
    // inStock: bool
    Object? c3;
    c3 = s.boolean(s.read(input, 'in_stock'), p, 'in_stock', _m);
    if (c3 == null || c3 is Undefined) s.required(p, 'in_stock', _m);
    // soldAt: DateTime?
    Object? c4;
    c4 = s.date(s.read(input, 'sold_at'), p, 'sold_at', _m);
    if (s.issues.length != e && !s.allErrors) return null;
    if (s.issues.length != e) return null;
    return ProductView(
      id: c0 as int,
      productName: c1 as String,
      price: c2 as double,
      inStock: c3 as bool,
      soldAt: c4 is Undefined ? null : c4 as DateTime?,
    );
  }

  @override
  ProductView fromMap(Map<String, dynamic> m) {
    return ProductView(
      id: (m['id'] as num).toInt(),
      productName: m['product_name'] as String,
      price: (m['price'] as num).toDouble(),
      inStock: m['in_stock'] as bool,
      soldAt: m['sold_at'] == null
          ? null
          : (DateTime.parse(m['sold_at'] as String).toUtc()),
    );
  }

  @override
  Map<String, dynamic> toMap(ProductView o) {
    int f0 = o.id;
    String f1 = o.productName;
    double f2 = o.price;
    bool f3 = o.inStock;
    DateTime? f4 = o.soldAt;
    return <String, dynamic>{
      'id': f0,
      'product_name': f1,
      'price': f2,
      'in_stock': f3,
      'sold_at': f4 == null ? null : f4.toIso8601String(),
    };
  }

  @override
  void writeObject(Object object, JsonWriter w) =>
      $writeProductView(object as ProductView, w);
  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'ProductView',
      'properties': <String, dynamic>{
        'id': <String, dynamic>{'type': 'integer'},
        'product_name': <String, dynamic>{'type': 'string'},
        'price': <String, dynamic>{'type': 'number'},
        'in_stock': <String, dynamic>{'type': 'boolean'},
        'sold_at': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'format': 'date-time',
        },
      },
      'required': <dynamic>['id', 'product_name', 'price', 'in_stock'],
    };
  }
}

/// Writes the JSON of [ProductView], as `toMap()` gives it.
void $writeProductView(ProductView o, JsonWriter w) {
  w.run(_$ProductViewDto._j0);
  w.integer(o.id);
  w.run(_$ProductViewDto._j1);
  w.string(o.productName);
  w.run(_$ProductViewDto._j2);
  w.value(o.price);
  w.run(_$ProductViewDto._j3);
  w.boolean(o.inStock);
  w.run(_$ProductViewDto._j4);
  w.dateTime(o.soldAt);
  w.run(_$ProductViewDto._j5);
}

/// The checks, the converter and the JSON Schema of [SecretProductView].
const DtoSchema<SecretProductView> $SecretProductViewDto =
    _$SecretProductViewDto();

class _$SecretProductViewDto extends DtoSchema<SecretProductView>
    implements JsonObjectWriter {
  const _$SecretProductViewDto();

  static const Map<String, String> _m = <String, String>{};

  static final JsonRun _j0 = JsonRun('{"id":');
  static final JsonRun _j1 = JsonRun(',"product_name":');
  static final JsonRun _j2 = JsonRun(',"price":');
  static final JsonRun _j3 = JsonRun(',"in_stock":');
  static final JsonRun _j4 = JsonRun(',"sold_at":');
  static final JsonRun _j5 = JsonRun(',"secret":');
  static final JsonRun _j6 = JsonRun('}');

  @override
  Type get type => SecretProductView;

  @override
  String get name => 'SecretProductView';

  @override
  bool get usesRequiredWhen => false;

  @override
  SecretProductView? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // id: int
    Object? c0;
    c0 = s.integer(s.read(input, 'id'), p, 'id', _m);
    if (c0 == null || c0 is Undefined) s.required(p, 'id', _m);
    // productName: String
    Object? c1;
    c1 = s.string(s.read(input, 'product_name'), p, 'product_name', _m);
    if (c1 == null || c1 is Undefined) s.required(p, 'product_name', _m);
    // price: double
    Object? c2;
    c2 = s.decimal(s.read(input, 'price'), p, 'price', _m);
    if (c2 == null || c2 is Undefined) s.required(p, 'price', _m);
    // inStock: bool
    Object? c3;
    c3 = s.boolean(s.read(input, 'in_stock'), p, 'in_stock', _m);
    if (c3 == null || c3 is Undefined) s.required(p, 'in_stock', _m);
    // soldAt: DateTime?
    Object? c4;
    c4 = s.date(s.read(input, 'sold_at'), p, 'sold_at', _m);
    // secret: String
    Object? c5;
    c5 = s.string(s.read(input, 'secret'), p, 'secret', _m);
    if (c5 == null || c5 is Undefined) s.required(p, 'secret', _m);
    if (s.issues.length != e && !s.allErrors) return null;
    if (s.issues.length != e) return null;
    return SecretProductView(
      id: c0 as int,
      productName: c1 as String,
      price: c2 as double,
      inStock: c3 as bool,
      secret: c5 as String,
      soldAt: c4 is Undefined ? null : c4 as DateTime?,
    );
  }

  @override
  SecretProductView fromMap(Map<String, dynamic> m) {
    return SecretProductView(
      id: (m['id'] as num).toInt(),
      productName: m['product_name'] as String,
      price: (m['price'] as num).toDouble(),
      inStock: m['in_stock'] as bool,
      secret: m['secret'] as String,
      soldAt: m['sold_at'] == null
          ? null
          : (DateTime.parse(m['sold_at'] as String).toUtc()),
    );
  }

  @override
  Map<String, dynamic> toMap(SecretProductView o) {
    int f0 = o.id;
    String f1 = o.productName;
    double f2 = o.price;
    bool f3 = o.inStock;
    DateTime? f4 = o.soldAt;
    String f5 = o.secret;
    return <String, dynamic>{
      'id': f0,
      'product_name': f1,
      'price': f2,
      'in_stock': f3,
      'sold_at': f4 == null ? null : f4.toIso8601String(),
      'secret': f5,
    };
  }

  @override
  void writeObject(Object object, JsonWriter w) =>
      $writeSecretProductView(object as SecretProductView, w);
  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'SecretProductView',
      'properties': <String, dynamic>{
        'id': <String, dynamic>{'type': 'integer'},
        'product_name': <String, dynamic>{'type': 'string'},
        'price': <String, dynamic>{'type': 'number'},
        'in_stock': <String, dynamic>{'type': 'boolean'},
        'sold_at': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'format': 'date-time',
        },
        'secret': <String, dynamic>{'type': 'string'},
      },
      'required': <dynamic>[
        'id',
        'product_name',
        'price',
        'in_stock',
        'secret',
      ],
    };
  }
}

/// Writes the JSON of [SecretProductView], as `toMap()` gives it.
void $writeSecretProductView(SecretProductView o, JsonWriter w) {
  w.run(_$SecretProductViewDto._j0);
  w.integer(o.id);
  w.run(_$SecretProductViewDto._j1);
  w.string(o.productName);
  w.run(_$SecretProductViewDto._j2);
  w.value(o.price);
  w.run(_$SecretProductViewDto._j3);
  w.boolean(o.inStock);
  w.run(_$SecretProductViewDto._j4);
  w.dateTime(o.soldAt);
  w.run(_$SecretProductViewDto._j5);
  w.string(o.secret);
  w.run(_$SecretProductViewDto._j6);
}

/// The checks, the converter and the JSON Schema of [MixedView].
const DtoSchema<MixedView> $MixedViewDto = _$MixedViewDto();

class _$MixedViewDto extends DtoSchema<MixedView> implements JsonObjectWriter {
  const _$MixedViewDto();

  static const Map<String, String> _m = <String, String>{};

  static final JsonRun _j0 = JsonRun('{"dates":[');
  static final JsonRun _j1 = JsonRun('],"roles":[');
  static final JsonRun _j2 = JsonRun('],"days":');
  static final JsonRun _j3 = JsonRun(',"grid":');
  static final JsonRun _j4 = JsonRun(',"own":');
  static final JsonRun _j5 = JsonRun(',"owns":');
  static final JsonRun _j6 = JsonRun(',"product":');
  static final JsonRun _j7 = JsonRun(',"products":[');
  static final JsonRun _j8 = JsonRun('],"by_name":');
  static final JsonRun _j9 = JsonRun(',"maybe_products":');
  static final JsonRun _j10 = JsonRun(',"maybe_by_name":');
  static final JsonRun _j11 = JsonRun(',"maybe_dates":');
  static final JsonRun _j12 = JsonRun('}');

  @override
  Type get type => MixedView;

  @override
  String get name => 'MixedView';

  @override
  bool get usesRequiredWhen => false;

  @override
  MixedView? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // dates: List<DateTime>
    Object? c0;
    c0 = s.list(s.read(input, 'dates'), p, 'dates', _m);
    if (c0 is List) {
      int b0 = s.issues.length;
      List<Object> q0 = <Object>[...p, 'dates'];
      List<DateTime> o0 = <DateTime>[];
      for (int i0 = 0; i0 < c0.length; i0++) {
        Object? x0;
        x0 = s.date(c0[i0], q0, i0, _m);
        if (x0 == null || x0 is Undefined) {
          s.required(q0, i0, _m);
        } else if (x0 is! Invalid) {
          o0.add(x0 as DateTime);
        }
      }
      c0 = s.issues.length != b0 ? invalid : o0;
    }
    if (c0 == null || c0 is Undefined || s.emptyList(c0)) {
      s.required(p, 'dates', _m);
      c0 = invalid;
    }
    // roles: List<Role>
    Object? c1;
    c1 = s.list(s.read(input, 'roles'), p, 'roles', _m);
    if (c1 is List) {
      int b0 = s.issues.length;
      List<Object> q0 = <Object>[...p, 'roles'];
      List<Role> o0 = <Role>[];
      for (int i0 = 0; i0 < c1.length; i0++) {
        Object? x0;
        x0 = s.enumName(c1[i0], q0, i0, _m, const <String>['admin', 'user']);
        if (x0 is String) {
          x0 = switch (x0) {
            'admin' => Role.admin,
            _ => Role.user,
          };
        }
        if (x0 == null || x0 is Undefined) {
          s.required(q0, i0, _m);
        } else if (x0 is! Invalid) {
          o0.add(x0 as Role);
        }
      }
      c1 = s.issues.length != b0 ? invalid : o0;
    }
    if (c1 == null || c1 is Undefined || s.emptyList(c1)) {
      s.required(p, 'roles', _m);
      c1 = invalid;
    }
    // days: Map<String, DateTime>
    Object? c2;
    c2 = s.object(s.read(input, 'days'), p, 'days', _m);
    if (c2 is Map) {
      int b0 = s.issues.length;
      List<Object> q0 = <Object>[...p, 'days'];
      Map<String, DateTime> o0 = <String, DateTime>{};
      for (MapEntry<dynamic, dynamic> n0 in c2.entries) {
        String k0 = '${n0.key}';
        Object? x0;
        x0 = s.date(n0.value, q0, k0, _m);
        if (x0 == null || x0 is Undefined) {
          s.required(q0, k0, _m);
        } else if (x0 is! Invalid) {
          o0[k0] = x0 as DateTime;
        }
      }
      c2 = s.issues.length != b0 ? invalid : o0;
    }
    if (c2 == null || c2 is Undefined) s.required(p, 'days', _m);
    // grid: List<List<Role>>
    Object? c3;
    c3 = s.list(s.read(input, 'grid'), p, 'grid', _m);
    if (c3 is List) {
      int b0 = s.issues.length;
      List<Object> q0 = <Object>[...p, 'grid'];
      List<List<Role>> o0 = <List<Role>>[];
      for (int i0 = 0; i0 < c3.length; i0++) {
        Object? x0;
        x0 = s.list(c3[i0], q0, i0, _m);
        if (x0 is List) {
          int b1 = s.issues.length;
          List<Object> q1 = <Object>[...q0, i0];
          List<Role> o1 = <Role>[];
          for (int i1 = 0; i1 < x0.length; i1++) {
            Object? x1;
            x1 = s.enumName(x0[i1], q1, i1, _m, const <String>[
              'admin',
              'user',
            ]);
            if (x1 is String) {
              x1 = switch (x1) {
                'admin' => Role.admin,
                _ => Role.user,
              };
            }
            if (x1 == null || x1 is Undefined) {
              s.required(q1, i1, _m);
            } else if (x1 is! Invalid) {
              o1.add(x1 as Role);
            }
          }
          x0 = s.issues.length != b1 ? invalid : o1;
        }
        if (x0 == null || x0 is Undefined) {
          s.required(q0, i0, _m);
        } else if (x0 is! Invalid) {
          o0.add(x0 as List<Role>);
        }
      }
      c3 = s.issues.length != b0 ? invalid : o0;
    }
    if (c3 == null || c3 is Undefined || s.emptyList(c3)) {
      s.required(p, 'grid', _m);
      c3 = invalid;
    }
    // own: OwnJson
    Object? c4;
    c4 = s.object(s.read(input, 'own'), p, 'own', _m);
    if (c4 is Map) {
      c4 = $OwnJsonDto.convert(c4, s, <Object>[...p, 'own']) ?? invalid;
    }
    if (c4 == null || c4 is Undefined) s.required(p, 'own', _m);
    // owns: List<OwnJson>
    Object? c5;
    c5 = s.list(s.read(input, 'owns'), p, 'owns', _m);
    if (c5 is List) {
      int b0 = s.issues.length;
      List<Object> q0 = <Object>[...p, 'owns'];
      List<OwnJson> o0 = <OwnJson>[];
      for (int i0 = 0; i0 < c5.length; i0++) {
        Object? x0;
        x0 = s.object(c5[i0], q0, i0, _m);
        if (x0 is Map) {
          x0 = $OwnJsonDto.convert(x0, s, <Object>[...q0, i0]) ?? invalid;
        }
        if (x0 == null || x0 is Undefined) {
          s.required(q0, i0, _m);
        } else if (x0 is! Invalid) {
          o0.add(x0 as OwnJson);
        }
      }
      c5 = s.issues.length != b0 ? invalid : o0;
    }
    if (c5 == null || c5 is Undefined || s.emptyList(c5)) {
      s.required(p, 'owns', _m);
      c5 = invalid;
    }
    // product: ProductView?
    Object? c6;
    c6 = s.object(s.read(input, 'product'), p, 'product', _m);
    if (c6 is Map) {
      c6 = $ProductViewDto.convert(c6, s, <Object>[...p, 'product']) ?? invalid;
    }
    // products: List<ProductView>
    Object? c7;
    c7 = s.list(s.read(input, 'products'), p, 'products', _m);
    if (c7 is List) {
      int b0 = s.issues.length;
      List<Object> q0 = <Object>[...p, 'products'];
      List<ProductView> o0 = <ProductView>[];
      for (int i0 = 0; i0 < c7.length; i0++) {
        Object? x0;
        x0 = s.object(c7[i0], q0, i0, _m);
        if (x0 is Map) {
          x0 = $ProductViewDto.convert(x0, s, <Object>[...q0, i0]) ?? invalid;
        }
        if (x0 == null || x0 is Undefined) {
          s.required(q0, i0, _m);
        } else if (x0 is! Invalid) {
          o0.add(x0 as ProductView);
        }
      }
      c7 = s.issues.length != b0 ? invalid : o0;
    }
    if (c7 == null || c7 is Undefined || s.emptyList(c7)) {
      s.required(p, 'products', _m);
      c7 = invalid;
    }
    // byName: Map<String, ProductView>
    Object? c8;
    c8 = s.object(s.read(input, 'by_name'), p, 'by_name', _m);
    if (c8 is Map) {
      int b0 = s.issues.length;
      List<Object> q0 = <Object>[...p, 'by_name'];
      Map<String, ProductView> o0 = <String, ProductView>{};
      for (MapEntry<dynamic, dynamic> n0 in c8.entries) {
        String k0 = '${n0.key}';
        Object? x0;
        x0 = s.object(n0.value, q0, k0, _m);
        if (x0 is Map) {
          x0 = $ProductViewDto.convert(x0, s, <Object>[...q0, k0]) ?? invalid;
        }
        if (x0 == null || x0 is Undefined) {
          s.required(q0, k0, _m);
        } else if (x0 is! Invalid) {
          o0[k0] = x0 as ProductView;
        }
      }
      c8 = s.issues.length != b0 ? invalid : o0;
    }
    if (c8 == null || c8 is Undefined) s.required(p, 'by_name', _m);
    // maybeProducts: List<ProductView>?
    Object? c9;
    c9 = s.list(s.read(input, 'maybe_products'), p, 'maybe_products', _m);
    if (c9 is List) {
      int b0 = s.issues.length;
      List<Object> q0 = <Object>[...p, 'maybe_products'];
      List<ProductView> o0 = <ProductView>[];
      for (int i0 = 0; i0 < c9.length; i0++) {
        Object? x0;
        x0 = s.object(c9[i0], q0, i0, _m);
        if (x0 is Map) {
          x0 = $ProductViewDto.convert(x0, s, <Object>[...q0, i0]) ?? invalid;
        }
        if (x0 == null || x0 is Undefined) {
          s.required(q0, i0, _m);
        } else if (x0 is! Invalid) {
          o0.add(x0 as ProductView);
        }
      }
      c9 = s.issues.length != b0 ? invalid : o0;
    }
    // maybeByName: Map<String, ProductView>?
    Object? c10;
    c10 = s.object(s.read(input, 'maybe_by_name'), p, 'maybe_by_name', _m);
    if (c10 is Map) {
      int b0 = s.issues.length;
      List<Object> q0 = <Object>[...p, 'maybe_by_name'];
      Map<String, ProductView> o0 = <String, ProductView>{};
      for (MapEntry<dynamic, dynamic> n0 in c10.entries) {
        String k0 = '${n0.key}';
        Object? x0;
        x0 = s.object(n0.value, q0, k0, _m);
        if (x0 is Map) {
          x0 = $ProductViewDto.convert(x0, s, <Object>[...q0, k0]) ?? invalid;
        }
        if (x0 == null || x0 is Undefined) {
          s.required(q0, k0, _m);
        } else if (x0 is! Invalid) {
          o0[k0] = x0 as ProductView;
        }
      }
      c10 = s.issues.length != b0 ? invalid : o0;
    }
    // maybeDates: List<DateTime>?
    Object? c11;
    c11 = s.list(s.read(input, 'maybe_dates'), p, 'maybe_dates', _m);
    if (c11 is List) {
      int b0 = s.issues.length;
      List<Object> q0 = <Object>[...p, 'maybe_dates'];
      List<DateTime> o0 = <DateTime>[];
      for (int i0 = 0; i0 < c11.length; i0++) {
        Object? x0;
        x0 = s.date(c11[i0], q0, i0, _m);
        if (x0 == null || x0 is Undefined) {
          s.required(q0, i0, _m);
        } else if (x0 is! Invalid) {
          o0.add(x0 as DateTime);
        }
      }
      c11 = s.issues.length != b0 ? invalid : o0;
    }
    if (s.issues.length != e && !s.allErrors) return null;
    if (s.issues.length != e) return null;
    return MixedView(
      dates: c0 as List<DateTime>,
      roles: c1 as List<Role>,
      days: c2 as Map<String, DateTime>,
      grid: c3 as List<List<Role>>,
      own: c4 as OwnJson,
      owns: c5 as List<OwnJson>,
      products: c7 as List<ProductView>,
      byName: c8 as Map<String, ProductView>,
      product: c6 is Undefined ? null : c6 as ProductView?,
      maybeProducts: c9 is Undefined ? null : c9 as List<ProductView>?,
      maybeByName: c10 is Undefined ? null : c10 as Map<String, ProductView>?,
      maybeDates: c11 is Undefined ? null : c11 as List<DateTime>?,
    );
  }

  @override
  MixedView fromMap(Map<String, dynamic> m) {
    return MixedView(
      dates: <DateTime>[
        for (Object? x0 in m['dates'] as List<dynamic>)
          DateTime.parse(x0 as String).toUtc(),
      ],
      roles: <Role>[
        for (Object? x0 in m['roles'] as List<dynamic>)
          Role.values.byName(x0 as String),
      ],
      days: <String, DateTime>{
        for (MapEntry<dynamic, dynamic> x0
            in (m['days'] as Map<dynamic, dynamic>).entries)
          x0.key as String: DateTime.parse(x0.value as String).toUtc(),
      },
      grid: <List<Role>>[
        for (Object? x0 in m['grid'] as List<dynamic>)
          <Role>[
            for (Object? x1 in x0 as List<dynamic>)
              Role.values.byName(x1 as String),
          ],
      ],
      own: $OwnJsonDto.fromMap(m['own'] as Map<String, dynamic>),
      owns: <OwnJson>[
        for (Object? x0 in m['owns'] as List<dynamic>)
          $OwnJsonDto.fromMap(x0 as Map<String, dynamic>),
      ],
      products: <ProductView>[
        for (Object? x0 in m['products'] as List<dynamic>)
          $ProductViewDto.fromMap(x0 as Map<String, dynamic>),
      ],
      byName: <String, ProductView>{
        for (MapEntry<dynamic, dynamic> x0
            in (m['by_name'] as Map<dynamic, dynamic>).entries)
          x0.key as String: $ProductViewDto.fromMap(
            x0.value as Map<String, dynamic>,
          ),
      },
      product: m['product'] == null
          ? null
          : ($ProductViewDto.fromMap(m['product'] as Map<String, dynamic>)),
      maybeProducts: m['maybe_products'] == null
          ? null
          : (<ProductView>[
              for (Object? x0 in m['maybe_products'] as List<dynamic>)
                $ProductViewDto.fromMap(x0 as Map<String, dynamic>),
            ]),
      maybeByName: m['maybe_by_name'] == null
          ? null
          : (<String, ProductView>{
              for (MapEntry<dynamic, dynamic> x0
                  in (m['maybe_by_name'] as Map<dynamic, dynamic>).entries)
                x0.key as String: $ProductViewDto.fromMap(
                  x0.value as Map<String, dynamic>,
                ),
            }),
      maybeDates: m['maybe_dates'] == null
          ? null
          : (<DateTime>[
              for (Object? x0 in m['maybe_dates'] as List<dynamic>)
                DateTime.parse(x0 as String).toUtc(),
            ]),
    );
  }

  @override
  Map<String, dynamic> toMap(MixedView o) {
    List<DateTime> f0 = o.dates;
    List<Role> f1 = o.roles;
    Map<String, DateTime> f2 = o.days;
    List<List<Role>> f3 = o.grid;
    OwnJson f4 = o.own;
    List<OwnJson> f5 = o.owns;
    ProductView? f6 = o.product;
    List<ProductView> f7 = o.products;
    Map<String, ProductView> f8 = o.byName;
    List<ProductView>? f9 = o.maybeProducts;
    Map<String, ProductView>? f10 = o.maybeByName;
    List<DateTime>? f11 = o.maybeDates;
    return <String, dynamic>{
      'dates': <dynamic>[for (DateTime x0 in f0) x0.toIso8601String()],
      'roles': <dynamic>[for (Role x0 in f1) x0.name],
      'days': <String, dynamic>{
        for (MapEntry<String, DateTime> x0 in f2.entries)
          x0.key: x0.value.toIso8601String(),
      },
      'grid': <dynamic>[
        for (List<Role> x0 in f3) <dynamic>[for (Role x1 in x0) x1.name],
      ],
      'own': $OwnJsonDto.toMap(f4),
      'owns': <dynamic>[for (OwnJson x0 in f5) $OwnJsonDto.toMap(x0)],
      'product': f6 == null ? null : $ProductViewDto.toMap(f6),
      'products': <dynamic>[
        for (ProductView x0 in f7) $ProductViewDto.toMap(x0),
      ],
      'by_name': <String, dynamic>{
        for (MapEntry<String, ProductView> x0 in f8.entries)
          x0.key: $ProductViewDto.toMap(x0.value),
      },
      'maybe_products': f9 == null
          ? null
          : <dynamic>[for (ProductView x0 in f9) $ProductViewDto.toMap(x0)],
      'maybe_by_name': f10 == null
          ? null
          : <String, dynamic>{
              for (MapEntry<String, ProductView> x0 in f10.entries)
                x0.key: $ProductViewDto.toMap(x0.value),
            },
      'maybe_dates': f11 == null
          ? null
          : <dynamic>[for (DateTime x0 in f11) x0.toIso8601String()],
    };
  }

  @override
  void writeObject(Object object, JsonWriter w) =>
      $writeMixedView(object as MixedView, w);
  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'MixedView',
      'properties': <String, dynamic>{
        'dates': <String, dynamic>{
          'type': 'array',
          'items': <String, dynamic>{'type': 'string', 'format': 'date-time'},
        },
        'roles': <String, dynamic>{
          'type': 'array',
          'items': <String, dynamic>{
            'type': 'string',
            'enum': <dynamic>['admin', 'user'],
          },
        },
        'days': <String, dynamic>{
          'type': 'object',
          'additionalProperties': <String, dynamic>{
            'type': 'string',
            'format': 'date-time',
          },
        },
        'grid': <String, dynamic>{
          'type': 'array',
          'items': <String, dynamic>{
            'type': 'array',
            'items': <String, dynamic>{
              'type': 'string',
              'enum': <dynamic>['admin', 'user'],
            },
          },
        },
        'own': <String, dynamic>{'\$ref': '#/\$defs/OwnJson'},
        'owns': <String, dynamic>{
          'type': 'array',
          'items': <String, dynamic>{'\$ref': '#/\$defs/OwnJson'},
        },
        'product': <String, dynamic>{
          'anyOf': <dynamic>[
            <String, dynamic>{'\$ref': '#/\$defs/ProductView'},
            <String, dynamic>{'type': 'null'},
          ],
        },
        'products': <String, dynamic>{
          'type': 'array',
          'items': <String, dynamic>{'\$ref': '#/\$defs/ProductView'},
        },
        'by_name': <String, dynamic>{
          'type': 'object',
          'additionalProperties': <String, dynamic>{
            '\$ref': '#/\$defs/ProductView',
          },
        },
        'maybe_products': <String, dynamic>{
          'type': <dynamic>['array', 'null'],
          'items': <String, dynamic>{'\$ref': '#/\$defs/ProductView'},
        },
        'maybe_by_name': <String, dynamic>{
          'type': <dynamic>['object', 'null'],
          'additionalProperties': <String, dynamic>{
            '\$ref': '#/\$defs/ProductView',
          },
        },
        'maybe_dates': <String, dynamic>{
          'type': <dynamic>['array', 'null'],
          'items': <String, dynamic>{'type': 'string', 'format': 'date-time'},
        },
      },
      'required': <dynamic>[
        'dates',
        'roles',
        'days',
        'grid',
        'own',
        'owns',
        'products',
        'by_name',
      ],
      '\$defs': <String, dynamic>{
        'OwnJson': <String, dynamic>{
          'type': 'object',
          'title': 'OwnJson',
          'properties': <String, dynamic>{
            'id': <String, dynamic>{'type': 'integer'},
          },
          'required': <dynamic>['id'],
        },
        'ProductView': <String, dynamic>{
          'type': 'object',
          'title': 'ProductView',
          'properties': <String, dynamic>{
            'id': <String, dynamic>{'type': 'integer'},
            'product_name': <String, dynamic>{'type': 'string'},
            'price': <String, dynamic>{'type': 'number'},
            'in_stock': <String, dynamic>{'type': 'boolean'},
            'sold_at': <String, dynamic>{
              'type': <dynamic>['string', 'null'],
              'format': 'date-time',
            },
          },
          'required': <dynamic>['id', 'product_name', 'price', 'in_stock'],
        },
      },
    };
  }
}

/// Writes the JSON of [MixedView], as `toMap()` gives it.
void $writeMixedView(MixedView o, JsonWriter w) {
  w.run(_$MixedViewDto._j0);
  {
    List<DateTime> l0 = o.dates;
    for (int i = 0; i < l0.length; i++) {
      if (i > 0) w.run(JsonRun.comma);
      w.dateTime(l0[i]);
    }
  }
  w.run(_$MixedViewDto._j1);
  {
    List<Role> l1 = o.roles;
    for (int i = 0; i < l1.length; i++) {
      if (i > 0) w.run(JsonRun.comma);
      w.string(l1[i].name);
    }
  }
  w.run(_$MixedViewDto._j2);
  w.value(<String, dynamic>{
    for (MapEntry<String, DateTime> x0 in o.days.entries)
      x0.key: x0.value.toIso8601String(),
  });
  w.run(_$MixedViewDto._j3);
  w.value(<dynamic>[
    for (List<Role> x0 in o.grid) <dynamic>[for (Role x1 in x0) x1.name],
  ]);
  w.run(_$MixedViewDto._j4);
  w.value($OwnJsonDto.toMap(o.own));
  w.run(_$MixedViewDto._j5);
  w.value(<dynamic>[for (OwnJson x0 in o.owns) $OwnJsonDto.toMap(x0)]);
  w.run(_$MixedViewDto._j6);
  if (o.product case final v?) {
    $writeProductView(v, w);
  } else {
    w.value(null);
  }
  w.run(_$MixedViewDto._j7);
  {
    List<ProductView> l7 = o.products;
    for (int i = 0; i < l7.length; i++) {
      if (i > 0) w.run(JsonRun.comma);
      $writeProductView(l7[i], w);
    }
  }
  w.run(_$MixedViewDto._j8);
  w.value(<String, dynamic>{
    for (MapEntry<String, ProductView> x0 in o.byName.entries)
      x0.key: $ProductViewDto.toMap(x0.value),
  });
  w.run(_$MixedViewDto._j9);
  {
    List<ProductView>? n = o.maybeProducts;
    w.value(
      n == null
          ? null
          : <dynamic>[for (ProductView x0 in n) $ProductViewDto.toMap(x0)],
    );
  }
  w.run(_$MixedViewDto._j10);
  {
    Map<String, ProductView>? n = o.maybeByName;
    w.value(
      n == null
          ? null
          : <String, dynamic>{
              for (MapEntry<String, ProductView> x0 in n.entries)
                x0.key: $ProductViewDto.toMap(x0.value),
            },
    );
  }
  w.run(_$MixedViewDto._j11);
  {
    List<DateTime>? n = o.maybeDates;
    w.value(
      n == null ? null : <dynamic>[for (DateTime x0 in n) x0.toIso8601String()],
    );
  }
  w.run(_$MixedViewDto._j12);
}

/// The checks, the converter and the JSON Schema of [RunsView].
const DtoSchema<RunsView> $RunsViewDto = _$RunsViewDto();

class _$RunsViewDto extends DtoSchema<RunsView> implements JsonObjectWriter {
  const _$RunsViewDto();

  static const Map<String, String> _m = <String, String>{};

  static final JsonRun _j0 = JsonRun('{"id":');
  static final JsonRun _j1 = JsonRun(',"tags":[');
  static final JsonRun _j2 = JsonRun('],"notes":[');
  static final JsonRun _j3 = JsonRun('],"numbers":[');
  static final JsonRun _j4 = JsonRun('],"flags":[');
  static final JsonRun _j5 = JsonRun('],"main":');
  static final JsonRun _j6 = JsonRun(',"products":[');
  static final JsonRun _j7 = JsonRun('],"a \\"key\\" é \\\\ \$x":');
  static final JsonRun _j8 = JsonRun(',"active":');
  static final JsonRun _j9 = JsonRun('}');

  @override
  Type get type => RunsView;

  @override
  String get name => 'RunsView';

  @override
  bool get usesRequiredWhen => false;

  @override
  RunsView? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // id: int
    Object? c0;
    c0 = s.integer(s.read(input, 'id'), p, 'id', _m);
    if (c0 == null || c0 is Undefined) s.required(p, 'id', _m);
    // tags: List<String>
    Object? c1;
    c1 = s.list(s.read(input, 'tags'), p, 'tags', _m);
    if (c1 is List) {
      int b0 = s.issues.length;
      List<Object> q0 = <Object>[...p, 'tags'];
      List<String> o0 = <String>[];
      for (int i0 = 0; i0 < c1.length; i0++) {
        Object? x0;
        x0 = s.string(c1[i0], q0, i0, _m);
        if (x0 == null || x0 is Undefined) {
          s.required(q0, i0, _m);
        } else if (x0 is! Invalid) {
          o0.add(x0 as String);
        }
      }
      c1 = s.issues.length != b0 ? invalid : o0;
    }
    if (c1 == null || c1 is Undefined || s.emptyList(c1)) {
      s.required(p, 'tags', _m);
      c1 = invalid;
    }
    // notes: List<String?>
    Object? c2;
    c2 = s.list(s.read(input, 'notes'), p, 'notes', _m);
    if (c2 is List) {
      int b0 = s.issues.length;
      List<Object> q0 = <Object>[...p, 'notes'];
      List<String?> o0 = <String?>[];
      for (int i0 = 0; i0 < c2.length; i0++) {
        Object? x0;
        x0 = s.string(c2[i0], q0, i0, _m);
        if (x0 == null || x0 is Undefined) {
          o0.add(null);
        } else if (x0 is! Invalid) {
          o0.add(x0 as String?);
        }
      }
      c2 = s.issues.length != b0 ? invalid : o0;
    }
    if (c2 == null || c2 is Undefined || s.emptyList(c2)) {
      s.required(p, 'notes', _m);
      c2 = invalid;
    }
    // numbers: List<int>
    Object? c3;
    c3 = s.list(s.read(input, 'numbers'), p, 'numbers', _m);
    if (c3 is List) {
      int b0 = s.issues.length;
      List<Object> q0 = <Object>[...p, 'numbers'];
      List<int> o0 = <int>[];
      for (int i0 = 0; i0 < c3.length; i0++) {
        Object? x0;
        x0 = s.integer(c3[i0], q0, i0, _m);
        if (x0 == null || x0 is Undefined) {
          s.required(q0, i0, _m);
        } else if (x0 is! Invalid) {
          o0.add(x0 as int);
        }
      }
      c3 = s.issues.length != b0 ? invalid : o0;
    }
    if (c3 == null || c3 is Undefined || s.emptyList(c3)) {
      s.required(p, 'numbers', _m);
      c3 = invalid;
    }
    // flags: List<bool>
    Object? c4;
    c4 = s.list(s.read(input, 'flags'), p, 'flags', _m);
    if (c4 is List) {
      int b0 = s.issues.length;
      List<Object> q0 = <Object>[...p, 'flags'];
      List<bool> o0 = <bool>[];
      for (int i0 = 0; i0 < c4.length; i0++) {
        Object? x0;
        x0 = s.boolean(c4[i0], q0, i0, _m);
        if (x0 == null || x0 is Undefined) {
          s.required(q0, i0, _m);
        } else if (x0 is! Invalid) {
          o0.add(x0 as bool);
        }
      }
      c4 = s.issues.length != b0 ? invalid : o0;
    }
    if (c4 == null || c4 is Undefined || s.emptyList(c4)) {
      s.required(p, 'flags', _m);
      c4 = invalid;
    }
    // main: ProductView
    Object? c5;
    c5 = s.object(s.read(input, 'main'), p, 'main', _m);
    if (c5 is Map) {
      c5 = $ProductViewDto.convert(c5, s, <Object>[...p, 'main']) ?? invalid;
    }
    if (c5 == null || c5 is Undefined) s.required(p, 'main', _m);
    // products: List<ProductView>
    Object? c6;
    c6 = s.list(s.read(input, 'products'), p, 'products', _m);
    if (c6 is List) {
      int b0 = s.issues.length;
      List<Object> q0 = <Object>[...p, 'products'];
      List<ProductView> o0 = <ProductView>[];
      for (int i0 = 0; i0 < c6.length; i0++) {
        Object? x0;
        x0 = s.object(c6[i0], q0, i0, _m);
        if (x0 is Map) {
          x0 = $ProductViewDto.convert(x0, s, <Object>[...q0, i0]) ?? invalid;
        }
        if (x0 == null || x0 is Undefined) {
          s.required(q0, i0, _m);
        } else if (x0 is! Invalid) {
          o0.add(x0 as ProductView);
        }
      }
      c6 = s.issues.length != b0 ? invalid : o0;
    }
    if (c6 == null || c6 is Undefined || s.emptyList(c6)) {
      s.required(p, 'products', _m);
      c6 = invalid;
    }
    // odd: String
    Object? c7;
    c7 = s.string(s.read(input, 'a "key" é \\ \$x'), p, 'a "key" é \\ \$x', _m);
    if (c7 == null || c7 is Undefined) s.required(p, 'a "key" é \\ \$x', _m);
    // active: bool
    Object? c8;
    c8 = s.boolean(s.read(input, 'active'), p, 'active', _m);
    if (c8 == null || c8 is Undefined) s.required(p, 'active', _m);
    if (s.issues.length != e && !s.allErrors) return null;
    if (s.issues.length != e) return null;
    return RunsView(
      id: c0 as int,
      tags: c1 as List<String>,
      notes: c2 as List<String?>,
      numbers: c3 as List<int>,
      flags: c4 as List<bool>,
      main: c5 as ProductView,
      products: c6 as List<ProductView>,
      odd: c7 as String,
      active: c8 as bool,
    );
  }

  @override
  RunsView fromMap(Map<String, dynamic> m) {
    return RunsView(
      id: (m['id'] as num).toInt(),
      tags: <String>[
        for (Object? x0 in m['tags'] as List<dynamic>) x0 as String,
      ],
      notes: <String?>[
        for (Object? x0 in m['notes'] as List<dynamic>)
          x0 == null ? null : (x0 as String),
      ],
      numbers: <int>[
        for (Object? x0 in m['numbers'] as List<dynamic>) (x0 as num).toInt(),
      ],
      flags: <bool>[for (Object? x0 in m['flags'] as List<dynamic>) x0 as bool],
      main: $ProductViewDto.fromMap(m['main'] as Map<String, dynamic>),
      products: <ProductView>[
        for (Object? x0 in m['products'] as List<dynamic>)
          $ProductViewDto.fromMap(x0 as Map<String, dynamic>),
      ],
      odd: m['a "key" é \\ \$x'] as String,
      active: m['active'] as bool,
    );
  }

  @override
  Map<String, dynamic> toMap(RunsView o) {
    int f0 = o.id;
    List<String> f1 = o.tags;
    List<String?> f2 = o.notes;
    List<int> f3 = o.numbers;
    List<bool> f4 = o.flags;
    ProductView f5 = o.main;
    List<ProductView> f6 = o.products;
    String f7 = o.odd;
    bool f8 = o.active;
    return <String, dynamic>{
      'id': f0,
      'tags': f1,
      'notes': f2,
      'numbers': f3,
      'flags': f4,
      'main': $ProductViewDto.toMap(f5),
      'products': <dynamic>[
        for (ProductView x0 in f6) $ProductViewDto.toMap(x0),
      ],
      'a "key" é \\ \$x': f7,
      'active': f8,
    };
  }

  @override
  void writeObject(Object object, JsonWriter w) =>
      $writeRunsView(object as RunsView, w);
  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'RunsView',
      'properties': <String, dynamic>{
        'id': <String, dynamic>{'type': 'integer'},
        'tags': <String, dynamic>{
          'type': 'array',
          'items': <String, dynamic>{'type': 'string'},
        },
        'notes': <String, dynamic>{
          'type': 'array',
          'items': <String, dynamic>{
            'type': <dynamic>['string', 'null'],
          },
        },
        'numbers': <String, dynamic>{
          'type': 'array',
          'items': <String, dynamic>{'type': 'integer'},
        },
        'flags': <String, dynamic>{
          'type': 'array',
          'items': <String, dynamic>{'type': 'boolean'},
        },
        'main': <String, dynamic>{'\$ref': '#/\$defs/ProductView'},
        'products': <String, dynamic>{
          'type': 'array',
          'items': <String, dynamic>{'\$ref': '#/\$defs/ProductView'},
        },
        'a "key" é \\ \$x': <String, dynamic>{'type': 'string'},
        'active': <String, dynamic>{'type': 'boolean'},
      },
      'required': <dynamic>[
        'id',
        'tags',
        'notes',
        'numbers',
        'flags',
        'main',
        'products',
        'a "key" é \\ \$x',
        'active',
      ],
      '\$defs': <String, dynamic>{
        'ProductView': <String, dynamic>{
          'type': 'object',
          'title': 'ProductView',
          'properties': <String, dynamic>{
            'id': <String, dynamic>{'type': 'integer'},
            'product_name': <String, dynamic>{'type': 'string'},
            'price': <String, dynamic>{'type': 'number'},
            'in_stock': <String, dynamic>{'type': 'boolean'},
            'sold_at': <String, dynamic>{
              'type': <dynamic>['string', 'null'],
              'format': 'date-time',
            },
          },
          'required': <dynamic>['id', 'product_name', 'price', 'in_stock'],
        },
      },
    };
  }
}

/// Writes the JSON of [RunsView], as `toMap()` gives it.
void $writeRunsView(RunsView o, JsonWriter w) {
  w.run(_$RunsViewDto._j0);
  w.integer(o.id);
  w.run(_$RunsViewDto._j1);
  {
    List<String> l1 = o.tags;
    for (int i = 0; i < l1.length; i++) {
      if (i > 0) w.run(JsonRun.comma);
      w.string(l1[i]);
    }
  }
  w.run(_$RunsViewDto._j2);
  {
    List<String?> l2 = o.notes;
    for (int i = 0; i < l2.length; i++) {
      if (i > 0) w.run(JsonRun.comma);
      w.string(l2[i]);
    }
  }
  w.run(_$RunsViewDto._j3);
  {
    List<int> l3 = o.numbers;
    for (int i = 0; i < l3.length; i++) {
      if (i > 0) w.run(JsonRun.comma);
      w.integer(l3[i]);
    }
  }
  w.run(_$RunsViewDto._j4);
  {
    List<bool> l4 = o.flags;
    for (int i = 0; i < l4.length; i++) {
      if (i > 0) w.run(JsonRun.comma);
      w.boolean(l4[i]);
    }
  }
  w.run(_$RunsViewDto._j5);
  $writeProductView(o.main, w);
  w.run(_$RunsViewDto._j6);
  {
    List<ProductView> l6 = o.products;
    for (int i = 0; i < l6.length; i++) {
      if (i > 0) w.run(JsonRun.comma);
      $writeProductView(l6[i], w);
    }
  }
  w.run(_$RunsViewDto._j7);
  w.string(o.odd);
  w.run(_$RunsViewDto._j8);
  w.boolean(o.active);
  w.run(_$RunsViewDto._j9);
}

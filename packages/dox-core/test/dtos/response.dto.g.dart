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
  void writeObject(Object object, JsonWriter w) {
    ProductView o = object as ProductView;
    w.startObject();
    w.key('id');
    w.integer(o.id);
    w.key('product_name');
    w.string(o.productName);
    w.key('price');
    w.value(o.price);
    w.key('in_stock');
    w.value(o.inStock);
    w.key('sold_at');
    w.dateTime(o.soldAt);
    w.endObject();
  }

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

/// The checks, the converter and the JSON Schema of [MixedView].
const DtoSchema<MixedView> $MixedViewDto = _$MixedViewDto();

class _$MixedViewDto extends DtoSchema<MixedView> implements JsonObjectWriter {
  const _$MixedViewDto();

  static const Map<String, String> _m = <String, String>{};

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
    };
  }

  @override
  void writeObject(Object object, JsonWriter w) {
    MixedView o = object as MixedView;
    w.startObject();
    w.key('dates');
    w.value(<dynamic>[for (DateTime x0 in o.dates) x0.toIso8601String()]);
    w.key('roles');
    w.value(<dynamic>[for (Role x0 in o.roles) x0.name]);
    w.key('days');
    w.value(<String, dynamic>{
      for (MapEntry<String, DateTime> x0 in o.days.entries)
        x0.key: x0.value.toIso8601String(),
    });
    w.key('grid');
    w.value(<dynamic>[
      for (List<Role> x0 in o.grid) <dynamic>[for (Role x1 in x0) x1.name],
    ]);
    w.key('own');
    w.value($OwnJsonDto.toMap(o.own));
    w.key('owns');
    w.value(<dynamic>[for (OwnJson x0 in o.owns) $OwnJsonDto.toMap(x0)]);
    w.key('product');
    w.value(o.product);
    w.key('products');
    w.value(o.products);
    w.key('by_name');
    w.value(o.byName);
    w.endObject();
  }

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

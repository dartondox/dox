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

  static const Map<String, String> _messages = <String, String>{};

  @override
  Type get type => OwnJson;

  @override
  String get name => 'OwnJson';

  @override
  bool get usesRequiredWhen => false;

  @override
  OwnJson? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // id: int
    Object? id = state.integer(state.read(input, 'id'), path, 'id', _messages);
    if (id == null || id is Undefined) state.required(path, 'id', _messages);
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (state.issues.length != issuesBefore) return null;
    return OwnJson(id: id as int);
  }

  @override
  OwnJson fromMap(Map<String, dynamic> map) {
    return OwnJson(id: (map['id'] as num).toInt());
  }

  @override
  Map<String, dynamic> toMap(OwnJson dto) {
    return <String, dynamic>{'id': dto.id};
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

  static const Map<String, String> _messages = <String, String>{};

  static final JsonRun _idKey = JsonRun('{"id":');
  static final JsonRun _productNameKey = JsonRun(',"product_name":');
  static final JsonRun _priceKey = JsonRun(',"price":');
  static final JsonRun _inStockKey = JsonRun(',"in_stock":');
  static final JsonRun _soldAtKey = JsonRun(',"sold_at":');
  static final JsonRun _end = JsonRun('}');

  @override
  Type get type => ProductView;

  @override
  String get name => 'ProductView';

  @override
  bool get usesRequiredWhen => false;

  @override
  ProductView? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // id: int
    Object? id = state.integer(state.read(input, 'id'), path, 'id', _messages);
    if (id == null || id is Undefined) state.required(path, 'id', _messages);
    // productName: String
    Object? productName = state.string(
      state.read(input, 'product_name'),
      path,
      'product_name',
      _messages,
    );
    if (productName == null || productName is Undefined)
      state.required(path, 'product_name', _messages);
    // price: double
    Object? price = state.decimal(
      state.read(input, 'price'),
      path,
      'price',
      _messages,
    );
    if (price == null || price is Undefined)
      state.required(path, 'price', _messages);
    // inStock: bool
    Object? inStock = state.boolean(
      state.read(input, 'in_stock'),
      path,
      'in_stock',
      _messages,
    );
    if (inStock == null || inStock is Undefined)
      state.required(path, 'in_stock', _messages);
    // soldAt: DateTime?
    Object? soldAt = state.date(
      state.read(input, 'sold_at'),
      path,
      'sold_at',
      _messages,
    );
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (state.issues.length != issuesBefore) return null;
    return ProductView(
      id: id as int,
      productName: productName as String,
      price: price as double,
      inStock: inStock as bool,
      soldAt: soldAt is Undefined ? null : soldAt as DateTime?,
    );
  }

  @override
  ProductView fromMap(Map<String, dynamic> map) {
    return ProductView(
      id: (map['id'] as num).toInt(),
      productName: map['product_name'] as String,
      price: (map['price'] as num).toDouble(),
      inStock: map['in_stock'] as bool,
      soldAt: map['sold_at'] == null
          ? null
          : (DateTime.parse(map['sold_at'] as String).toUtc()),
    );
  }

  @override
  Map<String, dynamic> toMap(ProductView dto) {
    DateTime? soldAt = dto.soldAt;
    return <String, dynamic>{
      'id': dto.id,
      'product_name': dto.productName,
      'price': dto.price,
      'in_stock': dto.inStock,
      'sold_at': soldAt == null ? null : soldAt.toIso8601String(),
    };
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      $writeProductView(object as ProductView, writer);

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
void $writeProductView(ProductView dto, JsonWriter writer) {
  writer.run(_$ProductViewDto._idKey);
  writer.integer(dto.id);
  writer.run(_$ProductViewDto._productNameKey);
  writer.string(dto.productName);
  writer.run(_$ProductViewDto._priceKey);
  writer.value(dto.price);
  writer.run(_$ProductViewDto._inStockKey);
  writer.boolean(dto.inStock);
  writer.run(_$ProductViewDto._soldAtKey);
  writer.dateTime(dto.soldAt);
  writer.run(_$ProductViewDto._end);
}

/// The checks, the converter and the JSON Schema of [MixedView].
const DtoSchema<MixedView> $MixedViewDto = _$MixedViewDto();

class _$MixedViewDto extends DtoSchema<MixedView> implements JsonObjectWriter {
  const _$MixedViewDto();

  static const Map<String, String> _messages = <String, String>{};

  static final JsonRun _datesKey = JsonRun('{"dates":[');
  static final JsonRun _rolesKey = JsonRun('],"roles":[');
  static final JsonRun _daysKey = JsonRun('],"days":');
  static final JsonRun _gridKey = JsonRun(',"grid":');
  static final JsonRun _ownKey = JsonRun(',"own":');
  static final JsonRun _ownsKey = JsonRun(',"owns":');
  static final JsonRun _productKey = JsonRun(',"product":');
  static final JsonRun _productsKey = JsonRun(',"products":[');
  static final JsonRun _byNameKey = JsonRun('],"by_name":');
  static final JsonRun _end = JsonRun('}');

  @override
  Type get type => MixedView;

  @override
  String get name => 'MixedView';

  @override
  bool get usesRequiredWhen => false;

  @override
  MixedView? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // dates: List<DateTime>
    Object? dates = state.list(
      state.read(input, 'dates'),
      path,
      'dates',
      _messages,
    );
    if (dates is List) {
      int b0 = state.issues.length;
      List<Object> q0 = <Object>[...path, 'dates'];
      List<DateTime> o0 = <DateTime>[];
      for (int i0 = 0; i0 < dates.length; i0++) {
        Object? x0 = state.date(dates[i0], q0, i0, _messages);
        if (x0 == null || x0 is Undefined) {
          state.required(q0, i0, _messages);
        } else if (x0 is! Invalid) {
          o0.add(x0 as DateTime);
        }
      }
      dates = state.issues.length != b0 ? invalid : o0;
    }
    if (dates == null || dates is Undefined || state.emptyList(dates)) {
      state.required(path, 'dates', _messages);
      dates = invalid;
    }
    // roles: List<Role>
    Object? roles = state.list(
      state.read(input, 'roles'),
      path,
      'roles',
      _messages,
    );
    if (roles is List) {
      int b0 = state.issues.length;
      List<Object> q0 = <Object>[...path, 'roles'];
      List<Role> o0 = <Role>[];
      for (int i0 = 0; i0 < roles.length; i0++) {
        Object? x0 = state.enumName(
          roles[i0],
          q0,
          i0,
          _messages,
          const <String>['admin', 'user'],
        );
        if (x0 is String) {
          x0 = switch (x0) {
            'admin' => Role.admin,
            _ => Role.user,
          };
        }
        if (x0 == null || x0 is Undefined) {
          state.required(q0, i0, _messages);
        } else if (x0 is! Invalid) {
          o0.add(x0 as Role);
        }
      }
      roles = state.issues.length != b0 ? invalid : o0;
    }
    if (roles == null || roles is Undefined || state.emptyList(roles)) {
      state.required(path, 'roles', _messages);
      roles = invalid;
    }
    // days: Map<String, DateTime>
    Object? days = state.object(
      state.read(input, 'days'),
      path,
      'days',
      _messages,
    );
    if (days is Map) {
      int b0 = state.issues.length;
      List<Object> q0 = <Object>[...path, 'days'];
      Map<String, DateTime> o0 = <String, DateTime>{};
      for (MapEntry<dynamic, dynamic> n0 in days.entries) {
        String k0 = '${n0.key}';
        Object? x0 = state.date(n0.value, q0, k0, _messages);
        if (x0 == null || x0 is Undefined) {
          state.required(q0, k0, _messages);
        } else if (x0 is! Invalid) {
          o0[k0] = x0 as DateTime;
        }
      }
      days = state.issues.length != b0 ? invalid : o0;
    }
    if (days == null || days is Undefined)
      state.required(path, 'days', _messages);
    // grid: List<List<Role>>
    Object? grid = state.list(
      state.read(input, 'grid'),
      path,
      'grid',
      _messages,
    );
    if (grid is List) {
      int b0 = state.issues.length;
      List<Object> q0 = <Object>[...path, 'grid'];
      List<List<Role>> o0 = <List<Role>>[];
      for (int i0 = 0; i0 < grid.length; i0++) {
        Object? x0 = state.list(grid[i0], q0, i0, _messages);
        if (x0 is List) {
          int b1 = state.issues.length;
          List<Object> q1 = <Object>[...q0, i0];
          List<Role> o1 = <Role>[];
          for (int i1 = 0; i1 < x0.length; i1++) {
            Object? x1 = state.enumName(
              x0[i1],
              q1,
              i1,
              _messages,
              const <String>['admin', 'user'],
            );
            if (x1 is String) {
              x1 = switch (x1) {
                'admin' => Role.admin,
                _ => Role.user,
              };
            }
            if (x1 == null || x1 is Undefined) {
              state.required(q1, i1, _messages);
            } else if (x1 is! Invalid) {
              o1.add(x1 as Role);
            }
          }
          x0 = state.issues.length != b1 ? invalid : o1;
        }
        if (x0 == null || x0 is Undefined) {
          state.required(q0, i0, _messages);
        } else if (x0 is! Invalid) {
          o0.add(x0 as List<Role>);
        }
      }
      grid = state.issues.length != b0 ? invalid : o0;
    }
    if (grid == null || grid is Undefined || state.emptyList(grid)) {
      state.required(path, 'grid', _messages);
      grid = invalid;
    }
    // own: OwnJson
    Object? own = state.object(
      state.read(input, 'own'),
      path,
      'own',
      _messages,
    );
    if (own is Map) {
      own =
          $OwnJsonDto.convert(own, state, <Object>[...path, 'own']) ?? invalid;
    }
    if (own == null || own is Undefined) state.required(path, 'own', _messages);
    // owns: List<OwnJson>
    Object? owns = state.list(
      state.read(input, 'owns'),
      path,
      'owns',
      _messages,
    );
    if (owns is List) {
      int b0 = state.issues.length;
      List<Object> q0 = <Object>[...path, 'owns'];
      List<OwnJson> o0 = <OwnJson>[];
      for (int i0 = 0; i0 < owns.length; i0++) {
        Object? x0 = state.object(owns[i0], q0, i0, _messages);
        if (x0 is Map) {
          x0 = $OwnJsonDto.convert(x0, state, <Object>[...q0, i0]) ?? invalid;
        }
        if (x0 == null || x0 is Undefined) {
          state.required(q0, i0, _messages);
        } else if (x0 is! Invalid) {
          o0.add(x0 as OwnJson);
        }
      }
      owns = state.issues.length != b0 ? invalid : o0;
    }
    if (owns == null || owns is Undefined || state.emptyList(owns)) {
      state.required(path, 'owns', _messages);
      owns = invalid;
    }
    // product: ProductView?
    Object? product = state.object(
      state.read(input, 'product'),
      path,
      'product',
      _messages,
    );
    if (product is Map) {
      product =
          $ProductViewDto.convert(product, state, <Object>[
            ...path,
            'product',
          ]) ??
          invalid;
    }
    // products: List<ProductView>
    Object? products = state.list(
      state.read(input, 'products'),
      path,
      'products',
      _messages,
    );
    if (products is List) {
      int b0 = state.issues.length;
      List<Object> q0 = <Object>[...path, 'products'];
      List<ProductView> o0 = <ProductView>[];
      for (int i0 = 0; i0 < products.length; i0++) {
        Object? x0 = state.object(products[i0], q0, i0, _messages);
        if (x0 is Map) {
          x0 =
              $ProductViewDto.convert(x0, state, <Object>[...q0, i0]) ??
              invalid;
        }
        if (x0 == null || x0 is Undefined) {
          state.required(q0, i0, _messages);
        } else if (x0 is! Invalid) {
          o0.add(x0 as ProductView);
        }
      }
      products = state.issues.length != b0 ? invalid : o0;
    }
    if (products == null ||
        products is Undefined ||
        state.emptyList(products)) {
      state.required(path, 'products', _messages);
      products = invalid;
    }
    // byName: Map<String, ProductView>
    Object? byName = state.object(
      state.read(input, 'by_name'),
      path,
      'by_name',
      _messages,
    );
    if (byName is Map) {
      int b0 = state.issues.length;
      List<Object> q0 = <Object>[...path, 'by_name'];
      Map<String, ProductView> o0 = <String, ProductView>{};
      for (MapEntry<dynamic, dynamic> n0 in byName.entries) {
        String k0 = '${n0.key}';
        Object? x0 = state.object(n0.value, q0, k0, _messages);
        if (x0 is Map) {
          x0 =
              $ProductViewDto.convert(x0, state, <Object>[...q0, k0]) ??
              invalid;
        }
        if (x0 == null || x0 is Undefined) {
          state.required(q0, k0, _messages);
        } else if (x0 is! Invalid) {
          o0[k0] = x0 as ProductView;
        }
      }
      byName = state.issues.length != b0 ? invalid : o0;
    }
    if (byName == null || byName is Undefined)
      state.required(path, 'by_name', _messages);
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (state.issues.length != issuesBefore) return null;
    return MixedView(
      dates: dates as List<DateTime>,
      roles: roles as List<Role>,
      days: days as Map<String, DateTime>,
      grid: grid as List<List<Role>>,
      own: own as OwnJson,
      owns: owns as List<OwnJson>,
      products: products as List<ProductView>,
      byName: byName as Map<String, ProductView>,
      product: product is Undefined ? null : product as ProductView?,
    );
  }

  @override
  MixedView fromMap(Map<String, dynamic> map) {
    return MixedView(
      dates: <DateTime>[
        for (Object? x0 in map['dates'] as List<dynamic>)
          DateTime.parse(x0 as String).toUtc(),
      ],
      roles: <Role>[
        for (Object? x0 in map['roles'] as List<dynamic>)
          Role.values.byName(x0 as String),
      ],
      days: <String, DateTime>{
        for (MapEntry<dynamic, dynamic> x0
            in (map['days'] as Map<dynamic, dynamic>).entries)
          x0.key as String: DateTime.parse(x0.value as String).toUtc(),
      },
      grid: <List<Role>>[
        for (Object? x0 in map['grid'] as List<dynamic>)
          <Role>[
            for (Object? x1 in x0 as List<dynamic>)
              Role.values.byName(x1 as String),
          ],
      ],
      own: $OwnJsonDto.fromMap(map['own'] as Map<String, dynamic>),
      owns: <OwnJson>[
        for (Object? x0 in map['owns'] as List<dynamic>)
          $OwnJsonDto.fromMap(x0 as Map<String, dynamic>),
      ],
      products: <ProductView>[
        for (Object? x0 in map['products'] as List<dynamic>)
          $ProductViewDto.fromMap(x0 as Map<String, dynamic>),
      ],
      byName: <String, ProductView>{
        for (MapEntry<dynamic, dynamic> x0
            in (map['by_name'] as Map<dynamic, dynamic>).entries)
          x0.key as String: $ProductViewDto.fromMap(
            x0.value as Map<String, dynamic>,
          ),
      },
      product: map['product'] == null
          ? null
          : ($ProductViewDto.fromMap(map['product'] as Map<String, dynamic>)),
    );
  }

  @override
  Map<String, dynamic> toMap(MixedView dto) {
    ProductView? product = dto.product;
    return <String, dynamic>{
      'dates': <dynamic>[for (DateTime x0 in dto.dates) x0.toIso8601String()],
      'roles': <dynamic>[for (Role x0 in dto.roles) x0.name],
      'days': <String, dynamic>{
        for (MapEntry<String, DateTime> x0 in dto.days.entries)
          x0.key: x0.value.toIso8601String(),
      },
      'grid': <dynamic>[
        for (List<Role> x0 in dto.grid) <dynamic>[for (Role x1 in x0) x1.name],
      ],
      'own': $OwnJsonDto.toMap(dto.own),
      'owns': <dynamic>[for (OwnJson x0 in dto.owns) $OwnJsonDto.toMap(x0)],
      'product': product == null ? null : $ProductViewDto.toMap(product),
      'products': <dynamic>[
        for (ProductView x0 in dto.products) $ProductViewDto.toMap(x0),
      ],
      'by_name': <String, dynamic>{
        for (MapEntry<String, ProductView> x0 in dto.byName.entries)
          x0.key: $ProductViewDto.toMap(x0.value),
      },
    };
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      $writeMixedView(object as MixedView, writer);

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

/// Writes the JSON of [MixedView], as `toMap()` gives it.
void $writeMixedView(MixedView dto, JsonWriter writer) {
  writer.run(_$MixedViewDto._datesKey);
  {
    List<DateTime> dates = dto.dates;
    for (int i = 0; i < dates.length; i++) {
      if (i > 0) writer.run(JsonRun.comma);
      writer.dateTime(dates[i]);
    }
  }
  writer.run(_$MixedViewDto._rolesKey);
  {
    List<Role> roles = dto.roles;
    for (int i = 0; i < roles.length; i++) {
      if (i > 0) writer.run(JsonRun.comma);
      writer.string(roles[i].name);
    }
  }
  writer.run(_$MixedViewDto._daysKey);
  writer.value(<String, dynamic>{
    for (MapEntry<String, DateTime> x0 in dto.days.entries)
      x0.key: x0.value.toIso8601String(),
  });
  writer.run(_$MixedViewDto._gridKey);
  writer.value(<dynamic>[
    for (List<Role> x0 in dto.grid) <dynamic>[for (Role x1 in x0) x1.name],
  ]);
  writer.run(_$MixedViewDto._ownKey);
  writer.value($OwnJsonDto.toMap(dto.own));
  writer.run(_$MixedViewDto._ownsKey);
  writer.value(<dynamic>[for (OwnJson x0 in dto.owns) $OwnJsonDto.toMap(x0)]);
  writer.run(_$MixedViewDto._productKey);
  writer.value(dto.product);
  writer.run(_$MixedViewDto._productsKey);
  {
    List<ProductView> products = dto.products;
    for (int i = 0; i < products.length; i++) {
      if (i > 0) writer.run(JsonRun.comma);
      $writeProductView(products[i], writer);
    }
  }
  writer.run(_$MixedViewDto._byNameKey);
  writer.value(dto.byName);
  writer.run(_$MixedViewDto._end);
}

/// The checks, the converter and the JSON Schema of [RunsView].
const DtoSchema<RunsView> $RunsViewDto = _$RunsViewDto();

class _$RunsViewDto extends DtoSchema<RunsView> implements JsonObjectWriter {
  const _$RunsViewDto();

  static const Map<String, String> _messages = <String, String>{};

  static final JsonRun _idKey = JsonRun('{"id":');
  static final JsonRun _tagsKey = JsonRun(',"tags":[');
  static final JsonRun _notesKey = JsonRun('],"notes":[');
  static final JsonRun _numbersKey = JsonRun('],"numbers":[');
  static final JsonRun _flagsKey = JsonRun('],"flags":[');
  static final JsonRun _mainKey = JsonRun('],"main":');
  static final JsonRun _productsKey = JsonRun(',"products":[');
  static final JsonRun _oddKey = JsonRun('],"a \\"key\\" é \\\\ \$x":');
  static final JsonRun _activeKey = JsonRun(',"active":');
  static final JsonRun _end = JsonRun('}');

  @override
  Type get type => RunsView;

  @override
  String get name => 'RunsView';

  @override
  bool get usesRequiredWhen => false;

  @override
  RunsView? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // id: int
    Object? id = state.integer(state.read(input, 'id'), path, 'id', _messages);
    if (id == null || id is Undefined) state.required(path, 'id', _messages);
    // tags: List<String>
    Object? tags = state.list(
      state.read(input, 'tags'),
      path,
      'tags',
      _messages,
    );
    if (tags is List) {
      int b0 = state.issues.length;
      List<Object> q0 = <Object>[...path, 'tags'];
      List<String> o0 = <String>[];
      for (int i0 = 0; i0 < tags.length; i0++) {
        Object? x0 = state.string(tags[i0], q0, i0, _messages);
        if (x0 == null || x0 is Undefined) {
          state.required(q0, i0, _messages);
        } else if (x0 is! Invalid) {
          o0.add(x0 as String);
        }
      }
      tags = state.issues.length != b0 ? invalid : o0;
    }
    if (tags == null || tags is Undefined || state.emptyList(tags)) {
      state.required(path, 'tags', _messages);
      tags = invalid;
    }
    // notes: List<String?>
    Object? notes = state.list(
      state.read(input, 'notes'),
      path,
      'notes',
      _messages,
    );
    if (notes is List) {
      int b0 = state.issues.length;
      List<Object> q0 = <Object>[...path, 'notes'];
      List<String?> o0 = <String?>[];
      for (int i0 = 0; i0 < notes.length; i0++) {
        Object? x0 = state.string(notes[i0], q0, i0, _messages);
        if (x0 == null || x0 is Undefined) {
          o0.add(null);
        } else if (x0 is! Invalid) {
          o0.add(x0 as String?);
        }
      }
      notes = state.issues.length != b0 ? invalid : o0;
    }
    if (notes == null || notes is Undefined || state.emptyList(notes)) {
      state.required(path, 'notes', _messages);
      notes = invalid;
    }
    // numbers: List<int>
    Object? numbers = state.list(
      state.read(input, 'numbers'),
      path,
      'numbers',
      _messages,
    );
    if (numbers is List) {
      int b0 = state.issues.length;
      List<Object> q0 = <Object>[...path, 'numbers'];
      List<int> o0 = <int>[];
      for (int i0 = 0; i0 < numbers.length; i0++) {
        Object? x0 = state.integer(numbers[i0], q0, i0, _messages);
        if (x0 == null || x0 is Undefined) {
          state.required(q0, i0, _messages);
        } else if (x0 is! Invalid) {
          o0.add(x0 as int);
        }
      }
      numbers = state.issues.length != b0 ? invalid : o0;
    }
    if (numbers == null || numbers is Undefined || state.emptyList(numbers)) {
      state.required(path, 'numbers', _messages);
      numbers = invalid;
    }
    // flags: List<bool>
    Object? flags = state.list(
      state.read(input, 'flags'),
      path,
      'flags',
      _messages,
    );
    if (flags is List) {
      int b0 = state.issues.length;
      List<Object> q0 = <Object>[...path, 'flags'];
      List<bool> o0 = <bool>[];
      for (int i0 = 0; i0 < flags.length; i0++) {
        Object? x0 = state.boolean(flags[i0], q0, i0, _messages);
        if (x0 == null || x0 is Undefined) {
          state.required(q0, i0, _messages);
        } else if (x0 is! Invalid) {
          o0.add(x0 as bool);
        }
      }
      flags = state.issues.length != b0 ? invalid : o0;
    }
    if (flags == null || flags is Undefined || state.emptyList(flags)) {
      state.required(path, 'flags', _messages);
      flags = invalid;
    }
    // main: ProductView
    Object? main = state.object(
      state.read(input, 'main'),
      path,
      'main',
      _messages,
    );
    if (main is Map) {
      main =
          $ProductViewDto.convert(main, state, <Object>[...path, 'main']) ??
          invalid;
    }
    if (main == null || main is Undefined)
      state.required(path, 'main', _messages);
    // products: List<ProductView>
    Object? products = state.list(
      state.read(input, 'products'),
      path,
      'products',
      _messages,
    );
    if (products is List) {
      int b0 = state.issues.length;
      List<Object> q0 = <Object>[...path, 'products'];
      List<ProductView> o0 = <ProductView>[];
      for (int i0 = 0; i0 < products.length; i0++) {
        Object? x0 = state.object(products[i0], q0, i0, _messages);
        if (x0 is Map) {
          x0 =
              $ProductViewDto.convert(x0, state, <Object>[...q0, i0]) ??
              invalid;
        }
        if (x0 == null || x0 is Undefined) {
          state.required(q0, i0, _messages);
        } else if (x0 is! Invalid) {
          o0.add(x0 as ProductView);
        }
      }
      products = state.issues.length != b0 ? invalid : o0;
    }
    if (products == null ||
        products is Undefined ||
        state.emptyList(products)) {
      state.required(path, 'products', _messages);
      products = invalid;
    }
    // odd: String
    Object? odd = state.string(
      state.read(input, 'a "key" é \\ \$x'),
      path,
      'a "key" é \\ \$x',
      _messages,
    );
    if (odd == null || odd is Undefined)
      state.required(path, 'a "key" é \\ \$x', _messages);
    // active: bool
    Object? active = state.boolean(
      state.read(input, 'active'),
      path,
      'active',
      _messages,
    );
    if (active == null || active is Undefined)
      state.required(path, 'active', _messages);
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (state.issues.length != issuesBefore) return null;
    return RunsView(
      id: id as int,
      tags: tags as List<String>,
      notes: notes as List<String?>,
      numbers: numbers as List<int>,
      flags: flags as List<bool>,
      main: main as ProductView,
      products: products as List<ProductView>,
      odd: odd as String,
      active: active as bool,
    );
  }

  @override
  RunsView fromMap(Map<String, dynamic> map) {
    return RunsView(
      id: (map['id'] as num).toInt(),
      tags: <String>[
        for (Object? x0 in map['tags'] as List<dynamic>) x0 as String,
      ],
      notes: <String?>[
        for (Object? x0 in map['notes'] as List<dynamic>)
          x0 == null ? null : (x0 as String),
      ],
      numbers: <int>[
        for (Object? x0 in map['numbers'] as List<dynamic>) (x0 as num).toInt(),
      ],
      flags: <bool>[
        for (Object? x0 in map['flags'] as List<dynamic>) x0 as bool,
      ],
      main: $ProductViewDto.fromMap(map['main'] as Map<String, dynamic>),
      products: <ProductView>[
        for (Object? x0 in map['products'] as List<dynamic>)
          $ProductViewDto.fromMap(x0 as Map<String, dynamic>),
      ],
      odd: map['a "key" é \\ \$x'] as String,
      active: map['active'] as bool,
    );
  }

  @override
  Map<String, dynamic> toMap(RunsView dto) {
    return <String, dynamic>{
      'id': dto.id,
      'tags': dto.tags,
      'notes': dto.notes,
      'numbers': dto.numbers,
      'flags': dto.flags,
      'main': $ProductViewDto.toMap(dto.main),
      'products': <dynamic>[
        for (ProductView x0 in dto.products) $ProductViewDto.toMap(x0),
      ],
      'a "key" é \\ \$x': dto.odd,
      'active': dto.active,
    };
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      $writeRunsView(object as RunsView, writer);

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
void $writeRunsView(RunsView dto, JsonWriter writer) {
  writer.run(_$RunsViewDto._idKey);
  writer.integer(dto.id);
  writer.run(_$RunsViewDto._tagsKey);
  {
    List<String> tags = dto.tags;
    for (int i = 0; i < tags.length; i++) {
      if (i > 0) writer.run(JsonRun.comma);
      writer.string(tags[i]);
    }
  }
  writer.run(_$RunsViewDto._notesKey);
  {
    List<String?> notes = dto.notes;
    for (int i = 0; i < notes.length; i++) {
      if (i > 0) writer.run(JsonRun.comma);
      writer.string(notes[i]);
    }
  }
  writer.run(_$RunsViewDto._numbersKey);
  {
    List<int> numbers = dto.numbers;
    for (int i = 0; i < numbers.length; i++) {
      if (i > 0) writer.run(JsonRun.comma);
      writer.integer(numbers[i]);
    }
  }
  writer.run(_$RunsViewDto._flagsKey);
  {
    List<bool> flags = dto.flags;
    for (int i = 0; i < flags.length; i++) {
      if (i > 0) writer.run(JsonRun.comma);
      writer.boolean(flags[i]);
    }
  }
  writer.run(_$RunsViewDto._mainKey);
  $writeProductView(dto.main, writer);
  writer.run(_$RunsViewDto._productsKey);
  {
    List<ProductView> products = dto.products;
    for (int i = 0; i < products.length; i++) {
      if (i > 0) writer.run(JsonRun.comma);
      $writeProductView(products[i], writer);
    }
  }
  writer.run(_$RunsViewDto._oddKey);
  writer.string(dto.odd);
  writer.run(_$RunsViewDto._activeKey);
  writer.boolean(dto.active);
  writer.run(_$RunsViewDto._end);
}

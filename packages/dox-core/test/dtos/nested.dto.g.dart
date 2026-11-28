// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nested.dto.dart';

// **************************************************************************
// DoxDtoGenerator
// **************************************************************************

// ignore_for_file: type=lint

/// The checks, the converter and the JSON Schema of [Address].
const DtoSchema<Address> $AddressDto = _$AddressDto();

class _$AddressDto extends DtoSchema<Address> implements JsonObjectWriter {
  const _$AddressDto();

  static const Map<String, String> _m = <String, String>{};

  static final JsonRun _j0 = JsonRun('{"city":');
  static final JsonRun _j1 = JsonRun(',"post_code":');
  static final JsonRun _j2 = JsonRun('}');

  @override
  Type get type => Address;

  @override
  String get name => 'Address';

  @override
  bool get hasChecks => true;

  @override
  bool get usesRequiredWhen => false;

  @override
  Address? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // city: String
    Object? c0;
    c0 = s.string(s.read(input, 'city'), p, 'city', _m);
    if (c0 == null || c0 is Undefined) s.required(p, 'city', _m);
    // postCode: String
    Object? c1;
    c1 = s.string(s.read(input, 'post_code'), p, 'post_code', _m);
    if (c1 == null || c1 is Undefined) s.required(p, 'post_code', _m);
    if (s.issues.length != e && !s.allErrors) return null;
    if (c1 is String) {
      if (!(c1.runes.length == 5)) {
        s.fail(
          p,
          'post_code',
          IssueCodes.length,
          DefaultMessages.length,
          c1,
          params: const <String, Object?>{'length': 5},
          messages: _m,
        );
      }
    }
    if (s.issues.length != e) return null;
    return Address(city: c0 as String, postCode: c1 as String);
  }

  @override
  void crossCheck(Address o, DtoState s, List<Object> p) {
    o.validate(DtoErrors(s, p));
  }

  @override
  Address fromMap(Map<String, dynamic> m) {
    return Address(
      city: m['city'] as String,
      postCode: m['post_code'] as String,
    );
  }

  @override
  Map<String, dynamic> toMap(Address o) {
    String f0 = o.city;
    String f1 = o.postCode;
    return <String, dynamic>{'city': f0, 'post_code': f1};
  }

  @override
  void writeObject(Object object, JsonWriter w) =>
      $writeAddress(object as Address, w);
  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'Address',
      'properties': <String, dynamic>{
        'city': <String, dynamic>{'type': 'string'},
        'post_code': <String, dynamic>{
          'type': 'string',
          'minLength': 5,
          'maxLength': 5,
        },
      },
      'required': <dynamic>['city', 'post_code'],
    };
  }
}

/// Writes the JSON of [Address], as `toMap()` gives it.
void $writeAddress(Address o, JsonWriter w) {
  w.run(_$AddressDto._j0);
  w.string(o.city);
  w.run(_$AddressDto._j1);
  w.string(o.postCode);
  w.run(_$AddressDto._j2);
}

/// The checks, the converter and the JSON Schema of [OrderItem].
const DtoSchema<OrderItem> $OrderItemDto = _$OrderItemDto();

class _$OrderItemDto extends DtoSchema<OrderItem> implements JsonObjectWriter {
  const _$OrderItemDto();

  static const Map<String, String> _m = <String, String>{};

  static final JsonRun _j0 = JsonRun('{"name":');
  static final JsonRun _j1 = JsonRun(',"quantity":');
  static final JsonRun _j2 = JsonRun('}');

  @override
  Type get type => OrderItem;

  @override
  String get name => 'OrderItem';

  @override
  bool get usesRequiredWhen => false;

  @override
  OrderItem? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // name: String
    Object? c0;
    c0 = s.string(s.read(input, 'name'), p, 'name', _m);
    if (c0 == null || c0 is Undefined) s.required(p, 'name', _m);
    // quantity: int
    Object? c1;
    c1 = s.integer(s.read(input, 'quantity'), p, 'quantity', _m);
    if (c1 == null || c1 is Undefined) s.required(p, 'quantity', _m);
    if (s.issues.length != e && !s.allErrors) return null;
    if (c1 is int) {
      if (!(c1 > 0)) {
        s.fail(
          p,
          'quantity',
          IssueCodes.greaterThan,
          DefaultMessages.greaterThan,
          c1,
          params: const <String, Object?>{'min': 0},
          messages: _m,
        );
      }
    }
    if (s.issues.length != e) return null;
    return OrderItem(name: c0 as String, quantity: c1 as int);
  }

  @override
  OrderItem fromMap(Map<String, dynamic> m) {
    return OrderItem(
      name: m['name'] as String,
      quantity: (m['quantity'] as num).toInt(),
    );
  }

  @override
  Map<String, dynamic> toMap(OrderItem o) {
    String f0 = o.name;
    int f1 = o.quantity;
    return <String, dynamic>{'name': f0, 'quantity': f1};
  }

  @override
  void writeObject(Object object, JsonWriter w) =>
      $writeOrderItem(object as OrderItem, w);
  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'OrderItem',
      'properties': <String, dynamic>{
        'name': <String, dynamic>{'type': 'string'},
        'quantity': <String, dynamic>{'type': 'integer', 'exclusiveMinimum': 0},
      },
      'required': <dynamic>['name', 'quantity'],
    };
  }
}

/// Writes the JSON of [OrderItem], as `toMap()` gives it.
void $writeOrderItem(OrderItem o, JsonWriter w) {
  w.run(_$OrderItemDto._j0);
  w.string(o.name);
  w.run(_$OrderItemDto._j1);
  w.integer(o.quantity);
  w.run(_$OrderItemDto._j2);
}

/// The checks, the converter and the JSON Schema of [CreateOrder].
const DtoSchema<CreateOrder> $CreateOrderDto = _$CreateOrderDto();

class _$CreateOrderDto extends DtoSchema<CreateOrder>
    implements JsonObjectWriter {
  const _$CreateOrderDto();

  static const Map<String, String> _m = <String, String>{};

  static final JsonRun _j0 = JsonRun('{"address":');
  static final JsonRun _j1 = JsonRun(',"items":[');
  static final JsonRun _j2 = JsonRun('],"billing":');
  static final JsonRun _j3 = JsonRun('}');

  @override
  Type get type => CreateOrder;

  @override
  String get name => 'CreateOrder';

  @override
  bool get hasChecks => true;

  @override
  bool get usesRequiredWhen => false;

  @override
  CreateOrder? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // address: Address
    Object? c0;
    c0 = s.object(s.read(input, 'address'), p, 'address', _m);
    if (c0 is Map) {
      c0 = $AddressDto.convert(c0, s, <Object>[...p, 'address']) ?? invalid;
    }
    if (c0 == null || c0 is Undefined) s.required(p, 'address', _m);
    // items: List<OrderItem>
    Object? c1;
    c1 = s.list(s.read(input, 'items'), p, 'items', _m);
    if (c1 is List) {
      int b0 = s.issues.length;
      List<Object> q0 = <Object>[...p, 'items'];
      List<OrderItem> o0 = <OrderItem>[];
      for (int i0 = 0; i0 < c1.length; i0++) {
        Object? x0;
        x0 = s.object(c1[i0], q0, i0, _m);
        if (x0 is Map) {
          x0 = $OrderItemDto.convert(x0, s, <Object>[...q0, i0]) ?? invalid;
        }
        if (x0 == null || x0 is Undefined) {
          s.required(q0, i0, _m);
        } else if (x0 is! Invalid) {
          o0.add(x0 as OrderItem);
        }
      }
      c1 = s.issues.length != b0 ? invalid : o0;
    }
    if (c1 == null || c1 is Undefined || s.emptyList(c1)) {
      s.required(p, 'items', _m);
      c1 = invalid;
    }
    // billing: Address?
    Object? c2;
    c2 = s.object(s.read(input, 'billing'), p, 'billing', _m);
    if (c2 is Map) {
      c2 = $AddressDto.convert(c2, s, <Object>[...p, 'billing']) ?? invalid;
    }
    if (s.issues.length != e && !s.allErrors) return null;
    if (c1 is List<OrderItem>) {
      if (!(c1.length >= 1)) {
        s.fail(
          p,
          'items',
          IssueCodes.minItems,
          DefaultMessages.minItems,
          c1,
          params: const <String, Object?>{'min': 1},
          messages: _m,
        );
      }
    }
    if (s.issues.length != e) return null;
    return CreateOrder(
      address: c0 as Address,
      items: c1 as List<OrderItem>,
      billing: c2 is Undefined ? null : c2 as Address?,
    );
  }

  @override
  void crossCheck(CreateOrder o, DtoState s, List<Object> p) {
    {
      Address f = o.address;
      $AddressDto.crossCheck(f, s, <Object>[...p, 'address']);
    }
    {
      Address? f = o.billing;
      if (f != null) {
        $AddressDto.crossCheck(f, s, <Object>[...p, 'billing']);
      }
    }
  }

  @override
  CreateOrder fromMap(Map<String, dynamic> m) {
    return CreateOrder(
      address: $AddressDto.fromMap(m['address'] as Map<String, dynamic>),
      items: <OrderItem>[
        for (Object? x0 in m['items'] as List<dynamic>)
          $OrderItemDto.fromMap(x0 as Map<String, dynamic>),
      ],
      billing: m['billing'] == null
          ? null
          : ($AddressDto.fromMap(m['billing'] as Map<String, dynamic>)),
    );
  }

  @override
  Map<String, dynamic> toMap(CreateOrder o) {
    Address f0 = o.address;
    List<OrderItem> f1 = o.items;
    Address? f2 = o.billing;
    return <String, dynamic>{
      'address': $AddressDto.toMap(f0),
      'items': <dynamic>[for (OrderItem x0 in f1) $OrderItemDto.toMap(x0)],
      'billing': f2 == null ? null : $AddressDto.toMap(f2),
    };
  }

  @override
  void writeObject(Object object, JsonWriter w) =>
      $writeCreateOrder(object as CreateOrder, w);
  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'CreateOrder',
      'properties': <String, dynamic>{
        'address': <String, dynamic>{'\$ref': '#/\$defs/Address'},
        'items': <String, dynamic>{
          'type': 'array',
          'items': <String, dynamic>{'\$ref': '#/\$defs/OrderItem'},
          'minItems': 1,
        },
        'billing': <String, dynamic>{
          'anyOf': <dynamic>[
            <String, dynamic>{'\$ref': '#/\$defs/Address'},
            <String, dynamic>{'type': 'null'},
          ],
        },
      },
      'required': <dynamic>['address', 'items'],
      '\$defs': <String, dynamic>{
        'Address': <String, dynamic>{
          'type': 'object',
          'title': 'Address',
          'properties': <String, dynamic>{
            'city': <String, dynamic>{'type': 'string'},
            'post_code': <String, dynamic>{
              'type': 'string',
              'minLength': 5,
              'maxLength': 5,
            },
          },
          'required': <dynamic>['city', 'post_code'],
        },
        'OrderItem': <String, dynamic>{
          'type': 'object',
          'title': 'OrderItem',
          'properties': <String, dynamic>{
            'name': <String, dynamic>{'type': 'string'},
            'quantity': <String, dynamic>{
              'type': 'integer',
              'exclusiveMinimum': 0,
            },
          },
          'required': <dynamic>['name', 'quantity'],
        },
      },
    };
  }
}

/// Writes the JSON of [CreateOrder], as `toMap()` gives it.
void $writeCreateOrder(CreateOrder o, JsonWriter w) {
  w.run(_$CreateOrderDto._j0);
  $writeAddress(o.address, w);
  w.run(_$CreateOrderDto._j1);
  {
    List<OrderItem> l1 = o.items;
    for (int i = 0; i < l1.length; i++) {
      if (i > 0) w.run(JsonRun.comma);
      $writeOrderItem(l1[i], w);
    }
  }
  w.run(_$CreateOrderDto._j2);
  if (o.billing case final v?) {
    $writeAddress(v, w);
  } else {
    w.value(null);
  }
  w.run(_$CreateOrderDto._j3);
}

/// The checks, the converter and the JSON Schema of [SignUp].
const DtoSchema<SignUp> $SignUpDto = _$SignUpDto();

class _$SignUpDto extends DtoSchema<SignUp> implements JsonObjectWriter {
  const _$SignUpDto();

  static const Map<String, String> _m = <String, String>{};

  static final JsonRun _j0 = JsonRun('{"password":');
  static final JsonRun _j1 = JsonRun(',"password_confirmation":');
  static final JsonRun _j2 = JsonRun(',"starts_at":');
  static final JsonRun _j3 = JsonRun(',"ends_at":');
  static final JsonRun _j4 = JsonRun('}');

  @override
  Type get type => SignUp;

  @override
  String get name => 'SignUp';

  @override
  bool get hasChecks => true;

  @override
  bool get usesRequiredWhen => false;

  @override
  SignUp? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // password: String
    Object? c0;
    c0 = s.string(s.read(input, 'password'), p, 'password', _m);
    if (c0 == null || c0 is Undefined) s.required(p, 'password', _m);
    // passwordConfirmation: String
    Object? c1;
    c1 = s.string(
      s.read(input, 'password_confirmation'),
      p,
      'password_confirmation',
      _m,
    );
    if (c1 == null || c1 is Undefined)
      s.required(p, 'password_confirmation', _m);
    // startsAt: DateTime?
    Object? c2;
    c2 = s.date(s.read(input, 'starts_at'), p, 'starts_at', _m);
    // endsAt: DateTime?
    Object? c3;
    c3 = s.date(s.read(input, 'ends_at'), p, 'ends_at', _m);
    if (s.issues.length != e && !s.allErrors) return null;
    if (c0 is String) {
      if (!(c0.runes.length >= 8)) {
        s.fail(
          p,
          'password',
          IssueCodes.minLength,
          DefaultMessages.minLength,
          c0,
          params: const <String, Object?>{'min': 8},
          messages: _m,
        );
      }
    }
    if (s.issues.length != e) return null;
    return SignUp(
      password: c0 as String,
      passwordConfirmation: c1 as String,
      startsAt: c2 is Undefined ? null : c2 as DateTime?,
      endsAt: c3 is Undefined ? null : c3 as DateTime?,
    );
  }

  @override
  void crossCheck(SignUp o, DtoState s, List<Object> p) {
    o.validate(DtoErrors(s, p));
  }

  @override
  SignUp fromMap(Map<String, dynamic> m) {
    return SignUp(
      password: m['password'] as String,
      passwordConfirmation: m['password_confirmation'] as String,
      startsAt: m['starts_at'] == null
          ? null
          : (DateTime.parse(m['starts_at'] as String).toUtc()),
      endsAt: m['ends_at'] == null
          ? null
          : (DateTime.parse(m['ends_at'] as String).toUtc()),
    );
  }

  @override
  Map<String, dynamic> toMap(SignUp o) {
    String f0 = o.password;
    String f1 = o.passwordConfirmation;
    DateTime? f2 = o.startsAt;
    DateTime? f3 = o.endsAt;
    return <String, dynamic>{
      'password': f0,
      'password_confirmation': f1,
      'starts_at': f2 == null ? null : f2.toIso8601String(),
      'ends_at': f3 == null ? null : f3.toIso8601String(),
    };
  }

  @override
  void writeObject(Object object, JsonWriter w) =>
      $writeSignUp(object as SignUp, w);
  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'SignUp',
      'properties': <String, dynamic>{
        'password': <String, dynamic>{'type': 'string', 'minLength': 8},
        'password_confirmation': <String, dynamic>{'type': 'string'},
        'starts_at': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'format': 'date-time',
        },
        'ends_at': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'format': 'date-time',
        },
      },
      'required': <dynamic>['password', 'password_confirmation'],
    };
  }
}

/// Writes the JSON of [SignUp], as `toMap()` gives it.
void $writeSignUp(SignUp o, JsonWriter w) {
  w.run(_$SignUpDto._j0);
  w.string(o.password);
  w.run(_$SignUpDto._j1);
  w.string(o.passwordConfirmation);
  w.run(_$SignUpDto._j2);
  w.dateTime(o.startsAt);
  w.run(_$SignUpDto._j3);
  w.dateTime(o.endsAt);
  w.run(_$SignUpDto._j4);
}

/// The checks, the converter and the JSON Schema of [AsyncCheck].
const DtoSchema<AsyncCheck> $AsyncCheckDto = _$AsyncCheckDto();

class _$AsyncCheckDto extends DtoSchema<AsyncCheck>
    implements JsonObjectWriter {
  const _$AsyncCheckDto();

  static const Map<String, String> _m = <String, String>{};

  static final JsonRun _j0 = JsonRun('{"code":');
  static final JsonRun _j1 = JsonRun('}');

  @override
  Type get type => AsyncCheck;

  @override
  String get name => 'AsyncCheck';

  @override
  bool get hasChecks => true;

  @override
  bool get usesRequiredWhen => false;

  @override
  bool get isAsync => true;

  @override
  AsyncCheck? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // code: String
    Object? c0;
    c0 = s.string(s.read(input, 'code'), p, 'code', _m);
    if (c0 == null || c0 is Undefined) s.required(p, 'code', _m);
    if (s.issues.length != e && !s.allErrors) return null;
    if (s.issues.length != e) return null;
    return AsyncCheck(code: c0 as String);
  }

  @override
  Future<void> crossCheck(AsyncCheck o, DtoState s, List<Object> p) async {
    await o.validate(DtoErrors(s, p));
  }

  @override
  AsyncCheck fromMap(Map<String, dynamic> m) {
    return AsyncCheck(code: m['code'] as String);
  }

  @override
  Map<String, dynamic> toMap(AsyncCheck o) {
    String f0 = o.code;
    return <String, dynamic>{'code': f0};
  }

  @override
  void writeObject(Object object, JsonWriter w) =>
      $writeAsyncCheck(object as AsyncCheck, w);
  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'AsyncCheck',
      'properties': <String, dynamic>{
        'code': <String, dynamic>{'type': 'string'},
      },
      'required': <dynamic>['code'],
    };
  }
}

/// Writes the JSON of [AsyncCheck], as `toMap()` gives it.
void $writeAsyncCheck(AsyncCheck o, JsonWriter w) {
  w.run(_$AsyncCheckDto._j0);
  w.string(o.code);
  w.run(_$AsyncCheckDto._j1);
}

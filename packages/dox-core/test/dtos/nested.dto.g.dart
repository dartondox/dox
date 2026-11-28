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

  static const Map<String, String> _messages = <String, String>{};

  @override
  Type get type => Address;

  @override
  String get name => 'Address';

  @override
  bool get hasChecks => true;

  @override
  bool get usesRequiredWhen => false;

  @override
  Address? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // city: String
    Object? city = state.string(
      state.read(input, 'city'),
      path,
      'city',
      _messages,
    );
    if (city == null || city is Undefined)
      state.required(path, 'city', _messages);
    // postCode: String
    Object? postCode = state.string(
      state.read(input, 'post_code'),
      path,
      'post_code',
      _messages,
    );
    if (postCode == null || postCode is Undefined)
      state.required(path, 'post_code', _messages);
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (postCode is String) {
      if (!(postCode.runes.length == 5)) {
        state.fail(
          path,
          'post_code',
          IssueCodes.length,
          DefaultMessages.length,
          postCode,
          params: const <String, Object?>{'length': 5},
          messages: _messages,
        );
      }
    }
    if (state.issues.length != issuesBefore) return null;
    return Address(city: city as String, postCode: postCode as String);
  }

  @override
  void crossCheck(Address dto, DtoState state, List<Object> path) {
    dto.validate(DtoErrors(state, path));
  }

  @override
  Address fromMap(Map<String, dynamic> map) {
    return Address(
      city: map['city'] as String,
      postCode: map['post_code'] as String,
    );
  }

  @override
  Map<String, dynamic> toMap(Address dto) {
    return <String, dynamic>{'city': dto.city, 'post_code': dto.postCode};
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      writer.value(toMap(object as Address));

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

/// The checks, the converter and the JSON Schema of [OrderItem].
const DtoSchema<OrderItem> $OrderItemDto = _$OrderItemDto();

class _$OrderItemDto extends DtoSchema<OrderItem> implements JsonObjectWriter {
  const _$OrderItemDto();

  static const Map<String, String> _messages = <String, String>{};

  @override
  Type get type => OrderItem;

  @override
  String get name => 'OrderItem';

  @override
  bool get usesRequiredWhen => false;

  @override
  OrderItem? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // name: String
    Object? name = state.string(
      state.read(input, 'name'),
      path,
      'name',
      _messages,
    );
    if (name == null || name is Undefined)
      state.required(path, 'name', _messages);
    // quantity: int
    Object? quantity = state.integer(
      state.read(input, 'quantity'),
      path,
      'quantity',
      _messages,
    );
    if (quantity == null || quantity is Undefined)
      state.required(path, 'quantity', _messages);
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (quantity is int) {
      if (!(quantity > 0)) {
        state.fail(
          path,
          'quantity',
          IssueCodes.greaterThan,
          DefaultMessages.greaterThan,
          quantity,
          params: const <String, Object?>{'min': 0},
          messages: _messages,
        );
      }
    }
    if (state.issues.length != issuesBefore) return null;
    return OrderItem(name: name as String, quantity: quantity as int);
  }

  @override
  OrderItem fromMap(Map<String, dynamic> map) {
    return OrderItem(
      name: map['name'] as String,
      quantity: (map['quantity'] as num).toInt(),
    );
  }

  @override
  Map<String, dynamic> toMap(OrderItem dto) {
    return <String, dynamic>{'name': dto.name, 'quantity': dto.quantity};
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      writer.value(toMap(object as OrderItem));

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

/// The checks, the converter and the JSON Schema of [CreateOrder].
const DtoSchema<CreateOrder> $CreateOrderDto = _$CreateOrderDto();

class _$CreateOrderDto extends DtoSchema<CreateOrder>
    implements JsonObjectWriter {
  const _$CreateOrderDto();

  static const Map<String, String> _messages = <String, String>{};

  @override
  Type get type => CreateOrder;

  @override
  String get name => 'CreateOrder';

  @override
  bool get hasChecks => true;

  @override
  bool get usesRequiredWhen => false;

  @override
  CreateOrder? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // address: Address
    Object? address = state.object(
      state.read(input, 'address'),
      path,
      'address',
      _messages,
    );
    if (address is Map) {
      address =
          $AddressDto.convert(address, state, <Object>[...path, 'address']) ??
          invalid;
    }
    if (address == null || address is Undefined)
      state.required(path, 'address', _messages);
    // items: List<OrderItem>
    Object? items = state.list(
      state.read(input, 'items'),
      path,
      'items',
      _messages,
    );
    if (items is List) {
      int b0 = state.issues.length;
      List<Object> q0 = <Object>[...path, 'items'];
      List<OrderItem> o0 = <OrderItem>[];
      for (int i0 = 0; i0 < items.length; i0++) {
        Object? x0 = state.object(items[i0], q0, i0, _messages);
        if (x0 is Map) {
          x0 = $OrderItemDto.convert(x0, state, <Object>[...q0, i0]) ?? invalid;
        }
        if (x0 == null || x0 is Undefined) {
          state.required(q0, i0, _messages);
        } else if (x0 is! Invalid) {
          o0.add(x0 as OrderItem);
        }
      }
      items = state.issues.length != b0 ? invalid : o0;
    }
    if (items == null || items is Undefined || state.emptyList(items)) {
      state.required(path, 'items', _messages);
      items = invalid;
    }
    // billing: Address?
    Object? billing = state.object(
      state.read(input, 'billing'),
      path,
      'billing',
      _messages,
    );
    if (billing is Map) {
      billing =
          $AddressDto.convert(billing, state, <Object>[...path, 'billing']) ??
          invalid;
    }
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (items is List<OrderItem>) {
      if (!(items.length >= 1)) {
        state.fail(
          path,
          'items',
          IssueCodes.minItems,
          DefaultMessages.minItems,
          items,
          params: const <String, Object?>{'min': 1},
          messages: _messages,
        );
      }
    }
    if (state.issues.length != issuesBefore) return null;
    return CreateOrder(
      address: address as Address,
      items: items as List<OrderItem>,
      billing: billing is Undefined ? null : billing as Address?,
    );
  }

  @override
  void crossCheck(CreateOrder dto, DtoState state, List<Object> path) {
    {
      Address value = dto.address;
      $AddressDto.crossCheck(value, state, <Object>[...path, 'address']);
    }
    {
      Address? value = dto.billing;
      if (value != null) {
        $AddressDto.crossCheck(value, state, <Object>[...path, 'billing']);
      }
    }
  }

  @override
  CreateOrder fromMap(Map<String, dynamic> map) {
    return CreateOrder(
      address: $AddressDto.fromMap(map['address'] as Map<String, dynamic>),
      items: <OrderItem>[
        for (Object? x0 in map['items'] as List<dynamic>)
          $OrderItemDto.fromMap(x0 as Map<String, dynamic>),
      ],
      billing: map['billing'] == null
          ? null
          : ($AddressDto.fromMap(map['billing'] as Map<String, dynamic>)),
    );
  }

  @override
  Map<String, dynamic> toMap(CreateOrder dto) {
    Address? billing = dto.billing;
    return <String, dynamic>{
      'address': $AddressDto.toMap(dto.address),
      'items': <dynamic>[
        for (OrderItem x0 in dto.items) $OrderItemDto.toMap(x0),
      ],
      'billing': billing == null ? null : $AddressDto.toMap(billing),
    };
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      writer.value(toMap(object as CreateOrder));

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

/// The checks, the converter and the JSON Schema of [SignUp].
const DtoSchema<SignUp> $SignUpDto = _$SignUpDto();

class _$SignUpDto extends DtoSchema<SignUp> implements JsonObjectWriter {
  const _$SignUpDto();

  static const Map<String, String> _messages = <String, String>{};

  @override
  Type get type => SignUp;

  @override
  String get name => 'SignUp';

  @override
  bool get hasChecks => true;

  @override
  bool get usesRequiredWhen => false;

  @override
  SignUp? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // password: String
    Object? password = state.string(
      state.read(input, 'password'),
      path,
      'password',
      _messages,
    );
    if (password == null || password is Undefined)
      state.required(path, 'password', _messages);
    // passwordConfirmation: String
    Object? passwordConfirmation = state.string(
      state.read(input, 'password_confirmation'),
      path,
      'password_confirmation',
      _messages,
    );
    if (passwordConfirmation == null || passwordConfirmation is Undefined)
      state.required(path, 'password_confirmation', _messages);
    // startsAt: DateTime?
    Object? startsAt = state.date(
      state.read(input, 'starts_at'),
      path,
      'starts_at',
      _messages,
    );
    // endsAt: DateTime?
    Object? endsAt = state.date(
      state.read(input, 'ends_at'),
      path,
      'ends_at',
      _messages,
    );
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (password is String) {
      if (!(password.runes.length >= 8)) {
        state.fail(
          path,
          'password',
          IssueCodes.minLength,
          DefaultMessages.minLength,
          password,
          params: const <String, Object?>{'min': 8},
          messages: _messages,
        );
      }
    }
    if (state.issues.length != issuesBefore) return null;
    return SignUp(
      password: password as String,
      passwordConfirmation: passwordConfirmation as String,
      startsAt: startsAt is Undefined ? null : startsAt as DateTime?,
      endsAt: endsAt is Undefined ? null : endsAt as DateTime?,
    );
  }

  @override
  void crossCheck(SignUp dto, DtoState state, List<Object> path) {
    dto.validate(DtoErrors(state, path));
  }

  @override
  SignUp fromMap(Map<String, dynamic> map) {
    return SignUp(
      password: map['password'] as String,
      passwordConfirmation: map['password_confirmation'] as String,
      startsAt: map['starts_at'] == null
          ? null
          : (DateTime.parse(map['starts_at'] as String).toUtc()),
      endsAt: map['ends_at'] == null
          ? null
          : (DateTime.parse(map['ends_at'] as String).toUtc()),
    );
  }

  @override
  Map<String, dynamic> toMap(SignUp dto) {
    DateTime? startsAt = dto.startsAt;
    DateTime? endsAt = dto.endsAt;
    return <String, dynamic>{
      'password': dto.password,
      'password_confirmation': dto.passwordConfirmation,
      'starts_at': startsAt == null ? null : startsAt.toIso8601String(),
      'ends_at': endsAt == null ? null : endsAt.toIso8601String(),
    };
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      writer.value(toMap(object as SignUp));

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

/// The checks, the converter and the JSON Schema of [AsyncCheck].
const DtoSchema<AsyncCheck> $AsyncCheckDto = _$AsyncCheckDto();

class _$AsyncCheckDto extends DtoSchema<AsyncCheck>
    implements JsonObjectWriter {
  const _$AsyncCheckDto();

  static const Map<String, String> _messages = <String, String>{};

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
  AsyncCheck? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // code: String
    Object? code = state.string(
      state.read(input, 'code'),
      path,
      'code',
      _messages,
    );
    if (code == null || code is Undefined)
      state.required(path, 'code', _messages);
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (state.issues.length != issuesBefore) return null;
    return AsyncCheck(code: code as String);
  }

  @override
  Future<void> crossCheck(
    AsyncCheck dto,
    DtoState state,
    List<Object> path,
  ) async {
    await dto.validate(DtoErrors(state, path));
  }

  @override
  AsyncCheck fromMap(Map<String, dynamic> map) {
    return AsyncCheck(code: map['code'] as String);
  }

  @override
  Map<String, dynamic> toMap(AsyncCheck dto) {
    return <String, dynamic>{'code': dto.code};
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      writer.value(toMap(object as AsyncCheck));

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

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth.dto.dart';

// **************************************************************************
// DoxDtoGenerator
// **************************************************************************

// ignore_for_file: type=lint

/// The checks, the converter and the JSON Schema of [RegisterUser].
const DtoSchema<RegisterUser> $RegisterUserDto = _$RegisterUserDto();

class _$RegisterUserDto extends DtoSchema<RegisterUser> {
  const _$RegisterUserDto();

  static const Map<String, String> _m = <String, String>{};

  @override
  Type get type => RegisterUser;

  @override
  String get name => 'RegisterUser';

  @override
  bool get isAsync => true;

  @override
  RegisterUser? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // name: String
    Object? c0;
    c0 = s.string(s.read(input, 'name'), p, 'name', _m, trim: true);
    if (c0 == null || c0 is Undefined) s.required(p, 'name', _m);
    // email: String
    Object? c1;
    c1 = s.string(
      s.read(input, 'email'),
      p,
      'email',
      _m,
      trim: true,
      textCase: 1,
    );
    if (c1 == null || c1 is Undefined) s.required(p, 'email', _m);
    // password: String
    Object? c2;
    c2 = s.string(s.read(input, 'password'), p, 'password', _m);
    if (c2 == null || c2 is Undefined) s.required(p, 'password', _m);
    if (s.issues.length != e) return null;
    if (c0 is String) {
      if (!(c0.runes.length >= 2 && c0.runes.length <= 100)) {
        s.fail(
          p,
          'name',
          IssueCodes.lengthBetween,
          DefaultMessages.lengthBetween,
          c0,
          params: const <String, Object?>{'min': 2, 'max': 100},
          messages: _m,
        );
      }
    }
    if (c1 is String) {
      if (!(Patterns.email.hasMatch(c1))) {
        s.fail(
          p,
          'email',
          IssueCodes.email,
          DefaultMessages.email,
          c1,
          messages: _m,
        );
      }
    }
    if (c2 is String) {
      if (!(c2.runes.length >= 8)) {
        s.fail(
          p,
          'password',
          IssueCodes.minLength,
          DefaultMessages.minLength,
          c2,
          params: const <String, Object?>{'min': 8},
          messages: _m,
        );
      }
    }
    if (s.issues.length != e) return null;
    return RegisterUser(
      name: c0 as String,
      email: c1 as String,
      password: c2 as String,
    );
  }

  @override
  Future<void> checkAsync(RegisterUser o, DtoState s, List<Object> p) async {
    {
      String f = o.email;
      await s.asyncRule(
        const Unique('users', column: 'email'),
        f,
        p,
        'email',
        _m,
      );
    }
  }

  @override
  RegisterUser fromMap(Map<String, dynamic> m) {
    return RegisterUser(
      name: m['name'] as String,
      email: m['email'] as String,
      password: m['password'] as String,
    );
  }

  @override
  Map<String, dynamic> toMap(RegisterUser o) {
    String f0 = o.name;
    String f1 = o.email;
    String f2 = o.password;
    return <String, dynamic>{'name': f0, 'email': f1, 'password': f2};
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    Map<String, dynamic> j = <String, dynamic>{
      'type': 'object',
      'title': 'RegisterUser',
      'properties': <String, dynamic>{
        'name': <String, dynamic>{
          'type': 'string',
          'minLength': 2,
          'maxLength': 100,
        },
        'email': <String, dynamic>{'type': 'string', 'format': 'email'},
        'password': <String, dynamic>{'type': 'string', 'minLength': 8},
      },
      'required': <dynamic>['name', 'email', 'password'],
    };
    JsonSchemaTools.merge(j, <String>[
      'properties',
      'email',
    ], const Unique('users', column: 'email').toJsonSchema());
    return j;
  }
}

/// The checks, the converter and the JSON Schema of [LoginUser].
const DtoSchema<LoginUser> $LoginUserDto = _$LoginUserDto();

class _$LoginUserDto extends DtoSchema<LoginUser> {
  const _$LoginUserDto();

  static const Map<String, String> _m = <String, String>{};

  @override
  Type get type => LoginUser;

  @override
  String get name => 'LoginUser';

  @override
  LoginUser? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // email: String
    Object? c0;
    c0 = s.string(s.read(input, 'email'), p, 'email', _m);
    if (c0 == null || c0 is Undefined) s.required(p, 'email', _m);
    // password: String
    Object? c1;
    c1 = s.string(s.read(input, 'password'), p, 'password', _m);
    if (c1 == null || c1 is Undefined) s.required(p, 'password', _m);
    if (s.issues.length != e) return null;
    if (c0 is String) {
      if (!(Patterns.email.hasMatch(c0))) {
        s.fail(
          p,
          'email',
          IssueCodes.email,
          DefaultMessages.email,
          c0,
          messages: _m,
        );
      }
    }
    if (s.issues.length != e) return null;
    return LoginUser(email: c0 as String, password: c1 as String);
  }

  @override
  LoginUser fromMap(Map<String, dynamic> m) {
    return LoginUser(
      email: m['email'] as String,
      password: m['password'] as String,
    );
  }

  @override
  Map<String, dynamic> toMap(LoginUser o) {
    String f0 = o.email;
    String f1 = o.password;
    return <String, dynamic>{'email': f0, 'password': f1};
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'LoginUser',
      'properties': <String, dynamic>{
        'email': <String, dynamic>{'type': 'string', 'format': 'email'},
        'password': <String, dynamic>{'type': 'string'},
      },
      'required': <dynamic>['email', 'password'],
    };
  }
}

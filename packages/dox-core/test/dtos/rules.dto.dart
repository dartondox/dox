import 'package:dox_core/dox_core.dart';

part 'rules.dto.g.dart';

enum Role { admin, user }

@Dto()
class CreateUser {
  @Length(min: 3, max: 50)
  @Trim()
  final String name;

  @Email()
  final String email;

  @Min(18)
  final int? age;

  final Role role;

  @MaxItems(5)
  final List<String> tags;

  const CreateUser({
    required this.name,
    required this.email,
    this.age,
    this.role = Role.user,
    this.tags = const <String>[],
  });

  static const DtoSchema<CreateUser> schema = $CreateUserDto;
}

@Dto()
class TextRules {
  @Length(min: 2, max: 4)
  final String? len;

  @Length(min: 3, max: 3)
  final String? exact;

  @Length(min: 2)
  final String? lenMin;

  @MinLength(2)
  final String? minLen;

  @MaxLength(3)
  final String? maxLen;

  @Email()
  final String? email;

  @Url()
  final String? url;

  @Uuid()
  final String? uuid;

  @Ip()
  final String? ip;

  @Regex('[a-z]+')
  final String? regex;

  @In(<String>['a', 'b'])
  final String? inList;

  @NotIn(<String>['root'])
  final String? notIn;

  @StartsWith('dox')
  final String? starts;

  @EndsWith('.dev')
  final String? ends;

  @Alpha()
  final String? alpha;

  @AlphaNumeric()
  final String? alnum;

  @AlphaDash()
  final String? dash;

  const TextRules({
    this.len,
    this.exact,
    this.lenMin,
    this.minLen,
    this.maxLen,
    this.email,
    this.url,
    this.uuid,
    this.ip,
    this.regex,
    this.inList,
    this.notIn,
    this.starts,
    this.ends,
    this.alpha,
    this.alnum,
    this.dash,
  });

  static const DtoSchema<TextRules> schema = $TextRulesDto;
}

@Dto()
class ChangeText {
  @Trim()
  final String? trimmed;

  @Trim()
  @Lowercase()
  final String? lower;

  @Uppercase()
  final String? upper;

  @AllowEmpty()
  final String? keep;

  @Trim()
  final String? blank;

  const ChangeText({
    this.trimmed,
    this.lower,
    this.upper,
    this.keep,
    this.blank,
  });

  static const DtoSchema<ChangeText> schema = $ChangeTextDto;
}

@Dto()
class NumberRules {
  @Min(18)
  final int? min;

  @Max(100)
  final int? max;

  @Range(1, 10)
  final num? range;

  @Positive()
  final int? positive;

  @GreaterThan(0.5)
  final double? gt;

  @LessThan(100)
  final num? lt;

  @In(<int>[1, 2, 3])
  final int? inNum;

  @NotIn(<int>[0])
  final int? notInNum;

  const NumberRules({
    this.min,
    this.max,
    this.range,
    this.positive,
    this.gt,
    this.lt,
    this.inNum,
    this.notInNum,
  });

  static const DtoSchema<NumberRules> schema = $NumberRulesDto;
}

@Dto()
class ListRules {
  @MinItems(1)
  final List<int>? minItems;

  @MaxItems(2)
  final List<String>? maxItems;

  @UniqueItems()
  final List<String>? unique;

  @Email()
  final List<String>? emails;

  const ListRules({this.minItems, this.maxItems, this.unique, this.emails});

  static const DtoSchema<ListRules> schema = $ListRulesDto;
}

@Dto()
class DateRules {
  @After('2000-01-01')
  final DateTime? after;

  @Before('now')
  final DateTime? before;

  const DateRules({this.after, this.before});

  static const DtoSchema<DateRules> schema = $DateRulesDto;
}

@Dto()
class AllTypes {
  final String? s;
  final int? i;
  final double? d;
  final num? n;
  final bool? b;
  final DateTime? dt;
  final Role? role;
  final List<int>? list;
  final Map<String, int>? map;
  final Object? any;
  final Map<String, dynamic>? raw;

  const AllTypes({
    this.s,
    this.i,
    this.d,
    this.n,
    this.b,
    this.dt,
    this.role,
    this.list,
    this.map,
    this.any,
    this.raw,
  });

  static const DtoSchema<AllTypes> schema = $AllTypesDto;
}

@Dto(source: Source.query)
class SearchUsers {
  final String? q;
  final int page;
  final List<String> tags;

  const SearchUsers({this.q, this.page = 1, this.tags = const <String>[]});

  static const DtoSchema<SearchUsers> schema = $SearchUsersDto;
}

@Dto(strict: true)
class StrictInput {
  final String name;

  const StrictInput({required this.name});

  static const DtoSchema<StrictInput> schema = $StrictInputDto;
}

@Dto(
  messages: <String, String>{
    'email.required': 'We need your email',
    'required': 'Please fill in {field}',
    'integer': 'The {field} must be a number',
  },
)
class WithMessages {
  final String email;
  final String name;
  final int? age;

  @Length(min: 3, message: 'At least {min} letters, please')
  final String? nick;

  const WithMessages({
    required this.email,
    required this.name,
    this.age,
    this.nick,
  });

  static const DtoSchema<WithMessages> schema = $WithMessagesDto;
}

@Dto()
class SignUpKeys {
  final String firstName;

  @Name('emailAddress')
  final String email;

  const SignUpKeys({required this.firstName, required this.email});

  static const DtoSchema<SignUpKeys> schema = $SignUpKeysDto;
}

@Dto(keyCase: KeyCase.field)
class CamelKeys {
  final String firstName;

  const CamelKeys({required this.firstName});

  static const DtoSchema<CamelKeys> schema = $CamelKeysDto;
}

@Dto()
class UpdateUser {
  @Length(max: 5)
  final Maybe<String?> bio;

  final Maybe<int> age;

  const UpdateUser({
    this.bio = const Maybe<String?>.missing(),
    this.age = const Maybe<int>.missing(),
  });

  static const DtoSchema<UpdateUser> schema = $UpdateUserDto;
}

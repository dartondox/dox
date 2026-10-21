import 'package:dox_core/dox_core.dart';

import 'custom.dto.dart';
import 'database.dto.dart';
import 'files.dto.dart';
import 'nested.dto.dart';
import 'rules.dto.dart';

/// Every test DTO, like `lib/dtos.g.dart` in an app.
const List<DtoSchema<Object>> testDtos = <DtoSchema<Object>>[
  $CreateUserDto,
  $TextRulesDto,
  $ChangeTextDto,
  $NumberRulesDto,
  $ListRulesDto,
  $DateRulesDto,
  $AllTypesDto,
  $SearchUsersDto,
  $StrictInputDto,
  $WithMessagesDto,
  $SignUpKeysDto,
  $CamelKeysDto,
  $UpdateUserDto,
  $AddressDto,
  $OrderItemDto,
  $CreateOrderDto,
  $SignUpDto,
  $AsyncCheckDto,
  $CreatePostDto,
  $UploadAvatarDto,
  $CreateMemberDto,
  $UpdateMemberDto,
];

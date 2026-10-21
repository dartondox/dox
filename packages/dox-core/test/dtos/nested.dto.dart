import 'package:dox_core/dox_core.dart';

part 'nested.dto.g.dart';

@Dto()
class Address {
  final String city;

  @Length(min: 5, max: 5)
  final String postCode;

  const Address({required this.city, required this.postCode});

  void validate(DtoErrors errors) {
    if (city == 'Nowhere') errors.add('city', 'No such city');
  }

  static const DtoSchema<Address> schema = $AddressDto;
}

@Dto()
class OrderItem {
  final String name;

  @Positive()
  final int quantity;

  const OrderItem({required this.name, required this.quantity});

  static const DtoSchema<OrderItem> schema = $OrderItemDto;
}

@Dto()
class CreateOrder {
  final Address address;

  @MinItems(1)
  final List<OrderItem> items;

  final Address? billing;

  const CreateOrder({required this.address, required this.items, this.billing});

  static const DtoSchema<CreateOrder> schema = $CreateOrderDto;
}

@Dto()
class SignUp {
  @MinLength(8)
  final String password;

  final String passwordConfirmation;

  final DateTime? startsAt;
  final DateTime? endsAt;

  const SignUp({
    required this.password,
    required this.passwordConfirmation,
    this.startsAt,
    this.endsAt,
  });

  void validate(DtoErrors errors) {
    if (password != passwordConfirmation) {
      errors.add('password_confirmation', 'The passwords do not match');
    }
    if (startsAt != null && endsAt != null && !endsAt!.isAfter(startsAt!)) {
      errors.add('ends_at', 'The end must be after the start');
    }
  }

  static const DtoSchema<SignUp> schema = $SignUpDto;
}

@Dto()
class AsyncCheck {
  final String code;

  const AsyncCheck({required this.code});

  Future<void> validate(DtoErrors errors) async {
    await Future<void>.delayed(Duration.zero);
    if (code == 'bad') errors.add('code', 'The code is bad');
  }

  static const DtoSchema<AsyncCheck> schema = $AsyncCheckDto;
}

import 'package:dox_core/dox_core.dart';

import 'city.dart' show RvCity;
import 'noshow.dart';

part 'hidden.g.dart';

/// It uses classes whose generated code it can not call.
@Serialize()
class HiddenSer extends Serializer<Thing> {
  HiddenSer(super.data);

  @override
  Map<String, dynamic> convert(Thing m) {
    return <String, dynamic>{
      't': ThingSer(m),
      'ts': ThingSer(<Thing>[m]),
    };
  }
}

@Serialize()
class HiddenPlain {
  final PlainB p;
  final RvCity city;

  const HiddenPlain(this.p, this.city);
}

@Serialize()
class HiddenCity {
  final RvCity city;
  final List<RvCity> cities;

  const HiddenCity(this.city, this.cities);
}

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import 'requirements/core_flags_cases.dart';

/// every CoreFlags item, all off: the default behavior
void main() {
  group('flags off', () => coreFlagTests(const CoreFlags()));
}

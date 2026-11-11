import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import 'requirements/core_flags_cases.dart';

/// every CoreFlags item, all on: the Laravel behavior
void main() {
  group('flags on', () => coreFlagTests(const CoreFlags.all()));
}

library dox_builder;

import 'package:build/build.dart';
import 'package:dox_builder/src/dox_builder.dart';
import 'package:source_gen/source_gen.dart';

Builder buildDoxModel(BuilderOptions options) => SharedPartBuilder(
      [DoxModelBuilder()],
      'dox_model_generator',
    );

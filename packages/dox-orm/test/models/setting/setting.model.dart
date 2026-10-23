import 'package:dox_orm/dox_orm.dart';

part 'setting.model.g.dart';

/// a model without created_at and updated_at columns
@DoxModel(timestamps: false)
class Setting extends SettingGenerator {
  @Column()
  String? name;
}

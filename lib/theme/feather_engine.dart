import 'loonbox_theme.dart';
import 'default_feathers/bluemonday.dart';
import 'default_feathers/gonzo.dart';
import 'default_feathers/pinkmartini.dart';
import 'default_feathers/purplerain.dart';

/// Registry of all available feathers (themes).
class FeatherEngine {
  FeatherEngine._();

  static final Map<String, LoonBoxFeather> _builtIn = {
    blueMonday.id: blueMonday,
    gonzo.id: gonzo,
    pinkMartini.id: pinkMartini,
    purpleRain.id: purpleRain,
  };

  static List<LoonBoxFeather> get availableFeathers => _builtIn.values.toList();

  static LoonBoxFeather? getFeather(String id) => _builtIn[id];

  static LoonBoxFeather get defaultFeather => blueMonday;
}

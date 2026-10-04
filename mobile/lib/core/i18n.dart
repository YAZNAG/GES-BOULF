import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'i18n_ar.dart';

/// Langue de l'interface : 'fr' (par défaut) ou 'ar' (arabe, de droite à gauche).
class AppLang extends ChangeNotifier {
  static const _key = 'lang';
  static const supported = ['fr', 'ar'];

  String _code = 'fr';

  String get code => _code;
  bool get isAr => _code == 'ar';
  TextDirection get direction => isAr ? TextDirection.rtl : TextDirection.ltr;

  /// Locale des formats `intl` portant des noms (jours, mois).
  String get dateLocale => isAr ? 'ar' : 'fr_FR';

  /// Charge la langue enregistrée (à appeler avant `runApp`).
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved != null && supported.contains(saved)) _code = saved;
    } catch (_) {}
  }

  /// Change la langue, l'enregistre et reconstruit toute l'interface.
  Future<void> set(String code) async {
    if (!supported.contains(code) || code == _code) return;
    _code = code;
    notifyListeners();
    _rebuildAll();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, code);
    } catch (_) {}
  }

  /// Force la reconstruction de tous les widgets (y compris les écrans déjà ouverts
  /// et les widgets `const`) pour que les textes traduits soient relus.
  void _rebuildAll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      void rebuild(Element e) {
        e.markNeedsBuild();
        e.visitChildren(rebuild);
      }

      WidgetsBinding.instance.rootElement?.visitChildren(rebuild);
    });
  }
}

/// Langue courante de l'application.
final appLang = AppLang();

/// Traduction d'un texte français (la clé est le texte français exact).
/// `{cle}` est remplacé par la valeur correspondante de [args].
String tr(String fr, [Map<String, Object?>? args]) {
  var s = appLang.isAr ? (arabicStrings[fr] ?? fr) : fr;
  if (args != null) {
    args.forEach((k, v) => s = s.replaceAll('{$k}', '${v ?? ''}'));
  }
  return s;
}

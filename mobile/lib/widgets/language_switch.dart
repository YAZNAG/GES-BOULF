import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import 'common.dart';

/// Nom d'une langue dans sa propre écriture.
String languageName(String code) => code == 'ar' ? 'العربية' : 'Français';

/// Sélecteur « Français / العربية » (appliqué immédiatement et enregistré).
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appLang,
      builder: (context, _) => SegmentedButton<String>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColors.primary.withValues(alpha: 0.12),
          selectedForegroundColor: AppColors.primary,
        ),
        segments: const [
          ButtonSegment(value: 'fr', label: Text('Français'), icon: Icon(Icons.translate, size: 18)),
          ButtonSegment(value: 'ar', label: Text('العربية'), icon: Icon(Icons.translate, size: 18)),
        ],
        selected: {appLang.code},
        onSelectionChanged: (v) => appLang.set(v.first),
      ),
    );
  }
}

/// Carte « Langue » avec le sélecteur (profil, à propos).
class LanguageCard extends StatelessWidget {
  const LanguageCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: tr('Langue'),
      icon: Icons.language,
      children: const [SizedBox(width: double.infinity, child: LanguageSelector())],
    );
  }
}

/// Ligne « Langue » d'une liste : ouvre un choix Français / العربية.
class LanguageTile extends StatelessWidget {
  const LanguageTile({super.key, this.color = AppColors.info});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconSquare(Icons.language, color: color),
      title: Text(tr('Langue'), style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('Français / العربية', style: const TextStyle(fontSize: 12.5)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(languageName(appLang.code), style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
        const Icon(Icons.chevron_right, color: AppColors.muted),
      ]),
      onTap: () => showLanguagePicker(context),
    );
  }
}

/// Feuille de choix de la langue.
Future<void> showLanguagePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(tr('Langue de l’application'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
        for (final code in AppLang.supported)
          ListTile(
            leading: Icon(
              appLang.code == code ? Icons.radio_button_checked : Icons.radio_button_off,
              color: appLang.code == code ? AppColors.primary : AppColors.muted,
            ),
            title: Text(languageName(code), style: const TextStyle(fontWeight: FontWeight.w700)),
            onTap: () {
              Navigator.pop(c);
              appLang.set(code);
            },
          ),
        const SizedBox(height: 12),
      ]),
    ),
  );
}

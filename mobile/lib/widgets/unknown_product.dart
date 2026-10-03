import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../screens/products/quick_add_screen.dart';
import 'common.dart';

/// Code-barres scanné absent du magasin.
/// La recherche automatique (bases ouvertes + assistant IA) démarre tout de suite : la fenêtre montre
/// la photo et les noms trouvés, puis « Ajouter ce produit » ouvre le formulaire déjà rempli
/// (seul le prix de vente reste à saisir). Renvoie l'article créé, ou null.
Future<Json?> offerAddProduct(BuildContext context, String code) async {
  final api = context.api;
  final recherche = api.get('articles/fiche', {'code': code}).then((r) => (r as Map).cast<String, dynamic>());

  final result = await showDialog<Json>(
    context: context,
    builder: (c) => _UnknownDialog(code: code, recherche: recherche),
  );
  if (result == null || !context.mounted) return null;
  // Créé entre-temps ailleurs : on renvoie l'article existant.
  final existant = result.obj('deja_existant');
  if (existant != null) return existant;
  return QuickAddScreen.open(context, code, fiche: result.obj('fiche'));
}

class _UnknownDialog extends StatelessWidget {
  const _UnknownDialog({required this.code, required this.recherche});

  final String code;
  final Future<Json> recherche;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Json>(
      future: recherche,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final res = snap.data ?? const {};
        final fiche = res.obj('fiche') ?? const {};
        final trouve = fiche.flag('trouve');
        final img = context.api.imageUrl(fiche['image_url']);
        final ar = fiche.strOrNull('name_ar');
        return AlertDialog(
          icon: const Icon(Icons.qr_code_2, color: AppColors.primary, size: 34),
          title: const Text('Produit introuvable'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Le code $code n’existe pas dans le magasin.', textAlign: TextAlign.center),
            const SizedBox(height: 14),
            if (loading)
              const Column(children: [
                SizedBox(height: 8),
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text('Recherche automatique du produit…', style: TextStyle(color: AppColors.muted)),
              ])
            else if (trouve)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    clipBehavior: Clip.antiAlias,
                    child: img != null
                        ? Image.network(img, fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported_outlined, color: AppColors.muted))
                        : const Icon(Icons.inventory_2_outlined, color: AppColors.muted),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: const [
                        Icon(Icons.auto_awesome, size: 14, color: AppColors.success),
                        SizedBox(width: 4),
                        Text('Trouvé automatiquement', style: TextStyle(color: AppColors.success, fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 2),
                      Text(fiche.str('name_fr'), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (ar != null) Align(alignment: Alignment.centerLeft, child: ArabicText(ar, maxLines: 1)),
                    ]),
                  ),
                ]),
              )
            else
              Text(
                snap.hasError
                    ? 'Recherche automatique indisponible. Vous pouvez saisir le produit vous-même.'
                    : 'Produit inconnu des bases ouvertes : saisissez son nom, sa catégorie et son prix.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
            if (!loading) ...[
              const SizedBox(height: 10),
              const Text('Il suffit ensuite d’indiquer le prix de vente.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
            FilledButton.icon(
              // Pendant la recherche, le bouton reste actif : le formulaire attendra le résultat.
              onPressed: () => Navigator.pop(context, snap.data ?? <String, dynamic>{}),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Ajouter ce produit'),
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../screens/products/quick_add_screen.dart';

/// Code-barres scanné absent du magasin : message + bouton « Ajouter ce produit »
/// qui ouvre le formulaire d'ajout (fiche préremplie automatiquement, seul le prix de vente est à saisir).
/// Renvoie l'article créé, ou null si l'utilisateur renonce.
Future<Json?> offerAddProduct(BuildContext context, String code) async {
  final ajouter = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.qr_code_2, color: AppColors.primary, size: 36),
      title: const Text('Produit introuvable'),
      content: Text('Le code $code n’existe pas dans le magasin.\n\n'
          'Ajoutez-le maintenant : la fiche (photo, nom français et arabe) est préparée automatiquement, '
          'il suffit d’indiquer le prix de vente.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Fermer')),
        FilledButton.icon(
          onPressed: () => Navigator.pop(c, true),
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Ajouter ce produit'),
        ),
      ],
    ),
  );
  if (ajouter != true || !context.mounted) return null;
  return QuickAddScreen.open(context, code);
}

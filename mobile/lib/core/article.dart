import 'api.dart';

/// Lecture d'un article de l'API (forme `articles`, `lookup`, `tarifs` ou `stock.article`).
extension ArticleRead on Json {
  String get articleName {
    final fr = strOrNull('name_fr');
    return fr ?? str('nom', 'Article');
  }

  String? get articleNameAr => strOrNull('name_ar');
  String get barcode => str('code_article');
  String get unit => str('unite');

  /// Prix (objet `prix` des articles, ou champs à plat des tarifs).
  Json get prices => obj('prix') ?? this;

  double get prixAchat => prices.dbl('prix_achat');
  double get prixVente => prices.dbl('prix_vente');
  double get prixGros => prices.dbl('prix_gros');
  double get prixPromo => prices.dbl('prix_promo');

  /// Prix appliqué en caisse : promo si > 0, sinon prix de vente.
  double get sellPrice => prixPromo > 0 ? prixPromo : prixVente;
  bool get hasPromo => prixPromo > 0 && prixPromo < prixVente;

  bool get isActive => flag('actif', true);
  bool get isPriced => sellPrice > 0;

  double? get stockQty {
    final s = obj('stock');
    if (s == null) return null;
    return s.dbl('quantite');
  }

  double get stockMin => obj('stock')?.dbl('seuil_min') ?? 0;

  /// Marge sur prix de vente, en % (null si inconnue).
  double? get margin {
    final m = dblOrNull('marge');
    if (m != null) return m;
    if (prixVente <= 0 || prixAchat <= 0) return null;
    return (prixVente - prixAchat) / prixVente * 100;
  }

  String? get brandName => obj('marque')?.strOrNull('nom');

  String? get categoryName {
    final sc = obj('sous_categorie');
    final c = sc?.obj('categorie');
    return c?.strOrNull('name_fr') ?? c?.strOrNull('nom') ?? sc?.strOrNull('name_fr') ?? sc?.strOrNull('nom');
  }

  String? get subCategoryName {
    final sc = obj('sous_categorie');
    return sc?.strOrNull('name_fr') ?? sc?.strOrNull('nom');
  }

  String? get familyName => obj('sous_categorie')?.obj('categorie')?.obj('famille')?.strOrNull('nom_fr');
}

/// Nom d'un mode de paiement.
String paymentModeLabel(String? mode) => switch ((mode ?? '').toLowerCase()) {
      'especes' || 'espece' || 'espèces' || 'cash' => 'Espèces',
      'carte' || 'card' || 'tpe' => 'Carte',
      'cheque' || 'chèque' => 'Chèque',
      'virement' => 'Virement',
      'effet' => 'Effet',
      'credit' || 'crédit' => 'Crédit',
      '' => '—',
      _ => mode!,
    };

const paymentModes = [
  ('especes', 'Espèces'),
  ('carte', 'Carte'),
  ('cheque', 'Chèque'),
  ('virement', 'Virement'),
];

/// Image d'une marque : `image` déjà « /storage/… » ou URL (photo changée depuis l'app), sinon `image_url`.
String? brandImagePath(Json m) {
  final img = m.strOrNull('image');
  if (img != null && (img.startsWith('/') || img.startsWith('http'))) return img;
  return m.strOrNull('image_url') ?? img;
}

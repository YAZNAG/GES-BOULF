import 'api.dart';
import 'i18n.dart';

/// Nom français d'une famille / catégorie / sous-catégorie (`nom_fr`, `name_fr` ou `nom`).
String? catNameFr(Json? j) => j == null ? null : j.strOrNull('nom_fr') ?? j.strOrNull('name_fr') ?? j.strOrNull('nom');

/// Nom arabe d'une famille / catégorie / sous-catégorie (`nom_ar` ou `name_ar`).
String? catNameAr(Json? j) => j == null ? null : j.strOrNull('nom_ar') ?? j.strOrNull('name_ar');

/// Nom affiché d'une famille / catégorie / sous-catégorie dans la langue courante
/// (arabe si actif et renseigné, sinon français).
String catName(Json? j, [String fallback = '—']) {
  final fr = catNameFr(j);
  final ar = catNameAr(j);
  return (appLang.isAr ? ar ?? fr : fr ?? ar) ?? fallback;
}

/// Ligne secondaire sous le nom : l'arabe en français, le français en arabe (null si identique/absent).
String? catSecondary(Json? j) {
  final fr = catNameFr(j);
  final ar = catNameAr(j);
  final s = appLang.isAr ? (ar == null ? null : fr) : ar;
  return s == catName(j) ? null : s;
}

/// Lecture d'un article de l'API (forme `articles`, `lookup`, `tarifs` ou `stock.article`).
extension ArticleRead on Json {
  /// Nom français (name_fr, sinon nom).
  String get articleNameFr => strOrNull('name_fr') ?? str('nom', tr('Article'));

  /// Nom affiché dans la langue courante (arabe si actif et renseigné).
  String get articleName {
    if (appLang.isAr) {
      final ar = strOrNull('name_ar');
      if (ar != null) return ar;
    }
    return articleNameFr;
  }

  /// Ligne secondaire sous le nom : l'arabe en français, le français en arabe (null si absent).
  String? get articleNameAr {
    final ar = strOrNull('name_ar');
    if (!appLang.isAr) return ar;
    return ar == null ? null : articleNameFr;
  }
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
    final n = catNameFr(c) ?? catNameAr(c);
    return n != null ? catName(c) : (catNameFr(sc) ?? catNameAr(sc)) != null ? catName(sc) : null;
  }

  String? get subCategoryName {
    final sc = obj('sous_categorie');
    return (catNameFr(sc) ?? catNameAr(sc)) != null ? catName(sc) : null;
  }

  String? get familyName {
    final f = obj('sous_categorie')?.obj('categorie')?.obj('famille');
    return (catNameFr(f) ?? catNameAr(f)) != null ? catName(f) : null;
  }
}

/// Nom d'un mode de paiement.
String paymentModeLabel(String? mode) => switch ((mode ?? '').toLowerCase()) {
      'especes' || 'espece' || 'espèces' || 'cash' => tr('Espèces'),
      'carte' || 'card' || 'tpe' => tr('Carte'),
      'cheque' || 'chèque' => tr('Chèque'),
      'virement' => tr('Virement'),
      'effet' => tr('Effet'),
      'credit' || 'crédit' => tr('Crédit'),
      '' => '—',
      _ => mode!,
    };

/// Modes de paiement (code, libellé français — afficher avec `tr(libellé)`).
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

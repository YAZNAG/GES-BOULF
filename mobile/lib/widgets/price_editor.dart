import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/article.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import 'common.dart';

/// Modification rapide des prix d'un article (PUT tarifs/{id}). Renvoie true si enregistré.
Future<bool> editPrices(BuildContext context, Json article) async {
  final res = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (c) => _PriceSheet(article: article),
  );
  return res ?? false;
}

class _PriceSheet extends StatefulWidget {
  const _PriceSheet({required this.article});

  final Json article;

  @override
  State<_PriceSheet> createState() => _PriceSheetState();
}

class _PriceSheetState extends State<_PriceSheet> {
  late final _achat = TextEditingController(text: priceInput(widget.article.prixAchat));
  late final _vente = TextEditingController(text: priceInput(widget.article.prixVente));
  late final _gros = TextEditingController(text: priceInput(widget.article.prixGros));
  late final _promo = TextEditingController(text: priceInput(widget.article.prixPromo));
  late bool _actif = widget.article.isActive;
  bool _busy = false;
  Map<String, List<String>> _errors = {};

  @override
  void dispose() {
    for (final c in [_achat, _vente, _gros, _promo]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _marge {
    final a = parseInput(_achat.text) ?? 0;
    final v = parseInput(_vente.text) ?? 0;
    if (a <= 0 || v <= 0) return null;
    return (v - a) / v * 100;
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _errors = {};
    });
    try {
      await context.api.put('tarifs/${widget.article.integer('id')}', {
        'prix_achat': parseInput(_achat.text) ?? 0,
        'prix_vente': parseInput(_vente.text) ?? 0,
        'prix_gros': parseInput(_gros.text) ?? 0,
        'prix_promo': parseInput(_promo.text),
        'actif': _actif,
      });
      if (mounted) {
        showSuccess(context, tr('Prix enregistrés.'));
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _errors = e.errors);
        if (e.errors.isEmpty) showError(context, e);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String label, TextEditingController c, String key, {IconData? icon, bool autofocus = false}) {
    return TextField(
      controller: c,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: tr(label),
        suffixText: tr('DH'),
        prefixIcon: icon == null ? null : Icon(icon, size: 20),
        errorText: _errors[key]?.first,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = _marge;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(tr('Modifier les prix'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ProductHeader(article: widget.article),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _field('Prix d’achat', _achat, 'prix_achat', icon: Icons.shopping_bag_outlined)),
            const SizedBox(width: 10),
            Expanded(child: _field('Prix de vente', _vente, 'prix_vente', icon: Icons.sell_outlined, autofocus: true)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field('Prix de gros', _gros, 'prix_gros')),
            const SizedBox(width: 10),
            Expanded(child: _field('Prix promo', _promo, 'prix_promo')),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.trending_up, color: AppColors.muted, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(tr('Marge sur vente'), style: const TextStyle(color: AppColors.muted))),
              Text(
                m == null ? '—' : percent(m),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: m == null ? AppColors.muted : (m < 0 ? AppColors.danger : (m < 10 ? AppColors.warning : AppColors.success)),
                ),
              ),
            ]),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _actif,
            activeThumbColor: AppColors.primary,
            title: Text(tr('Article actif (vendable en caisse)'), style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(tr('Un prix de vente > 0 active l’article.')),
            onChanged: (v) => setState(() => _actif = v),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: Text(tr('Enregistrer')),
          ),
        ]),
      ),
    );
  }
}

/// En-tête des formulaires de prix : photo du produit, noms FR / AR, marque et code-barres.
class ProductHeader extends StatelessWidget {
  const ProductHeader({super.key, required this.article, this.size = 76});

  final Json article;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ar = article.articleNameAr;
    return Row(children: [
      ItemThumb(path: article['image'], label: article.articleName, size: size),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (article.brandName != null)
            Text(article.brandName!.toUpperCase(),
                style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          Text(article.articleName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          if (ar != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: appLang.isAr
                  ? Directionality(textDirection: TextDirection.ltr, child: Text(ar, maxLines: 1, overflow: TextOverflow.ellipsis))
                  : ArabicText(ar, maxLines: 1),
            ),
          Text(article.barcode, style: const TextStyle(color: AppColors.muted, fontSize: 11.5, fontFamily: 'monospace')),
        ]),
      ),
    ]);
  }
}

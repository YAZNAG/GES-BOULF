import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/article.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/price_editor.dart';
import '../../widgets/stock_adjust.dart';

/// Fiche article : photo, noms FR/AR, prix, marge, stock, description. Renvoie true si modifié.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.articleId, this.initial});

  final int articleId;
  final Json? initial;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _view = GlobalKey<AsyncViewState<Json>>();
  bool _changed = false;

  Future<Json> _load() async => (await context.api.get('articles/${widget.articleId}') as Map).cast<String, dynamic>();

  Future<void> _editPrices(Json a) async {
    if (await editPrices(context, a)) {
      _changed = true;
      _view.currentState?.reload();
    }
  }

  Future<void> _adjust(Json a) async {
    final res = await adjustStock(context,
        articleId: a.integer('id'), name: a.articleName, current: a.stockQty, seuil: a.obj('stock')?.dblOrNull('seuil_min'), unit: a.unit);
    if (res != null) {
      _changed = true;
      _view.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: darkAppBar('Fiche article'),
        body: AsyncView<Json>(
          key: _view,
          load: _load,
          builder: (context, a, reload) => RefreshIndicator(onRefresh: reload, child: _body(context, a)),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Json a) {
    final ar = a.articleNameAr;
    final stock = a.stockQty;
    final m = a.margin;
    final imageUrl = context.api.imageUrl(a['image']);
    final path = [a.familyName, a.categoryName, a.subCategoryName].whereType<String>().toSet().join(' › ');
    return ListView(padding: EdgeInsets.zero, children: [
      // En-tête : image sur fond clair.
      Container(
        height: 230,
        color: Colors.white,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: imageUrl == null
            ? ItemThumb(label: a.articleName, size: 130)
            : GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (c) => Dialog(
                    backgroundColor: Colors.white,
                    child: InteractiveViewer(child: Padding(padding: const EdgeInsets.all(12), child: Image.network(imageUrl))),
                  ),
                ),
                child: Hero(
                  tag: 'article-${a.integer('id')}',
                  child: Image.network(imageUrl, fit: BoxFit.contain, errorBuilder: (_, _, _) => ItemThumb(label: a.articleName, size: 130)),
                ),
              ),
      ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(a.articleName, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, height: 1.2)),
          if (ar != null) ...[
            const SizedBox(height: 4),
            ArabicText(ar, textAlign: TextAlign.right, style: const TextStyle(fontSize: 18, color: AppColors.muted, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            a.isActive ? const Badge2('Actif', color: AppColors.success, icon: Icons.check_circle) : const Badge2('Inactif', color: AppColors.muted),
            if (!a.isPriced) const Badge2('À tarifer', color: AppColors.warning, icon: Icons.sell_outlined),
            if (a.hasPromo) const Badge2('En promotion', color: AppColors.primary, icon: Icons.local_offer),
            if (a.brandName != null) Badge2(a.brandName!, color: AppColors.info, icon: Icons.verified_outlined),
          ]),
          const SizedBox(height: 14),
          if (a.barcode.isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.qr_code_2, color: AppColors.ink),
                title: Text(a.barcode, style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
                subtitle: const Text('Code-barres'),
                trailing: IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: 'Copier',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: a.barcode));
                    showInfo(context, 'Code-barres copié.');
                  },
                ),
              ),
            ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Prix',
            icon: Icons.sell_outlined,
            trailing: TextButton.icon(onPressed: () => _editPrices(a), icon: const Icon(Icons.edit, size: 18), label: const Text('Modifier')),
            children: [
              Row(children: [
                Expanded(child: _PriceBox(label: 'Prix de vente', value: a.prixVente, highlight: true)),
                const SizedBox(width: 10),
                Expanded(child: _PriceBox(label: 'Prix d’achat', value: a.prixAchat)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _PriceBox(label: 'Prix de gros', value: a.prixGros)),
                const SizedBox(width: 10),
                Expanded(child: _PriceBox(label: 'Prix promo', value: a.prixPromo, color: AppColors.primary)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Marge sur vente', style: TextStyle(color: AppColors.muted)),
                const Spacer(),
                if (m != null && a.prixVente > 0)
                  Text('${money(a.prixVente - a.prixAchat)}  ·  ', style: const TextStyle(color: AppColors.muted)),
                Text(
                  m == null ? '—' : percent(m),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: m == null ? AppColors.muted : (m < 0 ? AppColors.danger : (m < 10 ? AppColors.warning : AppColors.success)),
                  ),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Stock',
            icon: Icons.warehouse_outlined,
            trailing: TextButton.icon(onPressed: () => _adjust(a), icon: const Icon(Icons.tune, size: 18), label: const Text('Ajuster')),
            children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(stock == null ? '—' : qty(stock, a.unit),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: stock == null || stock <= 0 ? AppColors.danger : (stock <= a.stockMin ? AppColors.warning : AppColors.ink),
                        )),
                    Text('Seuil minimum : ${qty(a.stockMin, a.unit)}', style: const TextStyle(color: AppColors.muted)),
                  ]),
                ),
                Badge2(
                  stock == null || stock <= 0 ? 'Rupture' : (stock <= a.stockMin ? 'Sous le seuil' : 'En stock'),
                  color: stock == null || stock <= 0 ? AppColors.danger : (stock <= a.stockMin ? AppColors.warning : AppColors.success),
                ),
              ]),
              if (stock != null && a.prixAchat > 0) ...[
                const Divider(height: 22),
                InfoRow('Valeur (achat)', money(stock * a.prixAchat)),
              ],
            ],
          ),
          const SizedBox(height: 14),
          SectionCard(title: 'Classement', icon: Icons.category_outlined, children: [
            InfoRow('Catégorie', path),
            InfoRow('Marque', a.brandName ?? ''),
            InfoRow('Unité', a.unit),
            InfoRow('Référence interne', '#${a.integer('id')}'),
          ]),
          if (a.strOrNull('description') != null) ...[
            const SizedBox(height: 14),
            SectionCard(title: 'Description', icon: Icons.notes, children: [
              Text(a.str('description'), style: const TextStyle(height: 1.45)),
            ]),
          ],
        ]),
      ),
    ]);
  }
}

class _PriceBox extends StatelessWidget {
  const _PriceBox({required this.label, required this.value, this.highlight = false, this.color});

  final String label;
  final double value;
  final bool highlight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primary.withValues(alpha: 0.07) : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: highlight ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value > 0 ? money(value) : '—',
            style: TextStyle(
              fontSize: highlight ? 19 : 16,
              fontWeight: FontWeight.w800,
              color: value > 0 ? (highlight ? AppColors.primary : (color ?? AppColors.ink)) : AppColors.muted,
            ),
          ),
        ),
      ]),
    );
  }
}

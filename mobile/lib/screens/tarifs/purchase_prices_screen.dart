import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/article.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';
import '../../widgets/pickers.dart';
import '../../widgets/price_editor.dart';
import '../../widgets/scanner.dart';
import '../products/product_detail_screen.dart';
import '../../widgets/unknown_product.dart';
import '../../widgets/category_filter.dart';

/// Prix d'achat des articles, avec le dernier achat (bon de réception) et la recherche FR / AR / code-barres.
class PurchasePricesScreen extends StatefulWidget {
  const PurchasePricesScreen({super.key});

  @override
  State<PurchasePricesScreen> createState() => _PurchasePricesScreenState();
}

class _PurchasePricesScreenState extends State<PurchasePricesScreen> {
  final _list = GlobalKey<PagedListState<Json>>();
  String? _statut;
  String _sort = 'nom';
  CategoryFilter? _cat;

  Future<void> _scan() async {
    final code = await ScannerPage.scan(context);
    if (code == null || !mounted) return;
    final a = await runBusy<Json?>(context, () => lookupArticle(context.api, code));
    if (!mounted) return;
    if (a == null && await offerAddProduct(context, code) == null) return;
    _list.currentState?.setSearch(code);
  }

  /// Modification rapide du prix d'achat (le prix de vente ne change pas).
  Future<bool> _edit(Json a) async {
    final ctrl = TextEditingController(text: a.prixAchat > 0 ? priceInput(a.prixAchat) : '');
    final v = await showDialog<double>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Prix d’achat'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ProductHeader(article: a, size: 64),
          const SizedBox(height: 12),
          if (a.prixVente > 0) Text('Prix de vente : ${money(a.prixVente)}', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            decoration: const InputDecoration(labelText: 'Prix d’achat', suffixText: 'DH'),
            onSubmitted: (t) => Navigator.pop(c, parseInput(t)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, parseInput(ctrl.text)), child: const Text('Enregistrer')),
        ],
      ),
    );
    ctrl.dispose();
    if (v == null || v < 0 || !mounted) return false;
    final res = await runBusy(context, () => context.api.put('tarifs/${a.integer('id')}', {'prix_achat': v}), success: 'Prix d’achat enregistré.');
    return res != null;
  }

  @override
  Widget build(BuildContext context) {
    final api = context.api;
    return Scaffold(
      appBar: darkAppBar('Prix d’achat', actions: [
        PopupMenuButton<String>(
          tooltip: 'Trier',
          icon: const Icon(Icons.sort),
          initialValue: _sort,
          onSelected: (v) {
            setState(() => _sort = v);
            _list.currentState?.reload();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'nom', child: Text('Nom (A → Z)')),
            PopupMenuItem(value: 'achat_desc', child: Text('Prix d’achat décroissant')),
            PopupMenuItem(value: 'achat_asc', child: Text('Prix d’achat croissant')),
          ],
        ),
      ]),
      body: PagedList<Json>(
        key: _list,
        searchHint: 'Code-barres, nom FR ou عربي',
        onScan: _scan,
        emptyIcon: Icons.shopping_bag_outlined,
        emptyTitle: 'Aucun article',
        filters: FilterChips<String>(
          leading: [
            CategoryFilterChip(
              value: _cat,
              onChanged: (c) {
                setState(() => _cat = c);
                _list.currentState?.reload();
              },
            ),
          ],
          options: const [(null, 'Tous'), ('sans_achat', 'Sans prix d’achat')],
          value: _statut,
          onChanged: (s) {
            setState(() => _statut = s);
            _list.currentState?.reload();
          },
        ),
        fetch: (page, q) => api.page('tarifs', (j) => j,
            page: page, query: {'q': q, 'statut': _statut, 'sort': _sort, 'with_dernier_achat': 1, ...?_cat?.query}),
        itemBuilder: (ctx, a, reload) => _tile(ctx, a, reload),
      ),
    );
  }

  Widget _tile(BuildContext ctx, Json a, VoidCallback reload) {
    final ar = a.articleNameAr;
    final achat = a.prixAchat;
    final dernier = a.strOrNull('dernier_achat_date');
    return InkWell(
      onTap: () async {
        if (await _edit(a)) reload();
      },
      onLongPress: () => ctx.push(ProductDetailScreen(articleId: a.integer('id'))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(children: [
          ItemThumb(path: a['image'], label: a.articleName, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.articleName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (ar != null) Align(alignment: Alignment.centerLeft, child: ArabicText(ar, maxLines: 1)),
              Text(a.barcode, style: const TextStyle(color: AppColors.muted, fontSize: 11.5, fontFamily: 'monospace')),
              if (dernier != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Dernier achat ${date(dernier)}'
                    '${a.strOrNull('dernier_achat_fournisseur') != null ? ' · ${a.str('dernier_achat_fournisseur')}' : ''}'
                    ' · ${money(a['dernier_achat_prix'])}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.info, fontSize: 11.5),
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(achat > 0 ? money(achat) : 'À saisir',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: achat > 0 ? AppColors.ink : AppColors.warning)),
            if (a.prixVente > 0)
              Text('vente ${money(a.prixVente)}', style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
          ]),
        ]),
      ),
    );
  }
}

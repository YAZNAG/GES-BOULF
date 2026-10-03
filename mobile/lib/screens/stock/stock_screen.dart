import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/article.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';
import '../../widgets/pickers.dart';
import '../../widgets/scanner.dart';
import '../../widgets/stock_adjust.dart';
import '../products/product_detail_screen.dart';
import '../../widgets/unknown_product.dart';
import '../../widgets/category_filter.dart';

/// Articles en stock (quantités, seuils, valeur), avec ajustement rapide.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key, this.initialStatut});

  final String? initialStatut;

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final _list = GlobalKey<PagedListState<Json>>();
  late String? _statut = widget.initialStatut;
  CategoryFilter? _cat;
  String _sort = 'nom';

  void _setStatut(String? s) {
    setState(() => _statut = s);
    _list.currentState?.reload();
  }

  Future<void> _scan() async {
    final code = await ScannerPage.scan(context);
    if (code == null || !mounted) return;
    final a = await runBusy<Json?>(context, () => lookupArticle(context.api, code));
    if (!mounted) return;
    if (a == null && await offerAddProduct(context, code) == null) return;
    _list.currentState?.setSearch(code);
  }

  @override
  Widget build(BuildContext context) {
    final api = context.api;
    return Scaffold(
      appBar: darkAppBar('Stock', actions: [
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
            PopupMenuItem(value: 'quantite_asc', child: Text('Quantité croissante')),
            PopupMenuItem(value: 'quantite_desc', child: Text('Quantité décroissante')),
            PopupMenuItem(value: 'valeur', child: Text('Valeur')),
          ],
        ),
      ]),
      body: PagedList<Json>(
        key: _list,
        searchHint: 'Code-barres, nom FR ou عربي',
        onScan: _scan,
        emptyIcon: Icons.warehouse_outlined,
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
          options: const [(null, 'Tous'), ('en_stock', 'En stock'), ('sous_seuil', 'Sous le seuil'), ('rupture', 'En rupture')],
          value: _statut,
          onChanged: _setStatut,
        ),
        headerBuilder: (context, raw) {
          final s = raw.obj('stats');
          if (s == null) return null;
          return Column(children: [
            StatsRow(children: [
              MiniStat(label: 'En stock', value: qty(s['en_stock']), color: AppColors.success, onTap: () => _setStatut('en_stock'), selected: _statut == 'en_stock'),
              MiniStat(label: 'Sous seuil', value: qty(s['sous_seuil']), color: AppColors.warning, onTap: () => _setStatut('sous_seuil'), selected: _statut == 'sous_seuil'),
              MiniStat(label: 'Rupture', value: qty(s['rupture']), color: AppColors.danger, onTap: () => _setStatut('rupture'), selected: _statut == 'rupture'),
            ]),
            StatsRow(padding: const EdgeInsets.fromLTRB(16, 8, 16, 10), children: [
              MiniStat(label: 'Valeur d’achat', value: moneyShort(s['valeur_achat'])),
              MiniStat(label: 'Valeur de vente', value: moneyShort(s['valeur_vente']), color: AppColors.info),
            ]),
          ]);
        },
        fetch: (page, q) => api.page('stock', (j) => j,
            page: page, query: {'q': q, 'statut': _statut, 'sort': _sort, 'with_stats': page == 1 ? 1 : null, ...?_cat?.query}),
        itemBuilder: (ctx, s, reload) {
          final a = s.obj('article') ?? {};
          final q = s.dbl('quantite');
          final min = s.dbl('seuil_min');
          final color = q <= 0 ? AppColors.danger : (q <= min ? AppColors.warning : AppColors.success);
          return InkWell(
            onTap: () async {
              final changed = await ctx.push<bool>(ProductDetailScreen(articleId: s.integer('article_id', a.integer('id'))));
              if (changed == true) reload();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(children: [
                ItemThumb(path: a['image'], label: a.articleName, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.articleName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      [
                        if (a.barcode.isNotEmpty) a.barcode,
                        'Seuil ${qty(min)}',
                        if (s.dbl('valeur_achat') > 0) moneyShort(s['valeur_achat']),
                      ].join(' · '),
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(qty(q), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
                  Text(a.unit, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                ]),
                IconButton(
                  tooltip: 'Ajuster',
                  icon: const Icon(Icons.tune, size: 20),
                  onPressed: () async {
                    final res = await adjustStock(ctx,
                        articleId: s.integer('article_id', a.integer('id')), name: a.articleName, current: q, seuil: min, unit: a.unit);
                    if (res != null) reload();
                  },
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

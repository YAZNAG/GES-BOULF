import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';
import '../../widgets/pickers.dart';
import '../../widgets/scanner.dart';
import 'product_create_screen.dart';
import 'product_detail_screen.dart';
import '../../widgets/unknown_product.dart';
import '../../widgets/category_filter.dart';

/// Filtre de catégorie choisi (famille ou catégorie).
/// Liste des produits (recherche code-barres / FR / AR, scan, filtres).
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _list = GlobalKey<PagedListState<Json>>();
  String? _statut;
  String _sort = 'nom';
  CategoryFilter? _cat;

  Future<void> _scan() async {
    final code = await ScannerPage.scan(context, title: 'Rechercher un article');
    if (code == null || !mounted) return;
    final api = context.api;
    final a = await runBusy(context, () => lookupArticle(api, code));
    if (!mounted) return;
    var article = a;
    if (article == null) {
      // Produit absent : proposer l'ajout avec la fiche préparée automatiquement.
      article = await offerAddProduct(context, code);
      if (article == null || !mounted) return;
    }
    await context.push(ProductDetailScreen(articleId: article.integer('id'), initial: article));
    _list.currentState?.reload();
  }

  void _setCat(CategoryFilter? c) {
    setState(() => _cat = c);
    _list.currentState?.reload();
  }

  void _setStatut(String? s) {
    setState(() => _statut = s);
    _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.api;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'produit-ajout',
        onPressed: () async {
          final a = await context.push<Json>(const ProductCreateScreen());
          if (a != null) _list.currentState?.reload();
        },
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      appBar: darkAppBar('Produits', actions: [
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
            PopupMenuItem(value: 'recent', child: Text('Plus récents')),
            PopupMenuItem(value: 'prix_asc', child: Text('Prix croissant')),
            PopupMenuItem(value: 'prix_desc', child: Text('Prix décroissant')),
          ],
        ),
      ]),
      body: PagedList<Json>(
        key: _list,
        searchHint: 'Code-barres, nom FR ou عربي',
        onScan: _scan,
        emptyIcon: Icons.inventory_2_outlined,
        emptyTitle: 'Aucun produit',
        filters: FilterChips<String>(
          leading: [CategoryFilterChip(value: _cat, onChanged: _setCat)],
          options: const [(null, 'Tous'), ('actif', 'Actifs'), ('a_tarifer', 'À tarifer'), ('rupture', 'En rupture'), ('inactif', 'Inactifs')],
          value: _statut,
          onChanged: _setStatut,
        ),
        headerBuilder: (context, raw) {
          final s = raw.obj('stats');
          if (s == null) return null;
          return StatsRow(padding: const EdgeInsets.fromLTRB(16, 12, 16, 10), children: [
            MiniStat(label: 'Produits', value: qty(s['total']), onTap: () => _setStatut(null), selected: _statut == null),
            MiniStat(label: 'Actifs', value: qty(s['actifs']), color: AppColors.success, onTap: () => _setStatut('actif'), selected: _statut == 'actif'),
            MiniStat(label: 'À tarifer', value: qty(s['a_tarifer']), color: AppColors.warning, onTap: () => _setStatut('a_tarifer'), selected: _statut == 'a_tarifer'),
            MiniStat(label: 'Rupture', value: qty(s['rupture']), color: AppColors.danger, onTap: () => _setStatut('rupture'), selected: _statut == 'rupture'),
          ]);
        },
        fetch: (page, q) => api.page('articles', (j) => j, page: page, query: {
          'q': q,
          'statut': _statut,
          'sort': _sort,
          ...?_cat?.query,
          'with_stats': page == 1 ? 1 : null,
        }),
        itemBuilder: (ctx, a, reload) => ArticleTile(
          article: a,
          onTap: () async {
            final changed = await ctx.push<bool>(ProductDetailScreen(articleId: a.integer('id'), initial: a));
            if (changed == true) reload();
          },
        ),
      ),
    );
  }
}

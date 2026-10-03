import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';
import '../../widgets/pickers.dart';
import '../../widgets/scanner.dart';
import 'product_detail_screen.dart';
import 'quick_add_screen.dart';

/// Filtre de catégorie choisi (famille ou catégorie).
class CategoryFilter {
  const CategoryFilter({this.familleId, this.categorieId, required this.label});

  final int? familleId;
  final int? categorieId;
  final String label;
}

/// Feuille de choix famille → catégorie.
Future<CategoryFilter?> pickCategoryFilter(BuildContext context) {
  return showModalBottomSheet<CategoryFilter>(
    context: context,
    isScrollControlled: true,
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => _CategorySheet(scroll: scroll),
    ),
  );
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({required this.scroll});

  final ScrollController scroll;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  List<Json>? _familles;
  Json? _famille;
  List<Json>? _categories;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadFamilles();
  }

  Future<void> _loadFamilles() async {
    try {
      final r = await context.api.get('familles', {'per_page': 200}) as Json;
      if (mounted) setState(() => _familles = r.list('data'));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _openFamille(Json f) async {
    setState(() {
      _famille = f;
      _categories = null;
    });
    try {
      final r = await context.api.get('categories', {'per_page': 1000, 'famille_id': f.integer('id')}) as Json;
      if (mounted) setState(() => _categories = r.list('data'));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = _famille;
    final list = f == null ? _familles : _categories;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
        child: Row(children: [
          if (f != null)
            IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _famille = null))
          else
            const SizedBox(width: 12),
          Expanded(
            child: Text(f == null ? 'Familles' : f.str('nom_fr'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          if (f == null)
            TextButton(
              onPressed: () => Navigator.pop(context, const CategoryFilter(label: 'Toutes')),
              child: const Text('Tout afficher'),
            ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: list == null
            ? (_error != null
                ? ErrorState(error: _error!, onRetry: () {
                    setState(() => _error = null);
                    f == null ? _loadFamilles() : _openFamille(f);
                  })
                : const Center(child: CircularProgressIndicator()))
            : ListView(controller: widget.scroll, children: [
                if (f != null)
                  ListTile(
                    leading: const IconSquare(Icons.select_all),
                    title: Text('Toute la famille « ${f.str('nom_fr')} »', style: const TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () => Navigator.pop(context, CategoryFilter(familleId: f.integer('id'), label: f.str('nom_fr'))),
                  ),
                for (final it in list)
                  ListTile(
                    leading: ItemThumb(path: it['image'], label: it.str('nom_fr', it.str('name_fr', it.str('nom'))), size: 42),
                    title: Text(it.str('nom_fr', it.str('name_fr', it.str('nom'))), style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: (it.strOrNull('nom_ar') ?? it.strOrNull('name_ar')) == null
                        ? null
                        : Align(alignment: Alignment.centerLeft, child: ArabicText(it.strOrNull('nom_ar') ?? it.str('name_ar'))),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(qty(it['articles_count']), style: const TextStyle(color: AppColors.muted)),
                      if (f == null) const Icon(Icons.chevron_right),
                    ]),
                    onTap: () => f == null
                        ? _openFamille(it)
                        : Navigator.pop(
                            context,
                            CategoryFilter(
                              familleId: f.integer('id'),
                              categorieId: it.integer('id'),
                              label: it.str('name_fr', it.str('nom')),
                            )),
                  ),
              ]),
      ),
    ]);
  }
}

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
      final ajouter = await confirm(context, 'Article introuvable',
          'Le code $code n’existe pas dans le magasin. Voulez-vous l’ajouter ? Seul le prix de vente est à saisir.',
          ok: 'Ajouter le produit');
      if (!ajouter || !mounted) return;
      article = await QuickAddScreen.open(context, code);
      if (article == null || !mounted) return;
    }
    await context.push(ProductDetailScreen(articleId: article.integer('id'), initial: article));
    _list.currentState?.reload();
  }

  Future<void> _pickCat() async {
    final c = await pickCategoryFilter(context);
    if (c == null) return;
    setState(() => _cat = c.familleId == null ? null : c);
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
          leading: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InputChip(
                avatar: Icon(Icons.category_outlined, size: 18, color: _cat != null ? AppColors.primary : AppColors.muted),
                label: Text(_cat?.label ?? 'Catégorie'),
                selected: _cat != null,
                showCheckmark: false,
                selectedColor: AppColors.primary.withValues(alpha: 0.12),
                side: BorderSide(color: _cat != null ? AppColors.primary : AppColors.border),
                onPressed: _pickCat,
                onDeleted: _cat == null
                    ? null
                    : () {
                        setState(() => _cat = null);
                        _list.currentState?.reload();
                      },
              ),
            ),
          ],
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
          'famille_id': _cat?.familleId,
          'categorie_id': _cat?.categorieId,
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

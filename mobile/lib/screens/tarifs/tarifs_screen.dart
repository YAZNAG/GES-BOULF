import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/article.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';
import '../../widgets/pickers.dart';
import '../../widgets/price_editor.dart';
import '../../widgets/scanner.dart';
import '../products/product_detail_screen.dart';
import '../../widgets/unknown_product.dart';
import '../../widgets/category_filter.dart';

/// Tarifs de vente : prix d'achat / vente / gros / promo et marge, modification rapide.
class TarifsScreen extends StatefulWidget {
  const TarifsScreen({super.key, this.initialStatut});

  final String? initialStatut;

  @override
  State<TarifsScreen> createState() => _TarifsScreenState();
}

class _TarifsScreenState extends State<TarifsScreen> {
  final _list = GlobalKey<PagedListState<Json>>();
  late String? _statut = widget.initialStatut;
  String _sort = 'nom';
  CategoryFilter? _cat;

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
      appBar: darkAppBar(tr('Tarifs de vente'), actions: [
        PopupMenuButton<String>(
          tooltip: tr('Trier'),
          icon: const Icon(Icons.sort),
          initialValue: _sort,
          onSelected: (v) {
            setState(() => _sort = v);
            _list.currentState?.reload();
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'nom', child: Text(tr('Nom (A → Z)'))),
            PopupMenuItem(value: 'vente_asc', child: Text(tr('Prix de vente croissant'))),
            PopupMenuItem(value: 'vente_desc', child: Text(tr('Prix de vente décroissant'))),
            PopupMenuItem(value: 'marge_asc', child: Text(tr('Marge croissante'))),
            PopupMenuItem(value: 'marge_desc', child: Text(tr('Marge décroissante'))),
          ],
        ),
      ]),
      body: PagedList<Json>(
        key: _list,
        searchHint: tr('Code-barres, nom FR ou عربي'),
        onScan: _scan,
        emptyIcon: Icons.sell_outlined,
        emptyTitle: tr('Aucun article'),
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
          options: [
            (null, tr('Tous')),
            ('tarife', tr('Tarifés')),
            ('a_tarifer', tr('À tarifer')),
            ('promo', tr('En promo')),
            ('marge_faible', tr('Marge faible')),
            ('perte', tr('À perte')),
            ('sans_achat', tr('Sans prix d’achat')),
          ],
          value: _statut,
          onChanged: _setStatut,
        ),
        headerBuilder: (context, raw) {
          final s = raw.obj('stats');
          if (s == null) return null;
          return StatsRow(padding: const EdgeInsets.fromLTRB(16, 12, 16, 10), children: [
            MiniStat(label: tr('Tarifés'), value: qty(s['tarifes']), color: AppColors.success, onTap: () => _setStatut('tarife'), selected: _statut == 'tarife'),
            MiniStat(label: tr('À tarifer'), value: qty(s['a_tarifer']), color: AppColors.warning, onTap: () => _setStatut('a_tarifer'), selected: _statut == 'a_tarifer'),
            MiniStat(label: tr('À perte'), value: qty(s['perte']), color: AppColors.danger, onTap: () => _setStatut('perte'), selected: _statut == 'perte'),
            MiniStat(label: tr('Marge moy.'), value: s['marge_moyenne'] == null ? '—' : percent(s['marge_moyenne'])),
          ]);
        },
        fetch: (page, q) => api.page('tarifs', (j) => j, page: page, query: {'q': q, 'statut': _statut, 'sort': _sort, ...?_cat?.query}),
        itemBuilder: (ctx, a, reload) => _TarifTile(
          article: a,
          onEdit: () async {
            if (await editPrices(ctx, a)) reload();
          },
          onOpen: () async {
            final changed = await ctx.push<bool>(ProductDetailScreen(articleId: a.integer('id')));
            if (changed == true) reload();
          },
        ),
      ),
    );
  }
}

class _TarifTile extends StatelessWidget {
  const _TarifTile({required this.article, required this.onEdit, required this.onOpen});

  final Json article;
  final VoidCallback onEdit;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final a = article;
    final m = a.margin;
    final mColor = m == null ? AppColors.muted : (m < 0 ? AppColors.danger : (m < 10 ? AppColors.warning : AppColors.success));
    return InkWell(
      onTap: onEdit,
      onLongPress: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(children: [
          ItemThumb(path: a['image'], label: a.articleName, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.articleName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Row(children: [
                _mini(tr('Achat'), a.prixAchat),
                _mini(tr('Vente'), a.prixVente, bold: true),
                if (a.prixPromo > 0) _mini(tr('Promo'), a.prixPromo, color: AppColors.primary),
              ]),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Badge2(m == null ? tr('Marge —') : percent(m), color: mColor),
            if (!a.isActive) Padding(padding: const EdgeInsets.only(top: 4), child: Badge2(tr('Inactif'))),
          ]),
          IconButton(icon: const Icon(Icons.edit_outlined, size: 20), tooltip: tr('Modifier'), onPressed: onEdit),
        ]),
      ),
    );
  }

  Widget _mini(String label, double v, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        Text(v > 0 ? money(v) : '—',
            style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: v > 0 ? (color ?? AppColors.ink) : AppColors.muted)),
      ]),
    );
  }
}

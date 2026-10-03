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
      appBar: darkAppBar('Tarifs de vente', actions: [
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
            PopupMenuItem(value: 'vente_asc', child: Text('Prix de vente croissant')),
            PopupMenuItem(value: 'vente_desc', child: Text('Prix de vente décroissant')),
            PopupMenuItem(value: 'marge_asc', child: Text('Marge croissante')),
            PopupMenuItem(value: 'marge_desc', child: Text('Marge décroissante')),
          ],
        ),
      ]),
      body: PagedList<Json>(
        key: _list,
        searchHint: 'Code-barres, nom FR ou عربي',
        onScan: _scan,
        emptyIcon: Icons.sell_outlined,
        emptyTitle: 'Aucun article',
        filters: FilterChips<String>(
          options: const [
            (null, 'Tous'),
            ('tarife', 'Tarifés'),
            ('a_tarifer', 'À tarifer'),
            ('promo', 'En promo'),
            ('marge_faible', 'Marge faible'),
            ('perte', 'À perte'),
            ('sans_achat', 'Sans prix d’achat'),
          ],
          value: _statut,
          onChanged: _setStatut,
        ),
        headerBuilder: (context, raw) {
          final s = raw.obj('stats');
          if (s == null) return null;
          return StatsRow(padding: const EdgeInsets.fromLTRB(16, 12, 16, 10), children: [
            MiniStat(label: 'Tarifés', value: qty(s['tarifes']), color: AppColors.success, onTap: () => _setStatut('tarife'), selected: _statut == 'tarife'),
            MiniStat(label: 'À tarifer', value: qty(s['a_tarifer']), color: AppColors.warning, onTap: () => _setStatut('a_tarifer'), selected: _statut == 'a_tarifer'),
            MiniStat(label: 'À perte', value: qty(s['perte']), color: AppColors.danger, onTap: () => _setStatut('perte'), selected: _statut == 'perte'),
            MiniStat(label: 'Marge moy.', value: s['marge_moyenne'] == null ? '—' : percent(s['marge_moyenne'])),
          ]);
        },
        fetch: (page, q) => api.page('tarifs', (j) => j, page: page, query: {'q': q, 'statut': _statut, 'sort': _sort}),
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
                _mini('Achat', a.prixAchat),
                _mini('Vente', a.prixVente, bold: true),
                if (a.prixPromo > 0) _mini('Promo', a.prixPromo, color: AppColors.primary),
              ]),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Badge2(m == null ? 'Marge —' : percent(m), color: mColor),
            if (!a.isActive) const Padding(padding: EdgeInsets.only(top: 4), child: Badge2('Inactif')),
          ]),
          IconButton(icon: const Icon(Icons.edit_outlined, size: 20), tooltip: 'Modifier', onPressed: onEdit),
        ]),
      ),
    );
  }

  Widget _mini(String label, double v, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        Text(v > 0 ? money(v) : '—',
            style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: v > 0 ? (color ?? AppColors.ink) : AppColors.muted)),
      ]),
    );
  }
}

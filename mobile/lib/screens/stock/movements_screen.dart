import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/article.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';
import '../purchases/receipts_screens.dart';

String motifLabel(String m) => switch (m) {
      'achat' => tr('Achat'),
      'vente' => tr('Vente'),
      'retour' => tr('Retour'),
      'perte' => tr('Perte'),
      'don' => tr('Don'),
      'ajustement' => tr('Ajustement'),
      'inventaire' => tr('Inventaire'),
      '' => '—',
      _ => m[0].toUpperCase() + m.substring(1),
    };

/// Mouvements de stock (par défaut : entrées).
class MovementsScreen extends StatefulWidget {
  const MovementsScreen({super.key, this.type = 'entree'});

  final String? type;

  @override
  State<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends State<MovementsScreen> {
  final _list = GlobalKey<PagedListState<Json>>();
  late String? _type = widget.type;

  @override
  Widget build(BuildContext context) {
    final api = context.api;
    return Scaffold(
      appBar: darkAppBar(_type == 'entree' ? tr('Entrées de stock') : (_type == 'sortie' ? tr('Sorties de stock') : tr('Mouvements de stock'))),
      body: PagedList<Json>(
        key: _list,
        searchHint: tr('Article, code-barres, référence…'),
        emptyIcon: Icons.swap_vert,
        emptyTitle: tr('Aucun mouvement'),
        filters: FilterChips<String>(
          options: [('entree', tr('Entrées')), ('sortie', tr('Sorties')), (null, tr('Tous'))],
          value: _type,
          onChanged: (v) {
            setState(() => _type = v);
            _list.currentState?.reload();
          },
        ),
        fetch: (page, q) => api.page('m/mouvements', (j) => j, page: page, query: {'q': q, 'type': _type}),
        itemBuilder: (ctx, m, _) {
          final a = m.obj('article') ?? {};
          final entree = m.str('type_mouvement') == 'entree';
          final isReception = m.str('reference_type') == 'reception' && m.intOrNull('reference_id') != null;
          return ListTile(
            onTap: isReception ? () => ctx.push(ReceiptDetailScreen(receiptId: m.integer('reference_id'))) : null,
            leading: Stack(clipBehavior: Clip.none, children: [
              ItemThumb(path: a['image'], label: a.articleName, size: 44),
              PositionedDirectional(
                end: -4,
                bottom: -4,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: entree ? AppColors.success : AppColors.danger,
                  child: Icon(entree ? Icons.south_west : Icons.north_east, size: 12, color: Colors.white),
                ),
              ),
            ]),
            title: Text(a.articleName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              [
                dateTime(m['created_at']),
                motifLabel(m.str('motif')),
                ?m.obj('fournisseur')?.strOrNull('nom'),
                ?m.strOrNull('note'),
                if (m.obj('utilisateur') != null) tr('par {nom}', {'nom': m.obj('utilisateur')!.str('nom')}),
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5),
            ),
            trailing: Text(
              '${entree ? '+' : '−'} ${qty(m['quantite'])}',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: entree ? AppColors.success : AppColors.danger),
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/article.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';

enum SalesPeriod { today, week, month, all }

/// Ligne de vente réutilisable (tableau de bord, listes, historique client).
class SaleTile extends StatelessWidget {
  const SaleTile({super.key, required this.sale, this.onTap});

  final Json sale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final v = sale;
    final total = v.dbl('montant_total');
    final paye = v.dbl('montant_paye');
    final credit = total - paye > 0.009;
    final client = v.obj('client')?.strOrNull('nom');
    final facture = v.obj('facture')?.strOrNull('numero_facture');
    return ListTile(
      onTap: onTap,
      leading: IconSquare(credit ? Icons.schedule : Icons.receipt_long, color: credit ? AppColors.warning : AppColors.success),
      title: Text(client ?? 'Client de passage', maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        [
          dateTime(v['date_vente'] ?? v['created_at']),
          ?facture,
          paymentModeLabel(v.strOrNull('mode_paiement')),
          if (v.intOrNull('items_count') != null) '${v.integer('items_count')} art.',
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12.5),
      ),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(money(total), style: const TextStyle(fontWeight: FontWeight.w800)),
        if (credit) Text('Reste ${money(total - paye)}', style: const TextStyle(fontSize: 11.5, color: AppColors.warning, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Liste des ventes (filtres période, crédit).
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key, this.initialPeriod = SalesPeriod.all, this.clientId, this.clientName});

  final SalesPeriod initialPeriod;
  final int? clientId;
  final String? clientName;

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _list = GlobalKey<PagedListState<Json>>();
  late SalesPeriod _period = widget.initialPeriod;
  bool _credit = false;

  Map<String, dynamic> _range() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_period) {
      SalesPeriod.today => {'du': apiDate(today), 'au': apiDate(today)},
      SalesPeriod.week => {'du': apiDate(today.subtract(const Duration(days: 6))), 'au': apiDate(today)},
      SalesPeriod.month => {'du': apiDate(DateTime(now.year, now.month, 1)), 'au': apiDate(today)},
      SalesPeriod.all => {},
    };
  }

  @override
  Widget build(BuildContext context) {
    final api = context.api;
    return Scaffold(
      appBar: darkAppBar('Ventes', subtitle: widget.clientName),
      body: PagedList<Json>(
        key: _list,
        searchHint: 'N° de facture, client…',
        emptyIcon: Icons.receipt_long_outlined,
        emptyTitle: 'Aucune vente',
        emptyMessage: 'Aucune vente sur cette période.',
        filters: FilterChips<String>(
          options: const [('today', 'Aujourd’hui'), ('week', '7 jours'), ('month', 'Ce mois'), ('all', 'Tout'), ('credit', 'À crédit')],
          value: _credit ? 'credit' : _period.name,
          onChanged: (v) {
            setState(() {
              if (v == 'credit') {
                _credit = !_credit;
              } else {
                _credit = false;
                _period = SalesPeriod.values.byName(v!);
              }
            });
            _list.currentState?.reload();
          },
        ),
        headerBuilder: (context, raw) {
          final r = raw.obj('resume');
          if (r == null) return null;
          return StatsRow(children: [
            MiniStat(label: 'Ventes', value: qty(raw['total'])),
            MiniStat(label: 'Montant', value: moneyShort(r['montant'])),
            MiniStat(label: 'Encaissé', value: moneyShort(r['encaisse']), color: AppColors.success),
          ]);
        },
        fetch: (page, q) => api.page('m/ventes', (j) => j, page: page, query: {
          'q': q,
          ..._range(),
          if (_credit) 'credit': 1,
          'client_id': widget.clientId,
        }),
        itemBuilder: (ctx, v, _) => SaleTile(sale: v, onTap: () => ctx.push(SaleDetailScreen(saleId: v.integer('id')))),
      ),
    );
  }
}

/// Détail d'une vente (GET m/ventes/{id}).
class SaleDetailScreen extends StatelessWidget {
  const SaleDetailScreen({super.key, required this.saleId});

  final int saleId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: darkAppBar('Vente n° $saleId'),
      body: AsyncView<Json>(
        load: () async => (await context.api.get('m/ventes/$saleId') as Map).cast<String, dynamic>(),
        builder: (context, v, reload) {
          final items = v.list('items');
          final total = v.dbl('montant_total');
          final paye = v.dbl('montant_paye');
          final reste = total - paye;
          final facture = v.obj('facture');
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.circular(20)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        facture?.strOrNull('numero_facture') != null ? 'Facture ${facture!.str('numero_facture')}' : 'Vente',
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Badge2(reste > 0.009 ? 'Crédit' : 'Payée', color: reste > 0.009 ? const Color(0xFFFBBF24) : const Color(0xFF86EFAC)),
                  ]),
                  const SizedBox(height: 6),
                  Text(money(total), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(dateTime(v['date_vente'] ?? v['created_at']), style: const TextStyle(color: Colors.white60)),
                ]),
              ),
              const SizedBox(height: 14),
              SectionCard(title: 'Informations', icon: Icons.info_outline, children: [
                InfoRow('Client', v.obj('client')?.str('nom') ?? 'Client de passage'),
                InfoRow('Mode de paiement', paymentModeLabel(v.strOrNull('mode_paiement'))),
                InfoRow('Vendeur', v.obj('utilisateur')?.str('nom') ?? '—'),
                if (facture != null) InfoRow('Statut facture', facture.str('statut', '—')),
              ]),
              const SizedBox(height: 14),
              SectionCard(
                title: 'Articles (${items.length})',
                icon: Icons.shopping_basket_outlined,
                padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
                children: [
                  for (final (i, it) in items.indexed) ...[
                    if (i > 0) const Divider(height: 1, indent: 16),
                    _itemRow(context, it),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              SectionCard(children: [
                TotalLine('Total', money(total), bold: true),
                TotalLine('Payé', money(paye), color: AppColors.success),
                if (reste > 0.009) TotalLine('Reste (crédit)', money(reste), bold: true, color: AppColors.warning),
              ]),
            ]),
          );
        },
      ),
    );
  }

  Widget _itemRow(BuildContext context, Json it) {
    final a = it.obj('article') ?? {};
    final ar = a.articleNameAr;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        ItemThumb(path: a['image'], label: a.articleName, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.articleName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (ar != null) Align(alignment: Alignment.centerLeft, child: ArabicText(ar, maxLines: 1)),
            Text('${qty(it['quantite'], a.unit)} × ${money(it['prix_unitaire'])}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ]),
        ),
        Text(money(toNum(it['quantite']) * toNum(it['prix_unitaire'])), style: const TextStyle(fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/article.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';
import '../suppliers/suppliers_screens.dart';
import 'orders_screens.dart';
import 'receipt_form.dart';

/// Liste des bons de réception.
class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key, this.supplierId, this.supplierName});

  final int? supplierId;
  final String? supplierName;

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  final _list = GlobalKey<PagedListState<Json>>();
  bool _unpaid = false;

  @override
  Widget build(BuildContext context) {
    final api = context.api;
    return Scaffold(
      appBar: darkAppBar(tr('Bons de réception'), subtitle: widget.supplierName),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'receipt-add',
        onPressed: () async {
          await context.push(const ReceiptForm());
          _list.currentState?.reload();
        },
        icon: const Icon(Icons.add),
        label: Text(tr('Réception')),
      ),
      body: PagedList<Json>(
        key: _list,
        searchHint: tr('N° de bon, BL fournisseur…'),
        emptyIcon: Icons.move_to_inbox_outlined,
        emptyTitle: tr('Aucun bon de réception'),
        filters: FilterChips<bool>(
          options: [(false, tr('Tous')), (true, tr('Non soldés'))],
          value: _unpaid,
          onChanged: (v) {
            setState(() => _unpaid = v ?? false);
            _list.currentState?.reload();
          },
        ),
        headerBuilder: (context, raw) {
          final s = raw.obj('stats');
          if (s == null) return null;
          return StatsRow(children: [
            MiniStat(label: tr('Ce mois'), value: qty(s['mois_nombre'])),
            MiniStat(label: tr('Montant du mois'), value: moneyShort(s['mois_montant'])),
            MiniStat(label: tr('Crédit total'), value: moneyShort(s['credit_total']), color: AppColors.danger),
          ]);
        },
        fetch: (page, q) => api.page('achats/receptions', (j) => j,
            page: page, query: {'q': q, if (_unpaid) 'impaye': 1, 'fournisseur_id': widget.supplierId}),
        itemBuilder: (ctx, r, reload) {
          final reste = r.dbl('reste');
          return ListTile(
            leading: IconSquare(Icons.move_to_inbox_outlined, color: reste > 0 ? AppColors.warning : AppColors.success),
            title: Text(r.str('numero'), style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
              [
                r.obj('fournisseur')?.str('nom') ?? '—',
                date(r['date_reception']),
                if (r.obj('commande') != null) r.obj('commande')!.str('numero'),
              ].join(' · '),
              style: const TextStyle(fontSize: 12.5),
            ),
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(moneyShort(r['total']), style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(reste > 0 ? tr('Reste {montant}', {'montant': money(reste)}) : tr('Soldé'),
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: reste > 0 ? AppColors.warning : AppColors.success)),
            ]),
            onTap: () async {
              await ctx.push(ReceiptDetailScreen(receiptId: r.integer('id')));
              reload();
            },
          );
        },
      ),
    );
  }
}

/// Détail d'un bon de réception.
class ReceiptDetailScreen extends StatelessWidget {
  const ReceiptDetailScreen({super.key, required this.receiptId});

  final int receiptId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: darkAppBar(tr('Bon de réception')),
      body: AsyncView<Json>(
        load: () async => (await context.api.get('achats/receptions/$receiptId') as Map).cast<String, dynamic>(),
        builder: (context, r, reload) {
          final lignes = r.list('lignes');
          final reste = r.dbl('reste');
          final f = r.obj('fournisseur');
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.circular(20)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(r.str('numero'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800))),
                    Badge2(reste > 0 ? tr('Non soldé') : tr('Soldé'), color: reste > 0 ? const Color(0xFFFBBF24) : const Color(0xFF86EFAC)),
                  ]),
                  const SizedBox(height: 4),
                  Text(f?.str('nom') ?? '—', style: const TextStyle(color: Colors.white70, fontSize: 15)),
                  const SizedBox(height: 12),
                  Text(money(r['total']), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                ]),
              ),
              if (reste > 0 && f != null) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    if (await paySupplier(context, f, reception: r)) reload();
                  },
                  icon: const Icon(Icons.payments_outlined),
                  label: Text(tr('Régler le reste ({montant})', {'montant': money(reste)})),
                ),
              ],
              const SizedBox(height: 14),
              SectionCard(title: tr('Informations'), icon: Icons.info_outline, children: [
                InfoRow(tr('Date de réception'), date(r['date_reception'])),
                InfoRow(tr('BL fournisseur'), r.str('reference_fournisseur')),
                if (r.obj('commande') != null)
                  InfoRow(tr('Bon de commande'), '',
                      valueWidget: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: InkWell(
                          onTap: () => context.push(OrderDetailScreen(orderId: r.obj('commande')!.integer('id'))),
                          child: Text(r.obj('commande')!.str('numero'),
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                        ),
                      )),
                InfoRow(tr('Reçu par'), r.obj('utilisateur')?.str('nom') ?? ''),
                if (r.strOrNull('note') != null) InfoRow(tr('Note'), r.str('note')),
              ]),
              const SizedBox(height: 14),
              SectionCard(
                title: tr('Articles reçus ({n})', {'n': lignes.length}),
                icon: Icons.inventory_2_outlined,
                padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
                children: [
                  for (final (i, l) in lignes.indexed) ...[
                    if (i > 0) const Divider(height: 1, indent: 16),
                    _line(l),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              SectionCard(children: [
                TotalLine(tr('Total'), money(r['total']), bold: true),
                TotalLine(r.strOrNull('mode_paiement') != null ? tr('Payé ({mode})', {'mode': paymentModeLabel(r.str('mode_paiement'))}) : tr('Payé'),
                    money(r['montant_paye']), color: AppColors.success),
                TotalLine(tr('Reste (crédit fournisseur)'), money(reste), bold: true, color: reste > 0 ? AppColors.warning : AppColors.success),
              ]),
            ]),
          );
        },
      ),
    );
  }

  Widget _line(Json l) {
    final a = l.obj('article') ?? {};
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        ItemThumb(path: a['image'], label: a.articleName, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.articleName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('${qty(l['quantite'], a.unit)} × ${money(l['prix_achat'])}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            if (l.dbl('prix_vente') > 0)
              Text(tr('Prix de vente : {prix}', {'prix': money(l['prix_vente'])}), style: const TextStyle(color: AppColors.info, fontSize: 12)),
          ]),
        ),
        Text(money(l.dbl('quantite') * l.dbl('prix_achat')), style: const TextStyle(fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

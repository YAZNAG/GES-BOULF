import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/article.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/delete_helper.dart';
import '../../widgets/paged_list.dart';
import 'order_form.dart';
import 'receipt_form.dart';
import 'receipts_screens.dart';

/// Liste des bons de commande.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, this.supplierId, this.supplierName});

  final int? supplierId;
  final String? supplierName;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _list = GlobalKey<PagedListState<Json>>();
  String? _statut;

  @override
  Widget build(BuildContext context) {
    final api = context.api;
    return Scaffold(
      appBar: darkAppBar(tr('Bons de commande'), subtitle: widget.supplierName),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'order-add',
        onPressed: () async {
          await context.push(const OrderForm());
          _list.currentState?.reload();
        },
        icon: const Icon(Icons.add),
        label: Text(tr('Commande')),
      ),
      body: PagedList<Json>(
        key: _list,
        searchHint: tr('N° de bon, fournisseur…'),
        emptyIcon: Icons.receipt_long_outlined,
        emptyTitle: tr('Aucun bon de commande'),
        filters: FilterChips<String>(
          options: [
            (null, tr('Tous')),
            ('brouillon', tr('Brouillons')),
            ('confirmee', tr('Confirmées')),
            ('partielle', tr('Partielles')),
            ('recue', tr('Reçues')),
            ('annulee', tr('Annulées')),
          ],
          value: _statut,
          onChanged: (v) {
            setState(() => _statut = v);
            _list.currentState?.reload();
          },
        ),
        headerBuilder: (context, raw) {
          final s = raw.obj('stats');
          if (s == null || s.isEmpty) return null;
          final open = ['brouillon', 'confirmee', 'partielle'];
          final n = open.fold<int>(0, (t, k) => t + (s.obj(k)?.integer('n') ?? 0));
          final m = open.fold<double>(0, (t, k) => t + (s.obj(k)?.dbl('montant') ?? 0));
          return StatsRow(children: [
            MiniStat(label: tr('En cours'), value: qty(n), color: AppColors.info),
            MiniStat(label: tr('Montant en cours'), value: moneyShort(m)),
            MiniStat(label: tr('Reçues'), value: qty(s.obj('recue')?.integer('n') ?? 0), color: AppColors.success),
          ]);
        },
        fetch: (page, q) => api.page('achats/commandes', (j) => j,
            page: page, query: {'q': q, 'statut': _statut, 'fournisseur_id': widget.supplierId}),
        itemBuilder: (ctx, o, reload) => ListTile(
          leading: IconSquare(Icons.receipt_long_outlined, color: orderStatusColor(o.str('statut'))),
          title: Row(children: [
            Expanded(child: Text(o.str('numero'), style: const TextStyle(fontWeight: FontWeight.w800))),
            Badge2(orderStatusLabel(o.str('statut')), color: orderStatusColor(o.str('statut'))),
          ]),
          subtitle: Text(
            [
              o.obj('fournisseur')?.str('nom') ?? '—',
              date(o['date_commande']),
              o.integer('lignes_count') > 1 ? tr('{n} lignes', {'n': o.integer('lignes_count')}) : tr('{n} ligne', {'n': o.integer('lignes_count')}),
            ].join(' · '),
            style: const TextStyle(fontSize: 12.5),
          ),
          trailing: Text(moneyShort(o['total']), style: const TextStyle(fontWeight: FontWeight.w800)),
          onTap: () async {
            await ctx.push(OrderDetailScreen(orderId: o.integer('id')));
            reload();
          },
        ),
      ),
    );
  }
}

/// Détail d'un bon de commande, avec actions selon le statut.
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _view = GlobalKey<AsyncViewState<Json>>();

  Future<void> _setStatus(String statut, String label) async {
    final api = context.api;
    final ok = await confirm(context, label, tr('Confirmer : {action} ?', {'action': label}), ok: label, danger: statut == 'annulee');
    if (!ok || !mounted) return;
    final res = await runBusy(context, () => api.post('achats/commandes/${widget.orderId}/statut', {'statut': statut}),
        success: tr('Statut mis à jour.'));
    if (res != null && mounted) _view.currentState?.reload();
  }

  Future<void> _delete(Json o) async {
    final api = context.api;
    final done = await deleteWithFallback(
      context,
      what: tr('le bon de commande {numero}', {'numero': o.str('numero')}),
      confirmMessage: tr('Le brouillon {numero} sera supprimé définitivement.', {'numero': o.str('numero')}),
      delete: () => api.delete('achats/commandes/${widget.orderId}'),
      success: tr('Bon de commande supprimé.'),
    );
    if (done && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: darkAppBar(tr('Bon de commande')),
      body: AsyncView<Json>(
        key: _view,
        load: () async => (await context.api.get('achats/commandes/${widget.orderId}') as Map).cast<String, dynamic>(),
        builder: (context, o, reload) {
          final statut = o.str('statut');
          final lignes = o.list('lignes');
          final receptions = o.list('receptions');
          final canReceive = statut == 'confirmee' || statut == 'partielle';
          // Le serveur n'autorise l'annulation que d'un brouillon ou d'une commande confirmée sans réception,
          // et le retour en brouillon que d'une commande confirmée sans réception.
          final nothingReceived = lignes.every((l) => l.dbl('quantite_recue') <= 0) && receptions.isEmpty;
          return Column(children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: reload,
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.circular(20)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(
                          child: Text(o.str('numero'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: orderStatusColor(statut), borderRadius: BorderRadius.circular(20)),
                          child: Text(orderStatusLabel(statut),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(o.obj('fournisseur')?.str('nom') ?? '—', style: const TextStyle(color: Colors.white70, fontSize: 15)),
                      const SizedBox(height: 12),
                      Text(money(o['total']), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(title: tr('Informations'), icon: Icons.info_outline, children: [
                    InfoRow(tr('Date de commande'), date(o['date_commande'])),
                    InfoRow(tr('Livraison prévue'), o['date_prevue'] == null ? '' : date(o['date_prevue'])),
                    if (o['date_reception'] != null) InfoRow(tr('Dernière réception'), date(o['date_reception'])),
                    InfoRow(tr('Créé par'), o.obj('utilisateur')?.str('nom') ?? ''),
                    if (o.strOrNull('note') != null) InfoRow(tr('Note'), o.str('note')),
                  ]),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: tr('Lignes ({n})', {'n': lignes.length}),
                    icon: Icons.list_alt,
                    padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
                    children: [
                      for (final (i, l) in lignes.indexed) ...[
                        if (i > 0) const Divider(height: 1, indent: 16),
                        _line(l),
                      ],
                    ],
                  ),
                  if (receptions.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SectionCard(
                      title: tr('Réceptions'),
                      icon: Icons.move_to_inbox_outlined,
                      padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
                      children: [
                        for (final r in receptions)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.move_to_inbox_outlined, color: AppColors.success),
                            title: Text(r.str('numero'), style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(date(r['date_reception'])),
                            trailing: Text(money(r['total']), style: const TextStyle(fontWeight: FontWeight.w700)),
                            onTap: () => context.push(ReceiptDetailScreen(receiptId: r.integer('id'))),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (statut == 'brouillon')
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final ok = await context.push<bool>(OrderForm(order: o));
                          if (ok == true) reload();
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(tr('Modifier')),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                        onPressed: () => _setStatus('annulee', tr('Annuler la commande')),
                        icon: const Icon(Icons.block),
                        label: Text(tr('Annuler')),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                        onPressed: () => _delete(o),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(tr('Supprimer')),
                      ),
                    ]),
                  if (statut == 'confirmee' && nothingReceived)
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      OutlinedButton.icon(
                        onPressed: () => _setStatus('brouillon', tr('Remettre en brouillon')),
                        icon: const Icon(Icons.undo),
                        label: Text(tr('Remettre en brouillon')),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                        onPressed: () => _setStatus('annulee', tr('Annuler la commande')),
                        icon: const Icon(Icons.block),
                        label: Text(tr('Annuler')),
                      ),
                    ]),
                  if (statut == 'confirmee' && nothingReceived)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(tr('Pour modifier les lignes, remettez d’abord la commande en brouillon.'),
                          style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                    ),
                ]),
              ),
            ),
            if (statut == 'brouillon')
              BottomAction(label: tr('Confirmer la commande'), icon: Icons.verified_outlined, onPressed: () => _setStatus('confirmee', tr('Confirmer'))),
            if (canReceive)
              BottomAction(
                label: tr('Réceptionner'),
                icon: Icons.move_to_inbox_outlined,
                onPressed: () async {
                  final ok = await context.push<bool>(ReceiptForm(order: o));
                  if (ok == true) reload();
                },
              ),
          ]);
        },
      ),
    );
  }

  Widget _line(Json l) {
    final a = l.obj('article') ?? {};
    final q = l.dbl('quantite');
    final r = l.dbl('quantite_recue');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        ItemThumb(path: a['image'], label: a.articleName, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.articleName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('${qty(q, a.unit)} × ${money(l['prix_unitaire'])}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            if (r > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: q <= 0 ? 0 : (r / q).clamp(0, 1).toDouble(),
                        minHeight: 5,
                        backgroundColor: AppColors.border,
                        color: r >= q ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(tr('Reçu {recu}/{total}', {'recu': qty(r), 'total': qty(q)}), style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                ]),
              ),
          ]),
        ),
        const SizedBox(width: 8),
        Text(money(q * l.dbl('prix_unitaire')), style: const TextStyle(fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

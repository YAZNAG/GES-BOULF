import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/article.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
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
      appBar: darkAppBar('Bons de commande', subtitle: widget.supplierName),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'order-add',
        onPressed: () async {
          await context.push(const OrderForm());
          _list.currentState?.reload();
        },
        icon: const Icon(Icons.add),
        label: const Text('Commande'),
      ),
      body: PagedList<Json>(
        key: _list,
        searchHint: 'N° de bon, fournisseur…',
        emptyIcon: Icons.receipt_long_outlined,
        emptyTitle: 'Aucun bon de commande',
        filters: FilterChips<String>(
          options: const [
            (null, 'Tous'),
            ('brouillon', 'Brouillons'),
            ('confirmee', 'Confirmées'),
            ('partielle', 'Partielles'),
            ('recue', 'Reçues'),
            ('annulee', 'Annulées'),
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
            MiniStat(label: 'En cours', value: qty(n), color: AppColors.info),
            MiniStat(label: 'Montant en cours', value: moneyShort(m)),
            MiniStat(label: 'Reçues', value: qty(s.obj('recue')?.integer('n') ?? 0), color: AppColors.success),
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
              '${o.integer('lignes_count')} ligne${o.integer('lignes_count') > 1 ? 's' : ''}',
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
    final ok = await confirm(context, label, 'Confirmer : $label ?', ok: label, danger: statut == 'annulee');
    if (!ok || !mounted) return;
    final res = await runBusy(context, () => api.post('achats/commandes/${widget.orderId}/statut', {'statut': statut}),
        success: 'Statut mis à jour.');
    if (res != null || mounted) _view.currentState?.reload();
  }

  Future<void> _delete() async {
    final api = context.api;
    final ok = await confirm(context, 'Supprimer le brouillon', 'Ce bon de commande sera supprimé définitivement.', ok: 'Supprimer', danger: true);
    if (!ok || !mounted) return;
    final res = await runBusy(context, () => api.delete('achats/commandes/${widget.orderId}'), success: 'Bon de commande supprimé.');
    if (res != null && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: darkAppBar('Bon de commande'),
      body: AsyncView<Json>(
        key: _view,
        load: () async => (await context.api.get('achats/commandes/${widget.orderId}') as Map).cast<String, dynamic>(),
        builder: (context, o, reload) {
          final statut = o.str('statut');
          final lignes = o.list('lignes');
          final receptions = o.list('receptions');
          final canReceive = statut == 'confirmee' || statut == 'partielle';
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
                  SectionCard(title: 'Informations', icon: Icons.info_outline, children: [
                    InfoRow('Date de commande', date(o['date_commande'])),
                    InfoRow('Livraison prévue', o['date_prevue'] == null ? '' : date(o['date_prevue'])),
                    if (o['date_reception'] != null) InfoRow('Dernière réception', date(o['date_reception'])),
                    InfoRow('Créé par', o.obj('utilisateur')?.str('nom') ?? ''),
                    if (o.strOrNull('note') != null) InfoRow('Note', o.str('note')),
                  ]),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Lignes (${lignes.length})',
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
                      title: 'Réceptions',
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
                        label: const Text('Modifier'),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                        onPressed: () => _setStatus('annulee', 'Annuler la commande'),
                        icon: const Icon(Icons.block),
                        label: const Text('Annuler'),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Supprimer'),
                      ),
                    ]),
                  if (canReceive)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                      onPressed: () => _setStatus('annulee', 'Annuler la commande'),
                      icon: const Icon(Icons.block),
                      label: const Text('Annuler le reliquat'),
                    ),
                  if (statut == 'annulee')
                    OutlinedButton.icon(
                      onPressed: () => _setStatus('brouillon', 'Remettre en brouillon'),
                      icon: const Icon(Icons.undo),
                      label: const Text('Remettre en brouillon'),
                    ),
                ]),
              ),
            ),
            if (statut == 'brouillon')
              BottomAction(label: 'Confirmer la commande', icon: Icons.verified_outlined, onPressed: () => _setStatus('confirmee', 'Confirmer')),
            if (canReceive)
              BottomAction(
                label: 'Réceptionner',
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
                  Text('Reçu ${qty(r)}/${qty(q)}', style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
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

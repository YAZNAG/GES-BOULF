import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';
import '../purchases/orders_screens.dart';
import '../purchases/receipts_screens.dart';
import '../sales/sales_screens.dart';
import 'users_screens.dart';

enum _Period { today, month, lastMonth, days30 }

/// Profil d'un utilisateur : identité + activité sur une période (GET m/utilisateurs/{id}/activite).
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.userId, this.self = false});

  final int userId;

  /// « Mon profil » (ouvert depuis l'écran Plus).
  final bool self;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _view = GlobalKey<AsyncViewState<Json>>();
  _Period _period = _Period.month;
  Json? _user;

  (DateTime, DateTime) _range() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_period) {
      _Period.today => (today, today),
      _Period.month => (DateTime(now.year, now.month, 1), today),
      _Period.lastMonth => (DateTime(now.year, now.month - 1, 1), DateTime(now.year, now.month, 0)),
      _Period.days30 => (today.subtract(const Duration(days: 29)), today),
    };
  }

  Future<Json> _load() async {
    final (du, au) = _range();
    final res = (await context.api.get('m/utilisateurs/${widget.userId}/activite', {'du': apiDate(du), 'au': apiDate(au)}) as Map)
        .cast<String, dynamic>();
    final u = res.obj('utilisateur');
    if (u != null && mounted) setState(() => _user = u);
    return res;
  }

  Future<void> _edit() async {
    final u = _user;
    if (u == null) return;
    final ok = await context.push<bool>(UserForm(user: u));
    if (ok == true) {
      _view.currentState?.reload();
      if (widget.self && mounted) {
        try {
          await context.session.refresh();
        } catch (_) {}
      }
    }
  }

  Future<void> _toggle() async {
    final u = _user;
    if (u == null) return;
    if (await toggleUserActive(context, u)) _view.currentState?.reload();
  }

  Future<void> _delete() async {
    final u = _user;
    if (u == null) return;
    final res = await deleteUser(context, u);
    if (!mounted || res == null) return;
    if (res == 'deleted') {
      Navigator.of(context).pop(true);
    } else {
      _view.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = context.session.canAny(const ['utilisateurs.manage', 'systeme.settings']);
    final me = context.session.user?.integer('id');
    final isMe = widget.self || widget.userId == me;
    final actif = _user?.flag('actif', true) ?? true;
    return Scaffold(
      appBar: darkAppBar(widget.self ? 'Mon profil' : 'Profil utilisateur', actions: [
        if (canEdit && _user != null) IconButton(tooltip: 'Modifier', icon: const Icon(Icons.edit_outlined), onPressed: _edit),
        if (canEdit && _user != null && !isMe)
          PopupMenuButton<String>(
            tooltip: 'Actions',
            onSelected: (v) => switch (v) {
              'toggle' => _toggle(),
              _ => _delete(),
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'toggle',
                child: ListTile(
                  leading: Icon(actif ? Icons.block : Icons.check_circle_outline),
                  title: Text(actif ? 'Désactiver le compte' : 'Activer le compte'),
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: AppColors.danger),
                  title: Text('Supprimer', style: TextStyle(color: AppColors.danger)),
                ),
              ),
            ],
          ),
      ]),
      body: Column(children: [
        Container(
          color: Colors.white,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: FilterChips<_Period>(
            options: const [
              (_Period.today, 'Aujourd’hui'),
              (_Period.month, 'Ce mois'),
              (_Period.lastMonth, 'Mois dernier'),
              (_Period.days30, '30 jours'),
            ],
            value: _period,
            onChanged: (v) {
              if (v == null || v == _period) return;
              setState(() => _period = v);
              _view.currentState?.reload();
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: AsyncView<Json>(
            key: _view,
            load: _load,
            builder: (context, d, reload) => RefreshIndicator(onRefresh: reload, child: _body(context, d)),
          ),
        ),
      ]),
    );
  }

  Widget _body(BuildContext context, Json d) {
    final u = d.obj('utilisateur') ?? {};
    final name = [u.str('prenom'), u.str('nom')].where((e) => e.isNotEmpty).join(' ');
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w.characters.first.toUpperCase()).join();
    final actif = u.flag('actif', true);
    final periode = d.obj('periode');
    final ventes = d.obj('ventes') ?? {};
    final receptions = d.obj('receptions') ?? {};
    final commandes = d.obj('commandes') ?? {};
    final dv = d.list('dernieres_ventes');
    final dr = d.list('dernieres_receptions');
    final dc = d.list('derniers_bons_commande');
    String plural(int n, String w) => '$n $w${n > 1 ? 's' : ''}';

    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: actif ? AppColors.primary : AppColors.muted,
            child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.isEmpty ? '—' : name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              Text(u.str('email'), overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 4, children: [
                Badge2(roleLabel(u.obj('role')?.str('nom') ?? ''), color: const Color(0xFFFCA5A5)),
                Badge2(actif ? 'Actif' : 'Désactivé', color: actif ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1)),
              ]),
            ]),
          ),
        ]),
      ),
      if (periode != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text('Période du ${date(periode['du'])} au ${date(periode['au'])}',
              textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
        ),
      const GroupLabel('Activité'),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.45,
        children: [
          StatTile(
            label: 'Ventes',
            value: moneyShort(ventes['montant']),
            hint: plural(ventes.integer('nombre'), 'vente'),
            icon: Icons.point_of_sale,
            color: AppColors.success,
          ),
          StatTile(
            label: 'Encaissé',
            value: moneyShort(ventes['encaisse']),
            hint: 'sur les ventes',
            icon: Icons.payments_outlined,
            color: AppColors.teal,
          ),
          StatTile(
            label: 'Bons de réception',
            value: moneyShort(receptions['montant']),
            hint: plural(receptions.integer('nombre'), 'bon'),
            icon: Icons.move_to_inbox_outlined,
            color: AppColors.info,
          ),
          StatTile(
            label: 'Bons de commande',
            value: moneyShort(commandes['montant']),
            hint: plural(commandes.integer('nombre'), 'bon'),
            icon: Icons.receipt_long_outlined,
            color: AppColors.violet,
          ),
          StatTile(
            label: 'Retours clients',
            value: moneyShort(d['retours_clients']),
            icon: Icons.assignment_return_outlined,
            color: AppColors.warning,
          ),
          StatTile(
            label: 'Charges',
            value: moneyShort(d['charges']),
            icon: Icons.receipt_outlined,
            color: AppColors.danger,
          ),
        ],
      ),
      const GroupLabel('Dernières ventes'),
      _listCard(dv.isEmpty, 'Aucune vente sur la période.', [
        for (final v in dv)
          ListTile(
            leading: IconSquare(
              v.dbl('montant_total') - v.dbl('montant_paye') > 0.009 ? Icons.schedule : Icons.receipt_long,
              color: v.dbl('montant_total') - v.dbl('montant_paye') > 0.009 ? AppColors.warning : AppColors.success,
            ),
            title: Text(v.obj('client')?.strOrNull('nom') ?? v.strOrNull('nom_passage') ?? 'Client de passage',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${dateTime(v['date_vente'])} · n° ${v.integer('id')}', style: const TextStyle(fontSize: 12.5)),
            trailing: Text(money(v['montant_total']), style: const TextStyle(fontWeight: FontWeight.w800)),
            onTap: () => context.push(SaleDetailScreen(saleId: v.integer('id'))),
          ),
      ]),
      const GroupLabel('Dernières réceptions'),
      _listCard(dr.isEmpty, 'Aucune réception sur la période.', [
        for (final r in dr)
          ListTile(
            leading: const IconSquare(Icons.move_to_inbox_outlined, color: AppColors.info),
            title: Text(r.str('numero'), style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${r.obj('fournisseur')?.str('nom') ?? '—'} · ${date(r['date_reception'])}',
                style: const TextStyle(fontSize: 12.5)),
            trailing: Text(money(r['total']), style: const TextStyle(fontWeight: FontWeight.w800)),
            onTap: () => context.push(ReceiptDetailScreen(receiptId: r.integer('id'))),
          ),
      ]),
      const GroupLabel('Derniers bons de commande'),
      _listCard(dc.isEmpty, 'Aucun bon de commande sur la période.', [
        for (final o in dc)
          ListTile(
            leading: IconSquare(Icons.receipt_long_outlined, color: orderStatusColor(o.str('statut'))),
            title: Row(children: [
              Expanded(child: Text(o.str('numero'), style: const TextStyle(fontWeight: FontWeight.w700))),
              Badge2(orderStatusLabel(o.str('statut')), color: orderStatusColor(o.str('statut'))),
            ]),
            subtitle: Text('${o.obj('fournisseur')?.str('nom') ?? '—'} · ${date(o['date_commande'])}',
                style: const TextStyle(fontSize: 12.5)),
            trailing: Text(money(o['total']), style: const TextStyle(fontWeight: FontWeight.w800)),
            onTap: () => context.push(OrderDetailScreen(orderId: o.integer('id'))),
          ),
      ]),
      const SizedBox(height: 16),
    ]);
  }

  Widget _listCard(bool empty, String emptyText, List<Widget> tiles) {
    if (empty) {
      return Card(
        child: Padding(padding: const EdgeInsets.all(18), child: Text(emptyText, style: const TextStyle(color: AppColors.muted))),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (final (i, t) in tiles.indexed) ...[
          if (i > 0) const Divider(height: 1, indent: 72),
          t,
        ],
      ]),
    );
  }
}

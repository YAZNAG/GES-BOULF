import 'charges/charges_screens.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';
import '../core/article.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../widgets/bar_chart.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import '../widgets/scanner.dart';
import 'clients/clients_screens.dart';
import 'home_shell.dart';
import 'login_screen.dart';
import 'products/product_detail_screen.dart';
import 'purchases/order_form.dart';
import 'purchases/receipt_form.dart';
import 'sales/sales_screens.dart';
import 'stock/stock_screen.dart';
import 'suppliers/suppliers_screens.dart';
import 'tarifs/tarifs_screen.dart';
import '../widgets/unknown_product.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onOpenTab, this.viewKey});

  final void Function(HomeTab tab) onOpenTab;

  /// Permet au shell de rafraîchir le tableau de bord au retour sur l'onglet.
  final GlobalKey<AsyncViewState<Json>>? viewKey;

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12 ? tr('Bonjour') : (h < 18 ? tr('Bon après-midi') : tr('Bonsoir'));
  }

  Future<void> _scanProduct(BuildContext context) async {
    final code = await ScannerPage.scan(context, title: tr('Rechercher un article'));
    if (code == null || !context.mounted) return;
    final api = context.api;
    var a = await runBusy<Json?>(context, () => lookupArticle(api, code));
    if (!context.mounted) return;
    a ??= await offerAddProduct(context, code);
    if (a != null && context.mounted) context.push(ProductDetailScreen(articleId: a.integer('id')));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.session;
    return Scaffold(
      body: AsyncView<Json>(
        key: viewKey,
        load: () async => (await context.api.get('m/dashboard') as Map).cast<String, dynamic>(),
        skeleton: const _DashboardSkeleton(),
        builder: (context, d, reload) {
          final jour = d.obj('jour') ?? {};
          final mois = d.obj('mois') ?? {};
          final stock = d.obj('stock') ?? {};
          final produits = d.obj('produits') ?? {};
          final sept = d.list('sept_jours');
          final top = d.list('top_produits');
          final last = d.list('dernieres_ventes');
          final weekTotal = sept.fold<double>(0, (t, e) => t + e.dbl('montant'));
          final reste = jour.dbl('montant') - jour.dbl('encaisse');

          return RefreshIndicator(
            onRefresh: reload,
            color: AppColors.primary,
            child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 20, 24),
                  decoration: const BoxDecoration(
                    gradient: AppColors.headerGradient,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const BrandLogo(size: 34),
                      const SizedBox(width: 10),
                      const Text('Boulfrik', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                        child: Row(children: [
                          const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 14),
                          const SizedBox(width: 6),
                          Text(date(DateTime.now().toIso8601String()), style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 18),
                    Text(tr('{salut}, {nom}', {'salut': _greeting(), 'nom': s.firstName.isNotEmpty ? s.firstName : s.lastName}),
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(s.roleLabel, style: const TextStyle(color: Colors.white60)),
                    const SizedBox(height: 18),
                    // Carte « Ventes du jour ».
                    Material(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => context.push(const SalesScreen(initialPeriod: SalesPeriod.today)),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text(tr('Ventes du jour'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                                child: Text(_ventes(jour.integer('ventes')),
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(money(jour['montant']),
                                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                            ),
                            const SizedBox(height: 10),
                            Row(children: [
                              _HeaderFigure(label: tr('Encaissé'), value: money(jour['encaisse']), color: const Color(0xFF86EFAC)),
                              const SizedBox(width: 16),
                              _HeaderFigure(
                                label: tr('À crédit'),
                                value: money(reste > 0 ? reste : 0),
                                color: reste > 0 ? const Color(0xFFFCA5A5) : Colors.white70,
                              ),
                            ]),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                sliver: SliverList.list(children: [
                  // Actions rapides.
                  Row(children: [
                    _QuickAction(
                      icon: Icons.point_of_sale,
                      label: tr('Nouvelle\nvente'),
                      color: AppColors.primary,
                      onTap: () => onOpenTab(HomeTab.caisse),
                    ),
                    _QuickAction(
                      icon: Icons.qr_code_scanner,
                      label: tr('Scanner\nun article'),
                      color: AppColors.ink,
                      onTap: () => _scanProduct(context),
                    ),
                    _QuickAction(
                      icon: Icons.move_to_inbox_outlined,
                      label: tr('Bon de\nréception'),
                      color: AppColors.success,
                      onTap: () => context.push(const ReceiptForm()),
                    ),
                    _QuickAction(
                      icon: Icons.receipt_long_outlined,
                      label: tr('Bon de\ncommande'),
                      color: AppColors.info,
                      onTap: () => context.push(const OrderForm()),
                    ),
                  ]),
                  GroupLabel(tr('Indicateurs')),
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
                        label: tr('Ventes du mois'),
                        value: moneyShort(mois['montant']),
                        hint: _ventes(mois.integer('ventes')),
                        icon: Icons.trending_up,
                        color: AppColors.success,
                        onTap: () => context.push(const SalesScreen(initialPeriod: SalesPeriod.month)),
                      ),
                      StatTile(
                        label: tr('Crédit clients'),
                        value: moneyShort(d['credit_clients']),
                        icon: Icons.people_alt_outlined,
                        color: AppColors.violet,
                        onTap: () => context.push(const ClientsScreen(creditOnly: true)),
                      ),
                      StatTile(
                        label: tr('Crédit fournisseurs'),
                        value: moneyShort(d['credit_fournisseurs']),
                        icon: Icons.local_shipping_outlined,
                        color: AppColors.info,
                        onTap: () => context.push(const SuppliersScreen(creditOnly: true)),
                      ),
                      StatTile(
                        label: tr('Charges du mois'),
                        value: moneyShort(d['charges_mois']),
                        icon: Icons.receipt_long_outlined,
                        color: AppColors.danger,
                        onTap: () => context.push(const ChargesScreen()),
                      ),
                      StatTile(
                        label: tr('Ventes − charges'),
                        value: moneyShort(mois.dbl('montant') - d.dbl('charges_mois')),
                        hint: tr('ce mois'),
                        icon: Icons.account_balance_wallet_outlined,
                        color: mois.dbl('montant') - d.dbl('charges_mois') >= 0 ? AppColors.teal : AppColors.danger,
                        onTap: () => context.push(const ChargesScreen()),
                      ),
                      StatTile(
                        label: tr('À tarifer'),
                        value: qty(produits['a_tarifer']),
                        hint: tr('{actifs} actifs / {total}', {'actifs': qty(produits['actifs']), 'total': qty(produits['total'])}),
                        icon: Icons.sell_outlined,
                        color: AppColors.warning,
                        onTap: () => context.push(const TarifsScreen(initialStatut: 'a_tarifer')),
                      ),
                    ],
                  ),
                  GroupLabel(tr('Alertes stock')),
                  Row(children: [
                    Expanded(
                      child: _AlertCard(
                        icon: Icons.remove_shopping_cart_outlined,
                        color: AppColors.danger,
                        value: qty(stock['rupture']),
                        label: tr('En rupture'),
                        onTap: () => context.push(const StockScreen(initialStatut: 'rupture')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AlertCard(
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.warning,
                        value: qty(stock['sous_seuil']),
                        label: tr('Sous le seuil'),
                        onTap: () => context.push(const StockScreen(initialStatut: 'sous_seuil')),
                      ),
                    ),
                  ]),
                  if (sept.isNotEmpty) ...[
                    GroupLabel(tr('7 derniers jours')),
                    SectionCard(
                      title: moneyShort(weekTotal),
                      trailing: Badge2(tr('Chiffre d’affaires'), color: AppColors.primary),
                      children: [
                        BarChart(
                          values: [for (final e in sept) e.dbl('montant')],
                          labels: [for (final e in sept) _dayLabel(e)],
                        ),
                      ],
                    ),
                  ],
                  if (top.isNotEmpty) ...[
                    GroupLabel(tr('Top 5 du mois')),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(children: [
                        for (final (i, p) in top.take(5).indexed) ...[
                          if (i > 0) const Divider(height: 1, indent: 72),
                          ListTile(
                            leading: Stack(clipBehavior: Clip.none, children: [
                              ItemThumb(path: p['image'], label: p.articleName, size: 44),
                              PositionedDirectional(
                                start: -6,
                                top: -6,
                                child: CircleAvatar(
                                  radius: 10,
                                  backgroundColor: i == 0 ? AppColors.primary : AppColors.ink,
                                  child: Text('${i + 1}',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ]),
                            title: Text(p.articleName, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(tr('{qte} vendus', {'qte': qty(p['qte'])})),
                            trailing: Text(moneyShort(p['montant']), style: const TextStyle(fontWeight: FontWeight.w800)),
                            onTap: p.intOrNull('id') == null
                                ? null
                                : () => context.push(ProductDetailScreen(articleId: p.integer('id'))),
                          ),
                        ],
                      ]),
                    ),
                  ],
                  GroupLabel(
                    tr('Dernières ventes'),
                    trailing: TextButton(
                      onPressed: () => context.push(const SalesScreen()),
                      child: Text(tr('Tout voir')),
                    ),
                  ),
                  if (last.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(children: [
                          const Icon(Icons.receipt_outlined, color: AppColors.muted),
                          const SizedBox(width: 12),
                          Expanded(child: Text(tr('Aucune vente pour le moment.'), style: const TextStyle(color: AppColors.muted))),
                        ]),
                      ),
                    )
                  else
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(children: [
                        for (final (i, v) in last.indexed) ...[
                          if (i > 0) const Divider(height: 1, indent: 72),
                          SaleTile(sale: v, onTap: () => context.push(SaleDetailScreen(saleId: v.integer('id')))),
                        ],
                      ]),
                    ),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }

  static String _ventes(int n) => n > 1 ? tr('{n} ventes', {'n': n}) : tr('{n} vente', {'n': n});

  static String _dayLabel(Json e) {
    if (appLang.isAr) {
      final d = parseDate(e['date']);
      if (d != null) return DateFormat('EEE', appLang.dateLocale).format(d);
    }
    final j = e.str('jour');
    if (j.isNotEmpty) return j[0].toUpperCase() + j.substring(1);
    final d = parseDate(e['date']);
    return d == null ? '' : '${d.day}';
  }
}

class _HeaderFigure extends StatelessWidget {
  const _HeaderFigure({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Flexible(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: '$label  ', style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
              TextSpan(text: value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 12, offset: const Offset(0, 5))],
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.2)),
          ]),
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.icon, required this.color, required this.value, required this.label, required this.onTap});

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(border: BorderDirectional(start: BorderSide(color: color, width: 4))),
          child: Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
                Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        height: 290,
        decoration: const BoxDecoration(
          gradient: AppColors.headerGradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: Colors.white),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: List.generate(
              4,
              (_) => const Expanded(
                  child: Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: SkeletonBox(height: 56, radius: 18))))),
          const SizedBox(height: 24),
          const Row(children: [
            Expanded(child: SkeletonBox(height: 110, radius: 18)),
            SizedBox(width: 12),
            Expanded(child: SkeletonBox(height: 110, radius: 18)),
          ]),
          const SizedBox(height: 12),
          const Row(children: [
            Expanded(child: SkeletonBox(height: 110, radius: 18)),
            SizedBox(width: 12),
            Expanded(child: SkeletonBox(height: 110, radius: 18)),
          ]),
        ]),
      ),
    ]);
  }
}

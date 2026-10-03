import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/common.dart';
import 'about_screen.dart';
import 'admin/settings_screens.dart';
import 'admin/users_screens.dart';
import 'clients/clients_screens.dart';
import 'purchases/orders_screens.dart';
import 'purchases/receipts_screens.dart';
import 'sales/sales_screens.dart';
import 'stock/movements_screen.dart';
import 'stock/stock_screen.dart';
import 'suppliers/suppliers_screens.dart';
import 'tarifs/tarifs_screen.dart';

typedef _Module = (String title, String subtitle, IconData icon, Color color, Widget Function() page);

/// « Plus » : profil, modules, paramètres.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.session;
    final sections = <(String, List<_Module>)>[
      ('Ventes', [
        ('Ventes', 'Historique et détail des ventes', Icons.receipt_long, AppColors.success, () => const SalesScreen()),
        ('Tarifs de vente', 'Prix, marges, articles à tarifer', Icons.sell_outlined, AppColors.primary, () => const TarifsScreen()),
        ('Clients', 'Fiches et historique', Icons.people_alt_outlined, AppColors.violet, () => const ClientsScreen()),
        ('Crédit clients', 'Encaisser un règlement', Icons.account_balance_wallet_outlined, AppColors.warning,
            () => const ClientsScreen(creditOnly: true)),
      ]),
      ('Achats', [
        ('Fournisseurs', 'Coordonnées, relevés', Icons.local_shipping_outlined, AppColors.info, () => const SuppliersScreen()),
        ('Crédit fournisseurs', 'Régler un fournisseur', Icons.payments_outlined, AppColors.danger,
            () => const SuppliersScreen(creditOnly: true)),
        ('Bons de commande', 'Créer, confirmer, suivre', Icons.receipt_long_outlined, AppColors.info, () => const OrdersScreen()),
        ('Bons de réception', 'Entrées de marchandises', Icons.move_to_inbox_outlined, AppColors.success, () => const ReceiptsScreen()),
        ('Paiements fournisseurs', 'Historique des règlements', Icons.history, AppColors.violet, () => const SupplierPaymentsScreen()),
      ]),
      ('Stock', [
        ('Stock', 'Quantités, seuils, valeur', Icons.warehouse_outlined, AppColors.teal, () => const StockScreen()),
        ('Entrées de stock', 'Mouvements d’entrée', Icons.south_west, AppColors.success, () => const MovementsScreen()),
      ]),
      ('Administration', [
        if (s.canAny(const ['utilisateurs.view', 'utilisateurs.manage', 'systeme.settings']))
          ('Utilisateurs', 'Comptes et accès', Icons.manage_accounts_outlined, AppColors.ink, () => const UsersScreen()),
        ('Unités', 'Pièce, kg, litre…', Icons.straighten, AppColors.muted, () => const RefListScreen(config: RefConfig.unites)),
        ('Marques', 'Marques des articles', Icons.verified_outlined, AppColors.muted, () => const RefListScreen(config: RefConfig.marques)),
        ('À propos', 'Version, mises à jour', Icons.info_outline, AppColors.muted, () => const AboutScreen()),
      ]),
    ];

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 20),
            decoration: const BoxDecoration(
              gradient: AppColors.headerGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Plus', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 27,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      s.userName.isEmpty ? '?' : s.userName.trim().split(RegExp(r'\s+')).take(2).map((w) => w.characters.first.toUpperCase()).join(),
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.userName, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                      Text(s.userEmail, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(20)),
                        child: Text(s.roleLabel, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'Se déconnecter',
                    style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.1)),
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () async {
                      if (await confirm(context, 'Déconnexion', 'Voulez-vous vous déconnecter ?', ok: 'Se déconnecter', danger: true)) {
                        await s.logout();
                      }
                    },
                  ),
                ]),
              ),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          sliver: SliverList.list(children: [
            for (final (title, items) in sections)
              if (items.isNotEmpty) ...[
                GroupLabel(title),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 70),
                      ListTile(
                        leading: IconSquare(items[i].$3, color: items[i].$4),
                        title: Text(items[i].$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(items[i].$2, style: const TextStyle(fontSize: 12.5)),
                        trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                        onTap: () => context.push(items[i].$5()),
                      ),
                    ],
                  ]),
                ),
              ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.border)),
              onPressed: () async {
                if (await confirm(context, 'Déconnexion', 'Voulez-vous vous déconnecter ?', ok: 'Se déconnecter', danger: true)) {
                  await s.logout();
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Se déconnecter'),
            ),
          ]),
        ),
      ]),
    );
  }
}

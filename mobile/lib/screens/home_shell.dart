import 'package:flutter/material.dart';

import '../core/api.dart';
import '../widgets/common.dart';

import 'dashboard_screen.dart';
import 'more_screen.dart';
import 'pos/pos_screen.dart';
import 'products/products_screen.dart';

/// Onglets de la barre du bas.
enum HomeTab { accueil, caisse, produits, plus }

/// Navigation principale : Accueil · Caisse · Produits · Plus.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _visited = <int>{0};
  final _dashboard = GlobalKey<AsyncViewState<Json>>();

  void _open(HomeTab tab) {
    if (tab == HomeTab.accueil && _index != 0) _dashboard.currentState?.reload();
    setState(() {
      _index = tab.index;
      _visited.add(_index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardScreen(onOpenTab: _open, viewKey: _dashboard),
      const PosScreen(),
      const ProductsScreen(),
      const MoreScreen(),
    ];
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _open(HomeTab.accueil);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < pages.length; i++) _visited.contains(i) ? pages[i] : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => _open(HomeTab.values[i]),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'Accueil'),
            NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: 'Caisse'),
            NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Produits'),
            NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded), label: 'Plus'),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/theme.dart';
import '../widgets/common.dart';
import 'login_screen.dart';
import 'update.dart';

/// À propos : version installée, serveur, recherche de mise à jour.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.session;
    return Scaffold(
      appBar: darkAppBar('À propos'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.circular(22)),
          child: Column(children: [
            const BrandLogo(size: 72),
            const SizedBox(height: 14),
            const Text('Boulfrik', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
            const Text('Gestion du supermarché', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (_, snap) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  snap.hasData ? 'Version ${snap.data!.version} (build ${snap.data!.buildNumber})' : 'Version …',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            ListTile(
              leading: const IconSquare(Icons.system_update_outlined, color: AppColors.success),
              title: const Text('Rechercher une mise à jour', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => checkForUpdate(context),
            ),
            const Divider(height: 1, indent: 72),
            ListTile(
              leading: const IconSquare(Icons.dns_outlined, color: AppColors.info),
              title: const Text('Serveur', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(s.api.baseUrl),
            ),
            const Divider(height: 1, indent: 72),
            ListTile(
              leading: const IconSquare(Icons.person_outline, color: AppColors.violet),
              title: const Text('Connecté en tant que', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${s.userName} · ${s.roleLabel}'),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        const Text('© Boulfrik — application réalisée par Optizaworks.',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
      ]),
    );
  }
}

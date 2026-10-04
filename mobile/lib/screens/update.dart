import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Version publiée sur le serveur (GET app/version) comparée à la version installée.
class UpdateInfo {
  UpdateInfo({
    required this.version,
    required this.build,
    required this.minBuild,
    required this.apkUrl,
    required this.notes,
    required this.installedVersion,
    required this.installedBuild,
  });

  final String version;
  final int build;
  final int minBuild;
  final String apkUrl;
  final String notes;
  final String installedVersion;
  final int installedBuild;

  bool get available => build > installedBuild;
  bool get required => minBuild > installedBuild;
}

Future<UpdateInfo?> fetchUpdateInfo(ApiClient api) async {
  try {
    final info = await PackageInfo.fromPlatform();
    final res = await api.get('app/version');
    if (res is! Map) return null;
    final d = res.cast<String, dynamic>();
    final j = d.obj('data') ?? d;
    return UpdateInfo(
      version: j.str('version'),
      build: j.integer('build'),
      minBuild: j.integer('min_build'),
      apkUrl: api.imageUrl(j.strOrNull('apk_url')) ?? '',
      notes: j.str('notes'),
      installedVersion: info.version,
      installedBuild: int.tryParse(info.buildNumber) ?? 0,
    );
  } catch (_) {
    return null;
  }
}

/// Vérification manuelle (écran « À propos »).
Future<void> checkForUpdate(BuildContext context) async {
  final info = await runBusy(context, () async {
    final i = await fetchUpdateInfo(context.api);
    if (i == null) throw ApiException(tr('Impossible de vérifier les mises à jour. Vérifiez votre connexion.'));
    return i;
  });
  if (info == null || !context.mounted) return;
  if (!info.available) {
    showSuccess(context, tr('Vous avez la dernière version ({version}).', {'version': info.installedVersion}));
    return;
  }
  Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => UpdateScreen(info: info)));
}

/// Page « Mise à jour disponible » (bloquante si la version installée n'est plus acceptée).
class UpdateScreen extends StatelessWidget {
  const UpdateScreen({super.key, required this.info});

  final UpdateInfo info;

  Future<void> _download(BuildContext context) async {
    final uri = Uri.tryParse(info.apkUrl);
    if (uri == null || info.apkUrl.isEmpty) {
      showError(context, ApiException(tr('Lien de téléchargement indisponible.')));
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showError(context, ApiException(tr('Impossible d’ouvrir le lien de téléchargement.')));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !info.required,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.headerGradient),
          child: SafeArea(
            child: Column(children: [
              if (!info.required)
                Align(
                  alignment: AlignmentDirectional.topEnd,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                )
              else
                const SizedBox(height: 48),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(children: [
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(28), boxShadow: [
                        BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 10)),
                      ]),
                      child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 52),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      info.required ? tr('Mise à jour obligatoire') : tr('Mise à jour disponible'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('Version {version} (build {build}) · installée : {installee} ({ibuild})', {'version': info.version, 'build': info.build, 'installee': info.installedVersion, 'ibuild': info.installedBuild}),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr('Nouveautés'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                          info.notes.trim().isEmpty ? tr('Améliorations et corrections.') : info.notes.trim(),
                          style: const TextStyle(color: Colors.white70, height: 1.4),
                        ),
                        if (info.required) ...[
                          const SizedBox(height: 14),
                          Text(
                            tr('Cette version de l’application n’est plus prise en charge. Installez la mise à jour pour continuer.'),
                            style: const TextStyle(color: Color(0xFFFCA5A5), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ]),
                    ),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  FilledButton.icon(
                    onPressed: () => _download(context),
                    icon: const Icon(Icons.download_rounded),
                    label: Text(tr('Télécharger')),
                  ),
                  if (!info.required) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.white70),
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Text(tr('Plus tard')),
                    ),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

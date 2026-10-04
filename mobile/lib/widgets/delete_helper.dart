import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/theme.dart';
import 'common.dart';

/// Utilisations renvoyées par le serveur (`{libellé: nombre}`, ou `[]` si aucune).
Map<String, int> usagesOf(Object? raw) {
  if (raw is! Map) return const {};
  final out = <String, int>{};
  raw.forEach((k, v) {
    final n = v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    if (n > 0) out['$k'] = n;
  });
  return out;
}

/// Boîte « élément utilisé ailleurs » : message, liste des utilisations et, si possible, « Désactiver ».
/// Renvoie true si l'utilisateur a choisi « Désactiver ».
Future<bool> showInUseDialog(
  BuildContext context, {
  required String message,
  Map<String, int> usages = const {},
  bool canDeactivate = false,
  String title = 'Suppression impossible',
  String deactivateLabel = 'Désactiver',
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.link, color: AppColors.warning, size: 30),
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(message),
          if (usages.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final e in usages.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      const Icon(Icons.circle, size: 6, color: AppColors.muted),
                      const SizedBox(width: 8),
                      Expanded(child: Text(e.key)),
                      Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                  ),
              ]),
            ),
          ],
          if (canDeactivate) ...[
            const SizedBox(height: 12),
            const Text('Désactivé, il n’apparaîtra plus dans les listes de saisie mais son historique est conservé.',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(canDeactivate ? 'Annuler' : 'Fermer')),
        if (canDeactivate)
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning, minimumSize: const Size(64, 42)),
            onPressed: () => Navigator.pop(c, true),
            icon: const Icon(Icons.visibility_off_outlined, size: 18),
            label: Text(deactivateLabel),
          ),
      ],
    ),
  );
  return res ?? false;
}

/// Désactivation avec indicateur de chargement. Renvoie true si réussie.
Future<bool> runDeactivate(BuildContext context, Future<void> Function() deactivate, {String success = 'Désactivé.'}) async {
  final ok = await runBusy<bool>(context, () async {
    await deactivate();
    return true;
  }, success: success);
  return ok == true;
}

/// Suppression protégée : confirmation, appel `delete`, puis, si le serveur refuse (409, élément utilisé),
/// explication + bouton « Désactiver » quand `deactivate` est fourni.
/// `what` désigne l'élément (ex. « le client « Ahmed » »). Renvoie true si quelque chose a changé.
Future<bool> deleteWithFallback(
  BuildContext context, {
  required String what,
  required Future<void> Function() delete,
  Future<void> Function()? deactivate,
  String? confirmMessage,
  bool askConfirm = true,
  String success = 'Supprimé.',
  String deactivated = 'Désactivé.',
}) async {
  if (askConfirm) {
    final ok = await confirm(
      context,
      'Supprimer',
      confirmMessage ?? 'Supprimer $what ? Cette action est définitive.',
      ok: 'Supprimer',
      danger: true,
    );
    if (!ok || !context.mounted) return false;
  }

  ApiException? conflict;
  final done = await runBusy<bool>(context, () async {
    try {
      await delete();
      return true;
    } on ApiException catch (e) {
      if (e.isConflict) {
        conflict = e;
        return false;
      }
      rethrow;
    }
  });
  if (!context.mounted) return done == true;
  if (done == true) {
    showSuccess(context, success);
    return true;
  }
  final e = conflict;
  if (e == null) return false; // autre erreur : déjà affichée par runBusy.

  final canDeactivate = deactivate != null && e.data['desactivable'] != false;
  final choice = await showInUseDialog(
    context,
    message: e.message,
    usages: usagesOf(e.data['utilisations']),
    canDeactivate: canDeactivate,
  );
  if (!choice || !context.mounted) return false;
  return runDeactivate(context, deactivate!, success: deactivated);
}

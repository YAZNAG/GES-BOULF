import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/session.dart';
import '../core/theme.dart';

/// Accès à la session depuis l'arbre de widgets.
class SessionScope extends InheritedNotifier<Session> {
  const SessionScope({super.key, required Session session, required super.child}) : super(notifier: session);

  static Session of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SessionScope>()!.notifier!;
  static Session read(BuildContext context) => context.getInheritedWidgetOfExactType<SessionScope>()!.notifier!;
}

extension SessionContext on BuildContext {
  Session get session => SessionScope.of(this);
  ApiClient get api => SessionScope.read(this).api;
  bool can(String permission) => SessionScope.of(this).can(permission);
  Future<T?> push<T>(Widget page) => Navigator.of(this).push<T>(MaterialPageRoute(builder: (_) => page));
}

String errorMessage(Object error) => error is ApiException ? error.details : tr('Une erreur est survenue.');

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(errorMessage(error))),
      ]),
      backgroundColor: AppColors.danger,
      duration: const Duration(seconds: 5),
    ));
}

void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: AppColors.success,
    ));
}

void showInfo(BuildContext context, String message, {Color color = AppColors.ink}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 3)));
}

Future<bool> confirm(BuildContext context, String title, String message,
    {String? ok, bool danger = false}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annuler'))),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: danger ? AppColors.danger : AppColors.primary,
            minimumSize: const Size(64, 42),
          ),
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok ?? tr('Confirmer')),
        ),
      ],
    ),
  );
  return res ?? false;
}

/// Exécute une action réseau avec indicateur de chargement et message d'erreur.
Future<T?> runBusy<T>(BuildContext context, Future<T> Function() action, {String? success}) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(
        child: Card(child: Padding(padding: EdgeInsets.all(22), child: CircularProgressIndicator())),
      ),
    ),
  );
  try {
    final res = await action();
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      if (success != null) showSuccess(context, success);
    }
    return res;
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      showError(context, e);
    }
    return null;
  }
}

/// Barre d'application sombre en dégradé (comme l'en-tête du site).
PreferredSizeWidget darkAppBar(String title, {List<Widget>? actions, PreferredSizeWidget? bottom, String? subtitle}) {
  return AppBar(
    title: subtitle == null
        ? Text(title)
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title),
            Text(subtitle, style: const TextStyle(fontSize: 12.5, color: Colors.white70, fontWeight: FontWeight.w500)),
          ]),
    actions: actions,
    bottom: bottom,
    flexibleSpace: const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.headerGradient)),
  );
}

class Badge2 extends StatelessWidget {
  const Badge2(this.label, {super.key, this.color = AppColors.muted, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Statuts des bons de commande.
Color orderStatusColor(String s) => switch (s) {
      'brouillon' => AppColors.muted,
      'confirmee' => AppColors.info,
      'partielle' => AppColors.warning,
      'recue' => AppColors.success,
      'annulee' => AppColors.danger,
      _ => AppColors.muted,
    };

String orderStatusLabel(String s) => switch (s) {
      'brouillon' => tr('Brouillon'),
      'confirmee' => tr('Confirmée'),
      'partielle' => tr('Partielle'),
      'recue' => tr('Reçue'),
      'annulee' => tr('Annulée'),
      _ => s,
    };

/// Texte arabe affiché de droite à gauche (dans les deux langues de l'interface).
class ArabicText extends StatelessWidget {
  const ArabicText(this.text, {super.key, this.style, this.maxLines, this.textAlign});

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text(
        text,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        textAlign: textAlign,
        style: style ?? const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final msg = error is ApiException ? (error as ApiException).message : tr('Une erreur est survenue.');
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: tr('Chargement impossible'),
      message: msg,
      action: OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(tr('Réessayer'))),
    );
  }
}

/// Bloc gris animé (squelette de chargement).
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: const Color(0xFFE8EAF0), borderRadius: BorderRadius.circular(widget.radius)),
      ),
    );
  }
}

/// Liste de squelettes (chargement initial d'une liste).
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 8});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (_, i) => Container(
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          const SkeletonBox(width: 46, height: 46, radius: 12),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SkeletonBox(width: i.isEven ? 180 : 140),
              const SizedBox(height: 8),
              const SkeletonBox(width: 100, height: 11),
            ]),
          ),
          const SkeletonBox(width: 56),
        ]),
      ),
    );
  }
}

/// Charge une donnée unique avec états chargement / erreur / rechargement.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({super.key, required this.load, required this.builder, this.skeleton});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;
  final Widget? skeleton;

  @override
  State<AsyncView<T>> createState() => AsyncViewState<T>();
}

class AsyncViewState<T> extends State<AsyncView<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() {
      _loading = _data == null;
      _error = null;
    });
    try {
      final d = await widget.load();
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
        if (_data != null) showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return widget.skeleton ?? const Center(child: CircularProgressIndicator());
    if (_data == null) return ErrorState(error: _error ?? tr('Erreur'), onRetry: reload);
    return widget.builder(context, _data as T, reload);
  }
}

/// Carte de section avec titre.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, required this.children, this.trailing, this.padding, this.icon});

  final String? title;
  final List<Widget> children;
  final Widget? trailing;
  final EdgeInsets? padding;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final pad = padding ?? const EdgeInsets.fromLTRB(16, 14, 16, 14);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: pad,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (title != null)
            Padding(
              padding: EdgeInsets.only(bottom: 10, left: pad.left == 0 ? 16 : 0, right: pad.right == 0 ? 16 : 0),
              child: Row(children: [
                if (icon != null) ...[Icon(icon, size: 19, color: AppColors.primary), const SizedBox(width: 8)],
                Expanded(
                  child: Text(title!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.ink)),
                ),
                ?trailing,
              ]),
            ),
          ...children,
        ]),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.valueStyle, this.valueWidget});

  final String label;
  final String value;
  final TextStyle? valueStyle;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 2, child: Text(label, style: const TextStyle(color: AppColors.muted))),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: valueWidget ??
              Text(value.isEmpty ? '—' : value,
                  textAlign: TextAlign.end, style: valueStyle ?? const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

/// Indicateur chiffré (tableau de bord, synthèses).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
    this.onTap,
    this.hint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              if (onTap != null) const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 2),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
              if (hint != null)
                Text(hint!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Petite pastille de statistique (en-têtes de listes).
class MiniStat extends StatelessWidget {
  const MiniStat({super.key, required this.label, required this.value, this.color = AppColors.ink, this.onTap, this.selected = false});

  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.10) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? color : AppColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            ),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ]),
        ),
      ),
    );
  }
}

/// Rangée de MiniStat de largeur égale.
class StatsRow extends StatelessWidget {
  const StatsRow({super.key, required this.children, this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 4)});

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: children[i]),
        ],
      ]),
    );
  }
}

/// Vignette d'image (chemin relatif « /storage/… » ou URL), ou initiales.
class ItemThumb extends StatelessWidget {
  const ItemThumb({super.key, this.path, required this.label, this.size = 46, this.color, this.icon});

  final Object? path;
  final String label;
  final double size;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    final words = label.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty && RegExp(r'[A-Za-zÀ-ÿ0-9؀-ۿ]').hasMatch(w));
    final initials = words.isEmpty ? '?' : words.take(2).map((w) => w.characters.first.toUpperCase()).join();
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(size * 0.26)),
      child: icon != null
          ? Icon(icon, color: c, size: size * 0.48)
          : Text(initials, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: size * 0.32)),
    );
    final url = context.api.imageUrl(path);
    if (url == null) return fallback;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.26),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        cacheWidth: (size * 3).round(),
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

/// Bouton principal fixé en bas d'écran (formulaires).
class BottomAction extends StatelessWidget {
  const BottomAction({super.key, required this.label, required this.onPressed, this.icon, this.busy = false, this.leading});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.border))),
        child: Row(children: [
          if (leading != null) ...[Expanded(child: leading!), const SizedBox(width: 12)],
          Expanded(
            child: FilledButton.icon(
              onPressed: busy ? null : onPressed,
              icon: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(icon ?? Icons.check),
              label: Text(label),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Titre de groupe dans une liste.
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Row(children: [
          Expanded(
            child: Text(text.toUpperCase(),
                style: const TextStyle(fontSize: 12, letterSpacing: 0.7, fontWeight: FontWeight.w800, color: AppColors.muted)),
          ),
          ?trailing,
        ]),
      );
}

/// Icône carrée colorée (listes de modules).
class IconSquare extends StatelessWidget {
  const IconSquare(this.icon, {super.key, this.color = AppColors.primary, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: size * 0.52),
      );
}

/// Ligne « libellé … montant » d'un récapitulatif.
class TotalLine extends StatelessWidget {
  const TotalLine(this.label, this.value, {super.key, this.bold = false, this.color, this.big = false});

  final String label;
  final String value;
  final bool bold;
  final bool big;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: big ? 20 : 14.5,
      fontWeight: bold || big ? FontWeight.w800 : FontWeight.w500,
      color: color ?? AppColors.ink,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: style.copyWith(color: bold || big ? style.color : AppColors.muted))),
        Text(value, style: style),
      ]),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/article.dart';
import '../core/format.dart';
import '../core/theme.dart';
import 'common.dart';
import 'paged_list.dart';
import 'scanner.dart';
import 'unknown_product.dart';

/// Recherche d'un article par code-barres (`GET articles/lookup?code=`). Null si introuvable.
Future<Json?> lookupArticle(ApiClient api, String code) async {
  try {
    final res = await api.get('articles/lookup', {'code': code.trim()});
    if (res is Map) {
      final j = res.cast<String, dynamic>();
      return j.obj('data') ?? (j.containsKey('id') ? j : null);
    }
    return null;
  } on ApiException catch (e) {
    if (e.status == 404) return null;
    rethrow;
  }
}

/// Sélection d'un élément distant (fournisseur, client…) dans une page plein écran.
Future<Json?> pickEntity(
  BuildContext context, {
  required String title,
  required Future<Paginated<Json>> Function(int page, String search) fetch,
  required String Function(Json) label,
  String Function(Json)? subtitle,
  Widget Function(Json)? leading,
  Widget Function(Json)? trailing,
  String searchHint = 'Rechercher…',
  Widget? top,
}) {
  return Navigator.of(context).push<Json>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (c) => Scaffold(
      appBar: darkAppBar(title),
      body: Column(children: [
        ?top,
        Expanded(
          child: PagedList<Json>(
            searchHint: searchHint,
            fetch: fetch,
            itemBuilder: (ctx, item, _) => ListTile(
              leading: leading?.call(item),
              title: Text(label(item), style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: subtitle == null ? null : Text(subtitle(item)),
              trailing: trailing?.call(item) ?? const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(ctx, item),
            ),
          ),
        ),
      ]),
    ),
  ));
}

Future<Json?> pickSupplier(BuildContext context) {
  final api = context.api;
  return pickEntity(
    context,
    title: 'Choisir un fournisseur',
    searchHint: 'Nom, téléphone…',
    fetch: (page, q) => api.page('fournisseurs', (j) => j, page: page, query: {'q': q}),
    label: (j) => j.str('nom'),
    subtitle: (j) => [j.strOrNull('ville'), j.strOrNull('telephone')].whereType<String>().join(' · '),
    leading: (j) => ItemThumb(label: j.str('nom'), color: AppColors.info, size: 40),
    trailing: (j) => j.dbl('solde') > 0
        ? Text(money(j['solde']), style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700))
        : const Icon(Icons.chevron_right),
  );
}

Future<Json?> pickClient(BuildContext context) {
  final api = context.api;
  return pickEntity(
    context,
    title: 'Choisir un client',
    searchHint: 'Nom ou téléphone',
    fetch: (page, q) => api.page('m/clients', (j) => j, page: page, query: {'q': q}),
    label: (j) => j.str('nom'),
    subtitle: (j) => [j.strOrNull('telephone'), j.str('type_client') == 'gros' ? 'Gros' : null].whereType<String>().join(' · '),
    leading: (j) => ItemThumb(label: j.str('nom'), color: AppColors.violet, size: 40),
    trailing: (j) => j.dbl('solde') > 0
        ? Text('Crédit ${money(j['solde'])}', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 12.5))
        : const Icon(Icons.chevron_right),
  );
}

/// Sélection d'un article : recherche (code-barres, FR, AR) ou scan.
Future<Json?> pickProduct(BuildContext context, {String title = 'Choisir un article'}) {
  final api = context.api;
  return Navigator.of(context).push<Json>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (c) => _ProductPicker(api: api, title: title),
  ));
}

class _ProductPicker extends StatelessWidget {
  const _ProductPicker({required this.api, required this.title});

  final ApiClient api;
  final String title;

  Future<void> _scan(BuildContext context) async {
    final code = await ScannerPage.scan(context);
    if (code == null || !context.mounted) return;
    try {
      final a = await lookupArticle(api, code);
      if (!context.mounted) return;
      final article = a ?? await offerAddProduct(context, code);
      if (article != null && context.mounted) Navigator.pop(context, article);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: darkAppBar(title),
      body: PagedList<Json>(
        searchHint: 'Code-barres, nom français ou arabe',
        onScan: () => _scan(context),
        fetch: (page, search) => api.page('articles', (j) => j, page: page, query: {'q': search, 'sort': 'nom'}),
        itemBuilder: (ctx, p, _) => ArticleTile(article: p, onTap: () => Navigator.pop(ctx, p)),
      ),
    );
  }
}

/// Ligne d'article (listes, recherches).
class ArticleTile extends StatelessWidget {
  const ArticleTile({super.key, required this.article, this.onTap, this.trailing, this.showStock = true});

  final Json article;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showStock;

  @override
  Widget build(BuildContext context) {
    final a = article;
    final stock = a.stockQty;
    final ar = a.articleNameAr;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          ItemThumb(path: a['image'], label: a.articleName, size: 50),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.articleName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (ar != null) Align(alignment: Alignment.centerLeft, child: ArabicText(ar, maxLines: 1)),
              const SizedBox(height: 3),
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (a.barcode.isNotEmpty)
                  Text(a.barcode, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontFeatures: [FontFeature.tabularFigures()])),
                if (!a.isActive) const Badge2('Inactif', color: AppColors.muted),
                if (!a.isPriced) const Badge2('À tarifer', color: AppColors.warning),
                if (showStock && stock != null)
                  Badge2(
                    stock <= 0 ? 'Rupture' : 'Stock ${qty(stock)}',
                    color: stock <= 0 ? AppColors.danger : (stock <= a.stockMin ? AppColors.warning : AppColors.success),
                  ),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          trailing ??
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(a.isPriced ? money(a.sellPrice) : '—',
                    style: TextStyle(fontWeight: FontWeight.w800, color: a.isPriced ? AppColors.ink : AppColors.muted)),
                if (a.hasPromo)
                  Text(money(a.prixVente),
                      style: const TextStyle(fontSize: 11.5, color: AppColors.muted, decoration: TextDecoration.lineThrough)),
              ]),
        ]),
      ),
    );
  }
}

/// Liste déroulante alimentée par l'API (rôles, unités…).
class RefDropdown extends StatefulWidget {
  const RefDropdown({
    super.key,
    required this.label,
    required this.path,
    required this.value,
    required this.onChanged,
    required this.itemLabel,
    this.query = const {},
    this.allowNull = false,
    this.nullLabel = 'Aucun',
    this.validator,
    this.prefixIcon,
  });

  final String label;
  final String path;
  final int? value;
  final ValueChanged<int?> onChanged;
  final String Function(Json) itemLabel;
  final Map<String, dynamic> query;
  final bool allowNull;
  final String nullLabel;
  final String? Function(int?)? validator;
  final IconData? prefixIcon;

  @override
  State<RefDropdown> createState() => _RefDropdownState();
}

class _RefDropdownState extends State<RefDropdown> {
  List<Json>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await context.api.get(widget.path, {'per_page': 200, ...widget.query});
      final items = res is List
          ? res.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
          : (res as Json).list('data');
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items == null) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
          suffixIcon: _error != null
              ? IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    setState(() => _error = null);
                    _load();
                  })
              : const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
        ),
        child: Text(_error != null ? 'Chargement impossible' : 'Chargement…', style: const TextStyle(color: AppColors.muted)),
      );
    }
    final ids = _items!.map((e) => e.integer('id')).toSet();
    final value = ids.contains(widget.value) ? widget.value : null;
    return DropdownButtonFormField<int?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: widget.label, prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon)),
      validator: widget.validator,
      items: [
        if (widget.allowNull) DropdownMenuItem<int?>(value: null, child: Text(widget.nullLabel)),
        for (final it in _items!)
          DropdownMenuItem<int?>(value: it.integer('id'), child: Text(widget.itemLabel(it), overflow: TextOverflow.ellipsis)),
      ],
      onChanged: widget.onChanged,
    );
  }
}

/// Champ de sélection d'une entité (ouvre un sélecteur).
class EntityField extends StatelessWidget {
  const EntityField({super.key, required this.label, required this.text, required this.onTap, this.icon, this.error, this.onClear, this.subtitle});

  final String label;
  final String? text;
  final String? subtitle;
  final VoidCallback? onTap;
  final IconData? icon;
  final String? error;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: error,
          enabled: onTap != null,
          prefixIcon: icon == null ? null : Icon(icon),
          suffixIcon: text != null && onClear != null
              ? IconButton(icon: const Icon(Icons.close), onPressed: onClear)
              : (onTap == null ? null : const Icon(Icons.arrow_drop_down)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(text ?? 'Choisir…',
              style: TextStyle(color: text == null ? AppColors.muted : AppColors.ink, fontWeight: text == null ? null : FontWeight.w600)),
          if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
      ),
    );
  }
}

/// Saisie d'une date (affichage jj/mm/aaaa, valeur AAAA-MM-JJ).
class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.value, required this.onChanged, this.allowClear = false});

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool allowClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.tryParse(value ?? '') ?? now,
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 5),
        );
        if (picked != null) onChanged(apiDate(picked));
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.event),
          suffixIcon: allowClear && value != null ? IconButton(icon: const Icon(Icons.close), onPressed: () => onChanged(null)) : null,
        ),
        child: Text(value == null ? 'Choisir…' : date(value)),
      ),
    );
  }
}

/// Puces de choix du mode de paiement.
class PaymentModePicker extends StatelessWidget {
  const PaymentModePicker({super.key, required this.value, required this.onChanged, this.modes});

  final String value;
  final ValueChanged<String> onChanged;
  final List<(String, String)>? modes;

  static IconData icon(String mode) => switch (mode) {
        'especes' => Icons.payments_outlined,
        'carte' => Icons.credit_card,
        'cheque' => Icons.receipt_outlined,
        'virement' => Icons.account_balance_outlined,
        'effet' => Icons.description_outlined,
        _ => Icons.payments_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final list = modes ?? paymentModes;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final (k, label) in list)
        ChoiceChip(
          avatar: Icon(icon(k), size: 18, color: value == k ? AppColors.primary : AppColors.muted),
          label: Text(label),
          selected: value == k,
          showCheckmark: false,
          selectedColor: AppColors.primary.withValues(alpha: 0.12),
          side: BorderSide(color: value == k ? AppColors.primary : AppColors.border),
          labelStyle: TextStyle(
            color: value == k ? AppColors.primary : AppColors.ink,
            fontWeight: value == k ? FontWeight.w700 : FontWeight.w500,
          ),
          onSelected: (_) => onChanged(k),
        ),
    ]);
  }
}

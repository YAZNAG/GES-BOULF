import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/article.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import 'common.dart';

/// Filtre de catalogue : famille, catégorie ou sous-catégorie (le niveau le plus fin choisi).
class CategoryFilter {
  // `label` reste un paramètre nommé public (compatibilité des appelants).
  // ignore: prefer_initializing_formals
  const CategoryFilter({this.familleId, this.categorieId, this.sousCategorieId, required String label, this.node}) : _label = label;

  final int? familleId;
  final int? categorieId;
  final int? sousCategorieId;
  final String _label;

  /// Élément choisi (famille, catégorie ou sous-catégorie) : permet d'afficher son nom
  /// dans la langue courante.
  final Json? node;

  /// Libellé affiché, dans la langue courante.
  String get label => node != null ? catName(node, _label) : tr(_label);

  bool get isEmpty => familleId == null && categorieId == null && sousCategorieId == null;

  /// Paramètres d'API (famille_id, categorie_id, sous_categorie_id).
  Map<String, dynamic> get query => {
        'famille_id': familleId,
        'categorie_id': categorieId,
        'sous_categorie_id': sousCategorieId,
      };
}

/// Feuille de choix : familles → catégories → sous-catégories.
Future<CategoryFilter?> pickCategoryFilter(BuildContext context) {
  return showModalBottomSheet<CategoryFilter>(
    context: context,
    isScrollControlled: true,
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => _CategorySheet(scroll: scroll),
    ),
  );
}

/// Puce « Catégorie » prête à placer dans une barre de filtres.
class CategoryFilterChip extends StatelessWidget {
  const CategoryFilterChip({super.key, required this.value, required this.onChanged});

  final CategoryFilter? value;
  final ValueChanged<CategoryFilter?> onChanged;

  @override
  Widget build(BuildContext context) {
    final on = value != null && !value!.isEmpty;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InputChip(
        avatar: Icon(Icons.category_outlined, size: 18, color: on ? AppColors.primary : AppColors.muted),
        label: Text(on ? value!.label : tr('Catégorie')),
        selected: on,
        showCheckmark: false,
        selectedColor: AppColors.primary.withValues(alpha: 0.12),
        side: BorderSide(color: on ? AppColors.primary : AppColors.border),
        onPressed: () async {
          final c = await pickCategoryFilter(context);
          if (c != null) onChanged(c.isEmpty ? null : c);
        },
        onDeleted: on ? () => onChanged(null) : null,
      ),
    );
  }
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({required this.scroll});

  final ScrollController scroll;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  List<Json>? _familles;
  Json? _famille;
  List<Json>? _categories;
  Json? _categorie;
  List<Json>? _sous;
  Object? _error;

  static String _name(Json j) => catName(j);
  static String? _second(Json j) => catSecondary(j);

  @override
  void initState() {
    super.initState();
    _loadFamilles();
  }

  Future<void> _loadFamilles() async {
    try {
      final r = await context.api.get('familles', {'per_page': 200}) as Json;
      if (mounted) setState(() => _familles = r.list('data'));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _openFamille(Json f) async {
    setState(() {
      _famille = f;
      _categories = null;
    });
    try {
      final r = await context.api.get('categories', {'per_page': 1000, 'famille_id': f.integer('id')}) as Json;
      if (mounted) setState(() => _categories = r.list('data').where((c) => c.integer('famille_id') == f.integer('id')).toList());
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _openCategorie(Json c) async {
    setState(() {
      _categorie = c;
      _sous = null;
    });
    try {
      final r = await context.api.get('sous_categories', {'per_page': 1000, 'categorie_id': c.integer('id')}) as Json;
      if (mounted) setState(() => _sous = r.list('data').where((s) => s.integer('categorie_id') == c.integer('id')).toList());
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _back() => setState(() {
        if (_categorie != null) {
          _categorie = null;
        } else {
          _famille = null;
        }
      });

  @override
  Widget build(BuildContext context) {
    final f = _famille;
    final c = _categorie;
    final List<Json>? list = c != null ? _sous : (f != null ? _categories : _familles);
    final title = c != null ? _name(c) : (f != null ? _name(f) : tr('Familles'));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
        child: Row(children: [
          if (f != null) IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back) else const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          if (f == null)
            TextButton(
              onPressed: () => Navigator.pop(context, const CategoryFilter(label: 'Toutes')),
              child: Text(tr('Tout afficher')),
            ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: list == null
            ? (_error != null
                ? ErrorState(
                    error: _error!,
                    onRetry: () {
                      setState(() => _error = null);
                      c != null ? _openCategorie(c) : (f != null ? _openFamille(f) : _loadFamilles());
                    })
                : const Center(child: CircularProgressIndicator()))
            : ListView(controller: widget.scroll, children: [
                // « Tout » au niveau courant.
                if (c != null)
                  ListTile(
                    leading: const IconSquare(Icons.select_all),
                    title: Text(tr('Toute la catégorie « {nom} »', {'nom': _name(c)}), style: const TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () => Navigator.pop(
                        context, CategoryFilter(familleId: f!.integer('id'), categorieId: c.integer('id'), label: _name(c), node: c)),
                  )
                else if (f != null)
                  ListTile(
                    leading: const IconSquare(Icons.select_all),
                    title: Text(tr('Toute la famille « {nom} »', {'nom': _name(f)}), style: const TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () => Navigator.pop(context, CategoryFilter(familleId: f.integer('id'), label: _name(f), node: f)),
                  ),
                for (final it in list)
                  ListTile(
                    leading: ItemThumb(path: it['image'], label: _name(it), size: 42),
                    title: Text(_name(it), style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: _second(it) == null
                        ? null
                        : Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Directionality(
                              textDirection: appLang.isAr ? TextDirection.ltr : TextDirection.rtl,
                              child: Text(_second(it)!, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                            ),
                          ),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(qty(it['articles_count']), style: const TextStyle(color: AppColors.muted)),
                      if (c == null) const Icon(Icons.chevron_right),
                    ]),
                    onTap: () {
                      if (f == null) {
                        _openFamille(it);
                      } else if (c == null) {
                        _openCategorie(it);
                      } else {
                        Navigator.pop(
                          context,
                          CategoryFilter(
                            familleId: f.integer('id'),
                            categorieId: c.integer('id'),
                            sousCategorieId: it.integer('id'),
                            label: _name(it),
                            node: it,
                          ),
                        );
                      }
                    },
                  ),
              ]),
      ),
    ]);
  }
}

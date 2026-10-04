import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/article.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/delete_helper.dart';
import '../../widgets/photo_field.dart';

/// Niveau de l'arborescence du catalogue : famille → catégorie → sous-catégorie.
class _Level {
  const _Level({
    required this.title,
    required this.singular,
    required this.path,
    required this.frKey,
    required this.arKey,
    this.parentKey,
    this.countLabel,
    required this.emptyTitle,
    required this.newTitle,
    required this.editTitle,
    required this.what,
    required this.deleted,
    this.openLabel,
  });

  final String title;
  final String singular;
  final String path;
  final String frKey;
  final String arKey;

  /// Champ du parent à envoyer (famille_id, categorie_id).
  final String? parentKey;
  final String Function(Json)? countLabel;

  // Libellés en français (affichés via tr()).
  final String emptyTitle;
  final String newTitle;
  final String editTitle;

  /// Désignation pour la suppression (placeholder {nom}).
  final String what;
  final String deleted;

  /// « Ouvrir les … » (niveau enfant), null au dernier niveau.
  final String? openLabel;

  static final familles = _Level(
    title: 'Familles',
    singular: 'famille',
    path: 'familles',
    frKey: 'nom_fr',
    arKey: 'nom_ar',
    countLabel: (j) => tr('{c} catégories · {p} produits', {'c': j.integer('categories_count'), 'p': j.integer('articles_count')}),
    emptyTitle: 'Aucune famille',
    newTitle: 'Nouvelle famille',
    editTitle: 'Modifier la famille',
    what: 'la famille « {nom} »',
    deleted: 'Famille supprimée.',
    openLabel: 'Ouvrir les catégories',
  );
  static final categories = _Level(
    title: 'Catégories',
    singular: 'catégorie',
    path: 'categories',
    frKey: 'name_fr',
    arKey: 'name_ar',
    parentKey: 'famille_id',
    countLabel: (j) =>
        tr('{s} sous-catégories · {p} produits', {'s': j.integer('sous_categories_count'), 'p': j.integer('articles_count')}),
    emptyTitle: 'Aucune catégorie',
    newTitle: 'Nouvelle catégorie',
    editTitle: 'Modifier la catégorie',
    what: 'la catégorie « {nom} »',
    deleted: 'Catégorie supprimée.',
    openLabel: 'Ouvrir les sous-catégories',
  );
  static final sousCategories = _Level(
    title: 'Sous-catégories',
    singular: 'sous-catégorie',
    path: 'sous_categories',
    frKey: 'name_fr',
    arKey: 'name_ar',
    parentKey: 'categorie_id',
    countLabel: (j) => tr('{p} produits', {'p': j.integer('articles_count')}),
    emptyTitle: 'Aucune sous-catégorie',
    newTitle: 'Nouvelle sous-catégorie',
    editTitle: 'Modifier la sous-catégorie',
    what: 'la sous-catégorie « {nom} »',
    deleted: 'Sous-catégorie supprimée.',
  );

  /// Nom français brut (formulaire).
  String nameOf(Json j) => j.str(frKey, j.str('nom'));

  /// Nom affiché dans la langue courante.
  String displayOf(Json j) => catName(j, nameOf(j));

  _Level? get child => identical(this, familles)
      ? categories
      : identical(this, categories)
          ? sousCategories
          : null;
}

/// Entrée du module : la liste des familles.
class CatalogAdminScreen extends StatelessWidget {
  const CatalogAdminScreen({super.key});

  @override
  Widget build(BuildContext context) => _LevelScreen(level: _Level.familles);
}

class _LevelScreen extends StatefulWidget {
  const _LevelScreen({required this.level, this.parent});

  final _Level level;
  final Json? parent;

  @override
  State<_LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<_LevelScreen> {
  List<Json>? _items;
  Object? _error;

  _Level get level => widget.level;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final query = <String, dynamic>{'per_page': 1000};
      if (level.parentKey != null && widget.parent != null) query[level.parentKey!] = widget.parent!.integer('id');
      final res = await context.api.get(level.path, query) as Json;
      var items = res.list('data');
      // Le serveur ne filtre pas toujours par parent : on assure le filtre ici.
      if (level.parentKey != null && widget.parent != null) {
        items = items.where((j) => j.integer(level.parentKey!) == widget.parent!.integer('id')).toList();
      }
      items.sort((a, b) => level.displayOf(a).toLowerCase().compareTo(level.displayOf(b).toLowerCase()));
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _edit([Json? item]) async {
    final saved = await context.push<bool>(_EntityForm(level: level, parent: widget.parent, item: item));
    if (saved == true) _load();
  }

  Future<void> _delete(Json item) async {
    final api = context.api;
    final done = await deleteWithFallback(
      context,
      what: tr(level.what, {'nom': level.displayOf(item)}),
      confirmMessage: tr('« {nom} » sera supprimée. Impossible si elle contient encore des éléments.', {'nom': level.displayOf(item)}),
      delete: () => api.delete('${level.path}/${item.integer('id')}'),
      success: tr(level.deleted),
    );
    if (done) _load();
  }

  @override
  Widget build(BuildContext context) {
    final parentName = widget.parent == null ? null : catName(widget.parent);
    return Scaffold(
      appBar: darkAppBar(tr(level.title), subtitle: parentName),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'cat-${level.path}',
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: Text(tr('Ajouter')),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _error != null
            ? ListView(children: [ErrorState(error: _error!, onRetry: _load)])
            : _items == null
                ? const SkeletonList()
                : _items!.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: 40),
                        EmptyState(
                          icon: Icons.category_outlined,
                          title: tr(level.emptyTitle),
                          message: tr('Ajoutez la première avec le bouton « Ajouter ».'),
                        ),
                      ])
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 230,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.82,
                        ),
                        itemCount: _items!.length,
                        itemBuilder: (_, i) => _card(_items![i]),
                      ),
      ),
    );
  }

  Widget _card(Json item) {
    final url = context.api.imageUrl(item['image']);
    final second = catSecondary(item);
    final child = level.child;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: child == null ? () => _edit(item) : () => context.push(_LevelScreen(level: child, parent: item)).then((_) => _load()),
        onLongPress: () => _actions(item),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              url != null
                  ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => const _NoImage())
                  : const _NoImage(),
              PositionedDirectional(
                top: 6,
                end: 6,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.92),
                  shape: const CircleBorder(),
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.more_vert, size: 20),
                    onPressed: () => _actions(item),
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(level.displayOf(item), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
              if (second != null && second.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Directionality(
                    textDirection: appLang.isAr ? TextDirection.ltr : TextDirection.rtl,
                    child: Text(second,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ),
                ),
              if (level.countLabel != null)
                Text(level.countLabel!(item), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _actions(Json item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(level.displayOf(item), style: const TextStyle(fontWeight: FontWeight.w800))),
          if (level.child != null)
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: Text(tr(level.openLabel ?? 'Ouvrir')),
              onTap: () => Navigator.pop(c, 'open'),
            ),
          ListTile(leading: const Icon(Icons.edit_outlined), title: Text(tr('Modifier')), onTap: () => Navigator.pop(c, 'edit')),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.danger),
            title: Text(tr('Supprimer'), style: const TextStyle(color: AppColors.danger)),
            onTap: () => Navigator.pop(c, 'delete'),
          ),
        ]),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'open':
        await context.push(_LevelScreen(level: level.child!, parent: item));
        _load();
      case 'edit':
        _edit(item);
      case 'delete':
        _delete(item);
    }
  }
}

class _NoImage extends StatelessWidget {
  const _NoImage();

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.surface,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, size: 40, color: AppColors.muted),
      );
}

/// Formulaire commun : nom FR, nom AR, photo. Le parent vient de l'écran précédent.
class _EntityForm extends StatefulWidget {
  const _EntityForm({required this.level, this.parent, this.item});

  final _Level level;
  final Json? parent;
  final Json? item;

  @override
  State<_EntityForm> createState() => _EntityFormState();
}

class _EntityFormState extends State<_EntityForm> {
  final _form = GlobalKey<FormState>();
  late final _fr = TextEditingController(text: widget.item == null ? '' : widget.level.nameOf(widget.item!));
  late final _ar = TextEditingController(text: widget.item?.str(widget.level.arKey) ?? '');
  File? _photo;
  bool _removePhoto = false;
  bool _saving = false;

  @override
  void dispose() {
    _fr.dispose();
    _ar.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final l = widget.level;
    final fr = _fr.text.trim();
    final ar = _ar.text.trim();
    final fields = <String, Object?>{
      l.frKey: fr,
      l.arKey: ar,
      if (l.frKey != 'nom_fr') 'nom': fr,
      if (l.parentKey != null) l.parentKey!: widget.item?.integer(l.parentKey!) ?? widget.parent?.integer('id'),
      if (widget.item != null) '_method': 'PUT',
    };
    try {
      final api = context.api;
      await api.multipart(widget.item == null ? l.path : '${l.path}/${widget.item!.integer('id')}', fields, file: _photo);
      if (widget.item != null && _photo == null && _removePhoto) {
        await api.delete('images/${l.path}/${widget.item!.integer('id')}');
      }
      if (!mounted) return;
      showSuccess(context, widget.item == null ? tr('Ajouté.') : tr('Modifié.'));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.level;
    final parentName = widget.parent == null ? null : catName(widget.parent);
    return Scaffold(
      appBar: darkAppBar(widget.item == null ? tr(l.newTitle) : tr(l.editTitle), subtitle: parentName),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Center(
            child: PhotoField(
              file: _photo,
              imagePath: _removePhoto ? null : widget.item?.strOrNull('image'),
              onChanged: (f) => setState(() => _photo = f),
              onRemove: widget.item == null ? null : () => setState(() => _removePhoto = true),
            ),
          ),
          if (_removePhoto && _photo == null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(tr('La photo sera supprimée à l’enregistrement.'),
                  textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _fr,
            autofocus: widget.item == null,
            textCapitalization: TextCapitalization.sentences,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: tr('Nom en français *')),
            validator: (v) => (v == null || v.trim().isEmpty) ? tr('Indiquez le nom.') : null,
          ),
          const SizedBox(height: 12),
          Directionality(
            textDirection: TextDirection.rtl,
            child: TextFormField(controller: _ar, decoration: const InputDecoration(labelText: 'الاسم بالعربية')),
          ),
        ]),
      ),
      bottomNavigationBar: BottomAction(label: tr('Enregistrer'), busy: _saving, onPressed: _save),
    );
  }
}

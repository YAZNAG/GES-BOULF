import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/article.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/delete_helper.dart';
import '../../widgets/paged_list.dart';
import '../../widgets/photo_field.dart';

/// Configuration d'une table de référence simple (unités, marques).
class RefConfig {
  const RefConfig({
    required this.title,
    required this.singular,
    required this.path,
    required this.icon,
    this.hasActive = false,
    this.nameMax = 100,
    this.imageType,
    required this.searchHint,
    required this.emptyTitle,
    required this.newTitle,
    required this.editTitle,
    required this.what,
    required this.deleted,
    required this.deactivatedMsg,
    required this.inactiveBadge,
    required this.activeLabel,
  });

  final String title;
  final String singular;
  final String path;
  final IconData icon;
  final bool hasActive;
  final int nameMax;

  /// Type pour `images/{type}/{id}` (photo modifiable), ou null.
  final String? imageType;

  // Libellés (en français, affichés via tr()).
  final String searchHint;
  final String emptyTitle;
  final String newTitle;
  final String editTitle;

  /// Désignation pour la suppression, avec le placeholder {nom}.
  final String what;
  final String deleted;
  final String deactivatedMsg;
  final String inactiveBadge;
  final String activeLabel;

  static const unites = RefConfig(
    title: 'Unités',
    singular: 'unité',
    path: 'unites',
    icon: Icons.straighten,
    hasActive: true,
    nameMax: 20,
    searchHint: 'Rechercher une unité…',
    emptyTitle: 'Aucune unité',
    newTitle: 'Nouvelle unité',
    editTitle: 'Modifier l’unité',
    what: 'l’unité « {nom} »',
    deleted: 'Unité supprimée.',
    deactivatedMsg: 'Unité désactivée.',
    inactiveBadge: 'Inactive',
    activeLabel: 'Active',
  );
  static const marques = RefConfig(
    title: 'Marques',
    singular: 'marque',
    path: 'marques',
    icon: Icons.verified_outlined,
    imageType: 'marques',
    searchHint: 'Rechercher une marque…',
    emptyTitle: 'Aucune marque',
    newTitle: 'Nouvelle marque',
    editTitle: 'Modifier la marque',
    what: 'la marque « {nom} »',
    deleted: 'Marque supprimée.',
    deactivatedMsg: 'Marque désactivée.',
    inactiveBadge: 'Inactive',
    activeLabel: 'Active',
  );
}

/// Liste CRUD d'une table de référence.
class RefListScreen extends StatefulWidget {
  const RefListScreen({super.key, required this.config});

  final RefConfig config;

  @override
  State<RefListScreen> createState() => _RefListScreenState();
}

class _RefListScreenState extends State<RefListScreen> {
  final _list = GlobalKey<PagedListState<Json>>();
  List<Json>? _cache;

  RefConfig get c => widget.config;

  void _refresh() {
    _cache = null;
    _list.currentState?.reload();
  }

  Future<void> _edit([Json? item]) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RefSheet(config: c, item: item),
    );
    if (ok == true) _refresh();
  }

  Future<void> _delete(Json item) async {
    final api = context.api;
    final id = item.integer('id');
    final done = await deleteWithFallback(
      context,
      what: tr(c.what, {'nom': item.str('nom')}),
      delete: () => api.delete('${c.path}/$id'),
      // Unités : on peut les désactiver si elles sont utilisées par des produits.
      deactivate: c.hasActive && item.flag('actif', true) ? () => api.put('${c.path}/$id', {'actif': false}) : null,
      success: tr(c.deleted),
      deactivated: tr(c.deactivatedMsg),
    );
    if (done) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.api;
    return Scaffold(
      appBar: darkAppBar(tr(c.title)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'ref-add-${c.path}',
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: Text(tr('Ajouter')),
      ),
      body: PagedList<Json>(
        key: _list,
        searchHint: tr(c.searchHint),
        emptyIcon: c.icon,
        emptyTitle: tr(c.emptyTitle),
        // L'API ne filtre pas ces tables : on charge tout puis on filtre localement.
        fetch: (page, q) async {
          final all = _cache ??= (await api.page(c.path, (j) => j, perPage: 1000)).items
            ..sort((a, b) => a.str('nom').toLowerCase().compareTo(b.str('nom').toLowerCase()));
          final needle = q.toLowerCase();
          final items = needle.isEmpty ? all : all.where((e) => e.str('nom').toLowerCase().contains(needle)).toList();
          return Paginated(items, 1, 1, items.length);
        },
        itemBuilder: (ctx, it, _) {
          final actif = it.flag('actif', true);
          return ListTile(
            leading: c.path == 'marques'
                ? ItemThumb(path: brandImagePath(it), label: it.str('nom'), color: AppColors.info, size: 40)
                : IconSquare(c.icon, color: actif ? AppColors.primary : AppColors.muted),
            title: Text(it.str('nom'), style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: it.strOrNull('description') == null ? null : Text(it.str('description'), maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (c.hasActive && !actif) Badge2(tr(c.inactiveBadge)),
              PopupMenuButton<String>(
                onSelected: (v) => v == 'edit' ? _edit(it) : _delete(it),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(tr('Modifier')))),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                      title: Text(tr('Supprimer'), style: const TextStyle(color: AppColors.danger)),
                    ),
                  ),
                ],
              ),
            ]),
            onTap: () => _edit(it),
          );
        },
      ),
    );
  }
}

class _RefSheet extends StatefulWidget {
  const _RefSheet({required this.config, this.item});

  final RefConfig config;
  final Json? item;

  @override
  State<_RefSheet> createState() => _RefSheetState();
}

class _RefSheetState extends State<_RefSheet> {
  late final _nom = TextEditingController(text: widget.item?.str('nom'));
  late final _desc = TextEditingController(text: widget.item?.str('description'));
  late bool _actif = widget.item?.flag('actif', true) ?? true;
  File? _photo;
  bool _removePhoto = false;
  bool _busy = false;
  Map<String, List<String>> _errors = {};

  String? get _imagePath => widget.item == null ? null : brandImagePath(widget.item!);

  @override
  void dispose() {
    _nom.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nom.text.trim().isEmpty) {
      setState(() => _errors = {'nom': [tr('Le nom est obligatoire.')]});
      return;
    }
    setState(() {
      _busy = true;
      _errors = {};
    });
    final c = widget.config;
    final body = {
      'nom': _nom.text.trim(),
      'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      if (c.hasActive) 'actif': _actif,
    };
    final api = context.api;
    try {
      final dynamic saved = widget.item == null
          ? await api.post(c.path, body)
          : await api.put('${c.path}/${widget.item!.integer('id')}', body);
      final id = widget.item?.integer('id') ?? (saved is Map ? saved.cast<String, dynamic>().intOrNull('id') : null);
      if (c.imageType != null && id != null) {
        if (_photo != null) {
          await api.multipart('images/${c.imageType}/$id', {}, file: _photo);
        } else if (_removePhoto && widget.item != null) {
          await api.delete('images/${c.imageType}/$id');
        }
      }
      if (!mounted) return;
      showSuccess(context, tr('Enregistré.'));
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errors = e.errors);
      if (e.errors.isEmpty) showError(context, e);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(widget.item == null ? tr(c.newTitle) : tr(c.editTitle),
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          if (c.imageType != null) ...[
            Center(
              child: PhotoField(
                size: 110,
                file: _photo,
                imagePath: _removePhoto ? null : _imagePath,
                onChanged: (f) => setState(() => _photo = f),
                onRemove: widget.item == null ? null : () => setState(() => _removePhoto = true),
              ),
            ),
            if (_removePhoto && _photo == null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(tr('La photo sera supprimée à l’enregistrement.'),
                    textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
              ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _nom,
            autofocus: widget.item == null,
            maxLength: c.nameMax,
            decoration: InputDecoration(labelText: tr('Nom *'), errorText: _errors['nom']?.first),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _desc,
            maxLines: 2,
            decoration: InputDecoration(labelText: tr('Description'), errorText: _errors['description']?.first),
          ),
          if (c.hasActive)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr(c.activeLabel)),
              value: _actif,
              activeThumbColor: AppColors.primary,
              onChanged: (v) => setState(() => _actif = v),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: Text(tr('Enregistrer')),
          ),
        ]),
      ),
    );
  }
}

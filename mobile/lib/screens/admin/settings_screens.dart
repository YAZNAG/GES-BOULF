import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';

/// Configuration d'une table de référence simple (unités, marques).
class RefConfig {
  const RefConfig({
    required this.title,
    required this.singular,
    required this.path,
    required this.icon,
    this.hasActive = false,
    this.nameMax = 100,
  });

  final String title;
  final String singular;
  final String path;
  final IconData icon;
  final bool hasActive;
  final int nameMax;

  static const unites = RefConfig(title: 'Unités', singular: 'unité', path: 'unites', icon: Icons.straighten, hasActive: true, nameMax: 20);
  static const marques = RefConfig(title: 'Marques', singular: 'marque', path: 'marques', icon: Icons.verified_outlined);
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
    final ok = await confirm(context, 'Supprimer', 'Supprimer « ${item.str('nom')} » ?', ok: 'Supprimer', danger: true);
    if (!ok || !mounted) return;
    final res = await runBusy(context, () async {
      await api.delete('${c.path}/${item.integer('id')}');
      return true;
    }, success: 'Supprimé.');
    if (res == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.api;
    return Scaffold(
      appBar: darkAppBar(c.title),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'ref-add-${c.path}',
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: Text('Ajouter'),
      ),
      body: PagedList<Json>(
        key: _list,
        searchHint: 'Rechercher une ${c.singular}…',
        emptyIcon: c.icon,
        emptyTitle: 'Aucune ${c.singular}',
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
                ? ItemThumb(path: it['image_url'] ?? it['image'], label: it.str('nom'), color: AppColors.info, size: 40)
                : IconSquare(c.icon, color: actif ? AppColors.primary : AppColors.muted),
            title: Text(it.str('nom'), style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: it.strOrNull('description') == null ? null : Text(it.str('description'), maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (c.hasActive && !actif) const Badge2('Inactive'),
              PopupMenuButton<String>(
                onSelected: (v) => v == 'edit' ? _edit(it) : _delete(it),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Modifier'))),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: AppColors.danger),
                      title: Text('Supprimer', style: TextStyle(color: AppColors.danger)),
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
  bool _busy = false;
  Map<String, List<String>> _errors = {};

  @override
  void dispose() {
    _nom.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nom.text.trim().isEmpty) {
      setState(() => _errors = {'nom': ['Le nom est obligatoire.']});
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
    try {
      if (widget.item == null) {
        await context.api.post(c.path, body);
      } else {
        await context.api.put('${c.path}/${widget.item!.integer('id')}', body);
      }
      if (!mounted) return;
      showSuccess(context, 'Enregistré.');
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
          Text(widget.item == null ? 'Nouvelle ${c.singular}' : 'Modifier la ${c.singular}',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(
            controller: _nom,
            autofocus: true,
            maxLength: c.nameMax,
            decoration: InputDecoration(labelText: 'Nom *', errorText: _errors['nom']?.first),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _desc,
            maxLines: 2,
            decoration: InputDecoration(labelText: 'Description', errorText: _errors['description']?.first),
          ),
          if (c.hasActive)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
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
            label: const Text('Enregistrer'),
          ),
        ]),
      ),
    );
  }
}

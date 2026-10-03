import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/article.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/pickers.dart';
import '../../widgets/scanner.dart';
import '../../widgets/unknown_product.dart';

String _statutLabel(String s) => switch (s) {
      'en_cours' => 'En cours',
      'valide' => 'Validé',
      'annule' => 'Annulé',
      _ => s,
    };

Color _statutColor(String s) => switch (s) {
      'en_cours' => AppColors.warning,
      'valide' => AppColors.success,
      _ => AppColors.muted,
    };

/// Liste des inventaires.
class InventoriesScreen extends StatefulWidget {
  const InventoriesScreen({super.key});

  @override
  State<InventoriesScreen> createState() => _InventoriesScreenState();
}

class _InventoriesScreenState extends State<InventoriesScreen> {
  List<Json>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final res = await context.api.get('inventaires', {'per_page': 100}) as Json;
      if (mounted) setState(() => _items = res.list('data'));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _create() async {
    final libelle = TextEditingController(text: 'Inventaire du ${date(DateTime.now().toIso8601String())}');
    int? famille;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Nouvel inventaire'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: libelle, decoration: const InputDecoration(labelText: 'Libellé')),
            const SizedBox(height: 12),
            RefDropdown(
              label: 'Périmètre',
              path: 'familles',
              value: famille,
              allowNull: true,
              nullLabel: 'Tout le magasin',
              onChanged: (v) => set(() => famille = v),
              itemLabel: (j) => j.str('nom_fr'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Commencer')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final inv = await runBusy(context, () => context.api.post('inventaires', {'libelle': libelle.text.trim(), 'famille_id': famille}));
    libelle.dispose();
    if (inv is Map && mounted) {
      await context.push(InventoryScreen(id: (inv['id'] as num).toInt()));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: darkAppBar('Inventaires'),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'inv-new',
        onPressed: _create,
        icon: const Icon(Icons.fact_check_outlined),
        label: const Text('Nouvel inventaire'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _error != null
            ? ListView(children: [ErrorState(error: _error!, onRetry: _load)])
            : _items == null
                ? const SkeletonList()
                : _items!.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 40),
                        EmptyState(
                          icon: Icons.fact_check_outlined,
                          title: 'Aucun inventaire',
                          message: 'Comptez votre stock réel : scannez les articles et l’application calcule les écarts.',
                        ),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                        itemCount: _items!.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final inv = _items![i];
                          final statut = inv.str('statut');
                          final perimetre = inv.obj('categorie')?.str('name_fr', inv.obj('categorie')!.str('nom')) ??
                              inv.obj('famille')?.str('nom_fr') ??
                              'Tout le magasin';
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            child: ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                              leading: IconSquare(Icons.fact_check_outlined, color: _statutColor(statut)),
                              title: Text(inv.str('libelle'), style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('${inv.str('numero')} · $perimetre · ${inv.integer('lignes_count')} article(s) compté(s)'),
                              trailing: Badge2(_statutLabel(statut), color: _statutColor(statut)),
                              onTap: () async {
                                await context.push(InventoryScreen(id: inv.integer('id')));
                                _load();
                              },
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

/// Comptage d'un inventaire : scan / recherche → quantité comptée → écarts → validation.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, required this.id});

  final int id;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  Json? _data;
  Object? _error;
  bool _ecartsOnly = false;

  Json get _inv => _data?.obj('inventaire') ?? {};
  bool get _ouvert => _inv.str('statut') == 'en_cours';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final res = await context.api.get('inventaires/${widget.id}', {if (_ecartsOnly) 'ecart': 1}) as Json;
      if (mounted) setState(() => _data = res);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _scan() async {
    final code = await ScannerPage.scan(context, title: 'Scanner l’article compté');
    if (code == null || !mounted) return;
    final a = await runBusy(context, () => lookupArticle(context.api, code));
    if (!mounted) return;
    final article = a ?? await offerAddProduct(context, code);
    if (article == null || !mounted) return;
    await _count(article);
  }

  Future<void> _search() async {
    final a = await pickProduct(context, title: 'Article compté');
    if (a != null && mounted) await _count(a);
  }

  /// Saisie de la quantité comptée pour un article (remplacer ou ajouter).
  Future<void> _count(Json article, {Json? ligne}) async {
    final deja = ligne?.dbl('quantite_comptee') ??
        _data?.list('lignes').where((l) => l.integer('article_id') == article.integer('id')).firstOrNull?.dbl('quantite_comptee');
    final ctrl = TextEditingController();
    var add = deja != null;
    final res = await showDialog<(double, bool)>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(article.articleName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (article.stockQty != null)
              Text('Stock théorique : ${qty(article.stockQty, article.unit)}', style: const TextStyle(color: AppColors.muted)),
            if (deja != null) ...[
              const SizedBox(height: 4),
              Text('Déjà compté : ${qty(deja, article.unit)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Ajouter')),
                  ButtonSegment(value: false, label: Text('Remplacer')),
                ],
                selected: {add},
                onSelectionChanged: (s) => set(() => add = s.first),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              decoration: InputDecoration(labelText: 'Quantité comptée', suffixText: article.unit),
              onSubmitted: (t) {
                final v = parseInput(t);
                if (v != null && v >= 0) Navigator.pop(c, (v, add));
              },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                final v = parseInput(ctrl.text);
                if (v != null && v >= 0) Navigator.pop(c, (v, add));
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (res == null || !mounted) return;
    final saved = await runBusy(
      context,
      () => context.api.post('inventaires/${widget.id}/compter',
          {'article_id': article.integer('id'), 'quantite': res.$1, 'mode': res.$2 ? 'add' : 'set'}),
    );
    if (saved != null) {
      _load();
      // Enchaîner les comptages : on repropose le scan.
      if (mounted) {
        final l = (saved as Map).cast<String, dynamic>();
        showSuccess(context, '${article.articleName} : ${qty(l['quantite_comptee'], article.unit)} (écart ${_signed(l.dbl('ecart'))})');
      }
    }
  }

  String _signed(double v) => v > 0 ? '+${qty(v)}' : qty(v);

  Future<void> _remove(Json ligne) async {
    final ok = await runBusy(context, () => context.api.delete('inventaires/${widget.id}/lignes/${ligne.integer('id')}'));
    if (ok != null) _load();
  }

  Future<void> _validate() async {
    final r = _data?.obj('resume') ?? {};
    final ok = await confirm(
      context,
      'Valider l’inventaire',
      '${r.integer('avec_ecart')} article(s) ont un écart (valeur ${money(r['ecart_valeur'])}).\n\n'
          'Le stock de chaque article compté sera aligné sur la quantité comptée. Les articles non comptés ne changent pas.',
      ok: 'Valider et corriger le stock',
    );
    if (!ok || !mounted) return;
    final res = await runBusy(context, () => context.api.post('inventaires/${widget.id}/valider'));
    if (res is Map && mounted) {
      showSuccess(context, 'Inventaire validé : ${res['corrections']} correction(s) de stock.');
      _load();
    }
  }

  Future<void> _cancel() async {
    final ok = await confirm(context, 'Annuler l’inventaire', 'Les comptages seront abandonnés, le stock ne change pas.',
        ok: 'Annuler l’inventaire', danger: true);
    if (!ok || !mounted) return;
    final res = await runBusy(context, () => context.api.post('inventaires/${widget.id}/annuler'));
    if (res != null && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final r = _data?.obj('resume') ?? {};
    final lignes = _data?.list('lignes') ?? [];
    final ecartValeur = r.dbl('ecart_valeur');
    return Scaffold(
      appBar: darkAppBar(_inv.str('libelle', 'Inventaire'), subtitle: _inv.strOrNull('numero'), actions: [
        if (_ouvert) IconButton(tooltip: 'Annuler l’inventaire', icon: const Icon(Icons.block), onPressed: _cancel),
      ]),
      body: _error != null
          ? ErrorState(error: _error!, onRetry: _load)
          : _data == null
              ? const SkeletonList()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 110), children: [
                    StatsRow(padding: EdgeInsets.zero, children: [
                      MiniStat(label: 'Comptés', value: qty(r['comptes'])),
                      MiniStat(label: 'Avec écart', value: qty(r['avec_ecart']), color: AppColors.warning),
                      MiniStat(
                        label: 'Écart (valeur)',
                        value: money(ecartValeur),
                        color: ecartValeur < 0 ? AppColors.danger : ecartValeur > 0 ? AppColors.success : AppColors.ink,
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      _ouvert
                          ? 'Périmètre : ${r.integer('perimetre')} articles actifs. Scannez ou cherchez chaque article et saisissez la quantité réellement présente.'
                          : 'Inventaire ${_statutLabel(_inv.str('statut')).toLowerCase()}${_inv.strOrNull('valide_le') != null ? ' le ${dateTime(_inv['valide_le'])}' : ''}.',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      FilterChip(
                        label: const Text('Écarts seulement'),
                        selected: _ecartsOnly,
                        onSelected: (v) {
                          setState(() => _ecartsOnly = v);
                          _load();
                        },
                      ),
                    ]),
                    const SizedBox(height: 6),
                    if (lignes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 30),
                        child: EmptyState(icon: Icons.qr_code_scanner, title: 'Aucun article compté', message: 'Commencez par scanner un article.'),
                      ),
                    for (final l in lignes) _line(l),
                  ]),
                ),
      bottomNavigationBar: _ouvert && _data != null
          ? SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.border))),
                child: Row(children: [
                  IconButton.filledTonal(tooltip: 'Rechercher', onPressed: _search, icon: const Icon(Icons.search)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(onPressed: _scan, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scanner')),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: lignes.isEmpty && r.integer('comptes') == 0 ? null : _validate, child: const Text('Valider')),
                ]),
              ),
            )
          : null,
    );
  }

  Widget _line(Json l) {
    final a = l.obj('article') ?? {};
    final ecart = l.dbl('ecart');
    final color = ecart < 0 ? AppColors.danger : ecart > 0 ? AppColors.success : AppColors.muted;
    final tile = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        ItemThumb(path: a['image'], label: a.articleName, size: 42),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.articleName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('Théorique ${qty(l['quantite_theorique'])} · compté ${qty(l['quantite_comptee'])} ${a.unit}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(ecart == 0 ? '0' : _signed(ecart), style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
          if (ecart != 0) Text(money(l['ecart_valeur']), style: TextStyle(color: color, fontSize: 11.5)),
        ]),
      ]),
    );
    if (!_ouvert) return tile;
    return Dismissible(
      key: ValueKey('ligne-${l.integer('id')}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => _remove(l),
      child: InkWell(borderRadius: BorderRadius.circular(14), onTap: () => _count(a, ligne: l), child: tile),
    );
  }
}

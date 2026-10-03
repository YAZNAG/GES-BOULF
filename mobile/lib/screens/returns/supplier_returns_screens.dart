import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/article.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/lines_editor.dart';
import '../../widgets/paged_list.dart';
import '../../widgets/pickers.dart';

/// Règlement d'un retour fournisseur.
String settlementLabel(String? r) => switch (r) {
      'avoir' => 'Avoir (déduit du crédit)',
      'remboursement' => 'Remboursement',
      null || '' => '—',
      _ => r,
    };

/// Liste des retours fournisseurs.
class SupplierReturnsScreen extends StatefulWidget {
  const SupplierReturnsScreen({super.key, this.supplierId, this.supplierName});

  final int? supplierId;
  final String? supplierName;

  @override
  State<SupplierReturnsScreen> createState() => _SupplierReturnsScreenState();
}

class _SupplierReturnsScreenState extends State<SupplierReturnsScreen> {
  final _list = GlobalKey<PagedListState<Json>>();

  @override
  Widget build(BuildContext context) {
    final api = context.api;
    return Scaffold(
      appBar: darkAppBar('Retours fournisseurs', subtitle: widget.supplierName),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'supplier-return-add',
        onPressed: () async {
          await context.push(const SupplierReturnForm());
          _list.currentState?.reload();
        },
        icon: const Icon(Icons.add),
        label: const Text('Nouveau retour'),
      ),
      body: PagedList<Json>(
        key: _list,
        searchHint: 'N° de retour, fournisseur…',
        emptyIcon: Icons.assignment_return,
        emptyTitle: 'Aucun retour fournisseur',
        headerBuilder: (context, raw) {
          final s = raw.obj('stats');
          if (s == null) return null;
          return StatsRow(children: [
            MiniStat(label: 'Retours du mois', value: qty(s['mois_nombre'])),
            MiniStat(label: 'Montant du mois', value: moneyShort(s['mois_montant']), color: AppColors.warning),
          ]);
        },
        fetch: (page, q) => api.page('retours-fournisseurs', (j) => j,
            page: page, query: {'q': q, 'fournisseur_id': widget.supplierId}),
        itemBuilder: (ctx, r, reload) => ListTile(
          leading: IconSquare(Icons.assignment_return, color: r.str('reglement') == 'avoir' ? AppColors.info : AppColors.warning),
          title: Text(r.str('numero'), style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(
            [
              r.obj('fournisseur')?.str('nom') ?? '—',
              date(r['date_retour']),
              settlementLabel(r.strOrNull('reglement')),
              ?r.obj('reception')?.strOrNull('numero'),
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5),
          ),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(money(r['total']), style: const TextStyle(fontWeight: FontWeight.w800)),
            Text('${r.integer('lignes_count')} ligne${r.integer('lignes_count') > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ]),
          onTap: () => ctx.push(SupplierReturnDetailScreen(returnId: r.integer('id'))),
        ),
      ),
    );
  }
}

/// Détail d'un retour fournisseur (GET retours-fournisseurs/{id}).
class SupplierReturnDetailScreen extends StatelessWidget {
  const SupplierReturnDetailScreen({super.key, required this.returnId});

  final int returnId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: darkAppBar('Retour fournisseur'),
      body: AsyncView<Json>(
        load: () async => (await context.api.get('retours-fournisseurs/$returnId') as Map).cast<String, dynamic>(),
        builder: (context, r, reload) {
          final lignes = r.list('lignes');
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.circular(20)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(r.str('numero'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    ),
                    Badge2(r.str('reglement') == 'avoir' ? 'Avoir' : 'Remboursement', color: const Color(0xFF93C5FD)),
                  ]),
                  const SizedBox(height: 4),
                  Text(r.obj('fournisseur')?.str('nom') ?? '—', style: const TextStyle(color: Colors.white70, fontSize: 15)),
                  const SizedBox(height: 12),
                  Text(money(r['total']), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                ]),
              ),
              const SizedBox(height: 14),
              SectionCard(title: 'Informations', icon: Icons.info_outline, children: [
                InfoRow('Date du retour', date(r['date_retour'])),
                InfoRow('Règlement', settlementLabel(r.strOrNull('reglement'))),
                if (r.obj('reception') != null) InfoRow('Bon de réception', r.obj('reception')!.str('numero')),
                InfoRow('Motif', r.str('motif')),
                if (r.strOrNull('note') != null) InfoRow('Note', r.str('note')),
                InfoRow('Enregistré par', r.obj('utilisateur')?.str('nom') ?? ''),
              ]),
              const SizedBox(height: 14),
              SectionCard(
                title: 'Articles retournés (${lignes.length})',
                icon: Icons.inventory_2_outlined,
                padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
                children: [
                  for (final (i, l) in lignes.indexed) ...[
                    if (i > 0) const Divider(height: 1, indent: 16),
                    _line(l),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              SectionCard(children: [
                TotalLine('Total du retour', money(r['total']), bold: true),
                Text(
                  r.str('reglement') == 'avoir'
                      ? 'Montant déduit de ce que nous devons au fournisseur.'
                      : 'Montant à rembourser par le fournisseur.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                ),
              ]),
            ]),
          );
        },
      ),
    );
  }

  Widget _line(Json l) {
    final a = l.obj('article') ?? {};
    final ar = a.articleNameAr;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        ItemThumb(path: a['image'], label: a.articleName, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.articleName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (ar != null) Align(alignment: Alignment.centerLeft, child: ArabicText(ar, maxLines: 1)),
            Text('${qty(l['quantite'], a.unit)} × ${money(l['prix_achat'])}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ]),
        ),
        Text(money(l.dbl('quantite') * l.dbl('prix_achat')), style: const TextStyle(fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

/// Création d'un retour fournisseur : fournisseur, lignes (scan / recherche), règlement.
class SupplierReturnForm extends StatefulWidget {
  const SupplierReturnForm({super.key, this.supplier});

  final Json? supplier;

  @override
  State<SupplierReturnForm> createState() => _SupplierReturnFormState();
}

class _SupplierReturnFormState extends State<SupplierReturnForm> {
  late Json? _supplier = widget.supplier;
  String? _date = apiDate(DateTime.now());
  String _reglement = 'avoir';
  final _motif = TextEditingController();
  final _note = TextEditingController();
  final _lines = <DocLine>[];
  bool _busy = false;
  Map<String, List<String>> _errors = {};

  @override
  void dispose() {
    _motif.dispose();
    _note.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double get _total => round2(_lines.fold(0.0, (t, l) => t + l.total));

  Future<void> _save() async {
    final errors = <String, List<String>>{};
    if (_supplier == null) errors['fournisseur_id'] = ['Choisissez un fournisseur.'];
    if (_lines.isEmpty) errors['lignes'] = ['Ajoutez au moins un article.'];
    for (var i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      if (parseInput(l.quantity.text) == null || l.qtyValue <= 0) errors['lignes.$i.quantite'] = ['Quantité invalide'];
      if (parseInput(l.price.text) == null || l.priceValue < 0) errors['lignes.$i.prix_achat'] = ['Prix d’achat requis'];
    }
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      showError(context, ApiException('Vérifiez les champs en rouge.'));
      return;
    }
    setState(() {
      _busy = true;
      _errors = {};
    });
    try {
      final res = await context.api.post('retours-fournisseurs', {
        'fournisseur_id': _supplier!.integer('id'),
        'date_retour': _date,
        'reglement': _reglement,
        if (_motif.text.trim().isNotEmpty) 'motif': _motif.text.trim(),
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
        'lignes': [
          for (final l in _lines) {'article_id': l.articleId, 'quantite': l.qtyValue, 'prix_achat': l.priceValue},
        ],
      });
      if (!mounted) return;
      final r = res is Map ? res.cast<String, dynamic>() : <String, dynamic>{};
      showSuccess(context, 'Retour ${r.str('numero')} enregistré · ${money(r['total'] ?? _total)}. Stock mis à jour.');
      final id = r.intOrNull('id');
      if (id != null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SupplierReturnDetailScreen(returnId: id)));
      } else {
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errors = e.errors);
      showError(context, e);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: darkAppBar('Nouveau retour fournisseur'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        EntityField(
          label: 'Fournisseur *',
          icon: Icons.local_shipping_outlined,
          text: _supplier?.str('nom'),
          subtitle: _supplier != null && _supplier!.dbl('solde') > 0 ? 'Crédit actuel : ${money(_supplier!['solde'])}' : null,
          error: _errors['fournisseur_id']?.first,
          onTap: () async {
            final s = await pickSupplier(context);
            if (s != null) setState(() => _supplier = s);
          },
        ),
        const SizedBox(height: 12),
        DateField(label: 'Date du retour', value: _date, onChanged: (v) => setState(() => _date = v)),
        const GroupLabel('Articles retournés'),
        LinesEditor(
          lines: _lines,
          onChanged: () => setState(() {}),
          priceLabel: 'Prix d’achat',
          errors: _errors,
        ),
        const GroupLabel('Règlement'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (k, label, icon) in const [
            ('avoir', 'Avoir — déduit du crédit', Icons.account_balance_wallet_outlined),
            ('remboursement', 'Remboursement', Icons.payments_outlined),
          ])
            ChoiceChip(
              avatar: Icon(icon, size: 18, color: _reglement == k ? AppColors.primary : AppColors.muted),
              label: Text(label),
              selected: _reglement == k,
              showCheckmark: false,
              selectedColor: AppColors.primary.withValues(alpha: 0.12),
              side: BorderSide(color: _reglement == k ? AppColors.primary : AppColors.border),
              labelStyle: TextStyle(
                color: _reglement == k ? AppColors.primary : AppColors.ink,
                fontWeight: _reglement == k ? FontWeight.w700 : FontWeight.w500,
              ),
              onSelected: (_) => setState(() => _reglement = k),
            ),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            _reglement == 'avoir'
                ? 'Le montant est déduit de ce que nous devons au fournisseur.'
                : 'Le fournisseur nous rembourse le montant.',
            style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
        ),
        const SizedBox(height: 14),
        TextField(controller: _motif, decoration: InputDecoration(labelText: 'Motif (facultatif)', errorText: _errors['motif']?.first)),
        const SizedBox(height: 12),
        TextField(controller: _note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note (facultatif)')),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TotalLine('Total du retour', money(_total), big: true),
          ),
        ),
      ]),
      bottomNavigationBar: BottomAction(
        leading: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('${_lines.length} ligne${_lines.length > 1 ? 's' : ''}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          FittedBox(child: Text(money(_total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
        ]),
        label: 'Valider',
        icon: Icons.assignment_return,
        busy: _busy,
        onPressed: _save,
      ),
    );
  }
}

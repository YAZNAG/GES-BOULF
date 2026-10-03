import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/article.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/photo_field.dart';
import '../../widgets/pickers.dart';

const _mois = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

Color _hex(String? s, [Color fallback = AppColors.muted]) {
  final v = (s ?? '').replaceAll('#', '');
  final n = int.tryParse(v.length == 6 ? 'FF$v' : v, radix: 16);
  return n == null ? fallback : Color(n);
}

IconData _icon(String? name) => switch (name) {
      'home' => Icons.home_outlined,
      'bolt' => Icons.bolt,
      'water' => Icons.water_drop_outlined,
      'people' => Icons.groups_outlined,
      'truck' => Icons.local_shipping_outlined,
      'wifi' => Icons.wifi,
      'build' => Icons.build_outlined,
      'inventory' => Icons.inventory_2_outlined,
      'gavel' => Icons.gavel,
      'bank' => Icons.account_balance_outlined,
      _ => Icons.receipt_long_outlined,
    };

/// Charges du magasin : mois par mois, total, répartition par catégorie.
class ChargesScreen extends StatefulWidget {
  const ChargesScreen({super.key});

  @override
  State<ChargesScreen> createState() => _ChargesScreenState();
}

class _ChargesScreenState extends State<ChargesScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int? _categorie;
  Json? _data;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final fin = DateTime(_month.year, _month.month + 1, 0);
    try {
      final res = await context.api.get('charges', {
        'du': apiDate(_month),
        'au': apiDate(fin),
        'per_page': 100,
        'categorie_id': _categorie,
      }) as Json;
      if (mounted) setState(() => _data = res);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _shift(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _data = null;
    });
    _load();
  }

  Future<void> _open([Json? charge]) async {
    final saved = await context.push<bool>(ChargeFormScreen(charge: charge));
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final parCat = _data?.list('par_categorie') ?? [];
    final items = _data?.list('data') ?? [];
    final total = _data?.dbl('montant_total') ?? 0;
    final current = _month.year == DateTime.now().year && _month.month == DateTime.now().month;
    return Scaffold(
      appBar: darkAppBar('Charges'),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'charge-new',
        onPressed: () => _open(),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle charge'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 96), children: [
          // En-tête : mois et total.
          Container(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 18),
            decoration: BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              Row(children: [
                IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left, color: Colors.white)),
                Expanded(
                  child: Text('${_mois[_month.month - 1][0].toUpperCase()}${_mois[_month.month - 1].substring(1)} ${_month.year}',
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                IconButton(
                  onPressed: current ? null : () => _shift(1),
                  icon: Icon(Icons.chevron_right, color: current ? Colors.white24 : Colors.white),
                ),
              ]),
              Text(money(total), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
              Text('${_data?.integer('total') ?? 0} charge(s)${_categorie != null ? ' dans cette catégorie' : ''}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
            ]),
          ),
          const SizedBox(height: 12),
          // Répartition par catégorie (filtre).
          if (parCat.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Toutes'),
                    selected: _categorie == null,
                    onSelected: (_) {
                      setState(() => _categorie = null);
                      _load();
                    },
                  ),
                ),
                for (final c in parCat)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(_icon(c.strOrNull('icone')), size: 16, color: _hex(c.strOrNull('couleur'))),
                      label: Text('${c.str('nom')} · ${moneyShort(c['montant'])}'),
                      selected: _categorie == c.integer('id'),
                      onSelected: (_) {
                        setState(() => _categorie = c.integer('id'));
                        _load();
                      },
                    ),
                  ),
              ]),
            ),
          if (parCat.isNotEmpty && total > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(children: [
                for (final c in parCat)
                  Expanded(
                    flex: ((c.dbl('montant') / total) * 1000).round().clamp(1, 1000),
                    child: Container(height: 10, color: _hex(c.strOrNull('couleur'))),
                  ),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          if (_error != null) ErrorState(error: _error!, onRetry: _load),
          if (_data == null && _error == null) const SkeletonList(count: 5),
          if (_data != null && items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: EmptyState(icon: Icons.receipt_long_outlined, title: 'Aucune charge', message: 'Ajoutez le loyer, l’électricité, les salaires…'),
            ),
          for (final ch in items) _tile(ch),
        ]),
      ),
    );
  }

  Widget _tile(Json ch) {
    final cat = ch.obj('categorie') ?? {};
    final color = _hex(cat.strOrNull('couleur'));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(_icon(cat.strOrNull('icone')), color: color)),
          title: Text(ch.str('libelle'), style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text([
            date(ch['date_charge']),
            cat.str('nom'),
            if (ch.strOrNull('beneficiaire') != null) ch.str('beneficiaire'),
          ].join(' · ')),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(money(ch['montant']), style: const TextStyle(fontWeight: FontWeight.w900)),
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (ch.strOrNull('piece') != null) const Icon(Icons.attach_file, size: 14, color: AppColors.muted),
              Text(paymentModeLabel(ch.strOrNull('mode_paiement')), style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
            ]),
          ]),
          onTap: () => _open(ch),
        ),
      ),
    );
  }
}

/// Saisie / modification d'une charge, avec photo du justificatif.
class ChargeFormScreen extends StatefulWidget {
  const ChargeFormScreen({super.key, this.charge});

  final Json? charge;

  @override
  State<ChargeFormScreen> createState() => _ChargeFormScreenState();
}

class _ChargeFormScreenState extends State<ChargeFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _libelle = TextEditingController(text: widget.charge?.str('libelle') ?? '');
  late final _montant = TextEditingController(text: widget.charge == null ? '' : priceInput(widget.charge!['montant']));
  late final _benef = TextEditingController(text: widget.charge?.str('beneficiaire') ?? '');
  late final _ref = TextEditingController(text: widget.charge?.str('reference') ?? '');
  late final _note = TextEditingController(text: widget.charge?.str('note') ?? '');
  late String _date = widget.charge?.str('date_charge') ?? apiDate(DateTime.now());
  late String _mode = widget.charge?.str('mode_paiement', 'especes') ?? 'especes';
  late int? _categorie = widget.charge?.intOrNull('categorie_charge_id');
  List<Json>? _categories;
  File? _piece;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    for (final c in [_libelle, _montant, _benef, _ref, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final res = await context.api.get('categories_charges');
      if (mounted) setState(() => _categories = (res as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList());
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _save() async {
    if (_categorie == null) {
      showInfo(context, 'Choisissez la catégorie de la charge.');
      return;
    }
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final edit = widget.charge != null;
      await context.api.multipart(edit ? 'charges/${widget.charge!.integer('id')}' : 'charges', {
        'categorie_charge_id': _categorie,
        'libelle': _libelle.text.trim(),
        'montant': parseInput(_montant.text),
        'date_charge': _date,
        'mode_paiement': _mode,
        'beneficiaire': _benef.text.trim(),
        'reference': _ref.text.trim(),
        'note': _note.text.trim(),
        if (edit) '_method': 'PUT',
      }, file: _piece, fileField: 'piece');
      if (!mounted) return;
      showSuccess(context, edit ? 'Charge modifiée.' : 'Charge enregistrée.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirm(context, 'Supprimer la charge', '« ${widget.charge!.str('libelle')} » sera supprimée.', ok: 'Supprimer', danger: true);
    if (!ok || !mounted) return;
    final res = await runBusy(context, () => context.api.delete('charges/${widget.charge!.integer('id')}'), success: 'Charge supprimée.');
    if (res != null && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final cats = _categories;
    return Scaffold(
      appBar: darkAppBar(widget.charge == null ? 'Nouvelle charge' : 'Modifier la charge', actions: [
        if (widget.charge != null) IconButton(tooltip: 'Supprimer', icon: const Icon(Icons.delete_outline), onPressed: _delete),
      ]),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
          TextFormField(
            controller: _montant,
            autofocus: widget.charge == null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            decoration: const InputDecoration(labelText: 'Montant *', suffixText: 'DH', prefixIcon: Icon(Icons.payments_outlined)),
            validator: (v) {
              final n = parseInput(v ?? '');
              return n == null || n <= 0 ? 'Indiquez le montant.' : null;
            },
          ),
          const GroupLabel('Catégorie'),
          if (cats == null)
            const LinearProgressIndicator()
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in cats)
                ChoiceChip(
                  avatar: Icon(_icon(c.strOrNull('icone')), size: 18, color: _categorie == c.integer('id') ? Colors.white : _hex(c.strOrNull('couleur'))),
                  label: Text(c.str('nom')),
                  selected: _categorie == c.integer('id'),
                  selectedColor: _hex(c.strOrNull('couleur'), AppColors.primary),
                  labelStyle: TextStyle(color: _categorie == c.integer('id') ? Colors.white : AppColors.ink, fontWeight: FontWeight.w600),
                  showCheckmark: false,
                  onSelected: (_) => setState(() {
                    _categorie = c.integer('id');
                    if (_libelle.text.trim().isEmpty) _libelle.text = c.str('nom');
                  }),
                ),
            ]),
          const GroupLabel('Détails'),
          TextFormField(
            controller: _libelle,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Libellé *', hintText: 'ex. Facture électricité septembre'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Indiquez le libellé.' : null,
          ),
          const SizedBox(height: 12),
          DateField(label: 'Date', value: _date, onChanged: (v) => setState(() => _date = v ?? _date)),
          const SizedBox(height: 12),
          PaymentModePicker(value: _mode, onChanged: (v) => setState(() => _mode = v)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _benef,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Bénéficiaire', hintText: 'ex. Lydec, propriétaire, salarié…'),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _ref, decoration: const InputDecoration(labelText: 'Référence (n° facture, chèque…)')),
          const SizedBox(height: 12),
          TextFormField(controller: _note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note')),
          const GroupLabel('Justificatif'),
          Center(child: PhotoField(file: _piece, imagePath: widget.charge?.strOrNull('piece'), onChanged: (f) => setState(() => _piece = f), size: 160)),
        ]),
      ),
      bottomNavigationBar: BottomAction(label: 'Enregistrer', busy: _saving, onPressed: _save),
    );
  }
}

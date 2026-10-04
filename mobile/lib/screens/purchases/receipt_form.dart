import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/article.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/lines_editor.dart';
import '../../widgets/pickers.dart';
import '../suppliers/suppliers_screens.dart';
import 'receipts_screens.dart';

/// Bon de réception : direct, ou depuis un bon de commande confirmé.
/// Prix d'achat saisi à la réception ; prix de vente facultatif ; montant payé facultatif.
class ReceiptForm extends StatefulWidget {
  const ReceiptForm({super.key, this.order});

  /// Bon de commande (détail complet) à réceptionner.
  final Json? order;

  @override
  State<ReceiptForm> createState() => _ReceiptFormState();
}

class _ReceiptFormState extends State<ReceiptForm> {
  Json? _supplier;
  Json? _order;
  String? _date = apiDate(DateTime.now());
  final _ref = TextEditingController();
  final _note = TextEditingController();
  final _paid = TextEditingController();
  String _mode = 'especes';
  final _lines = <DocLine>[];
  bool _busy = false;
  Map<String, List<String>> _errors = {};

  @override
  void initState() {
    super.initState();
    if (widget.order != null) _applyOrder(widget.order!);
  }

  @override
  void dispose() {
    _ref.dispose();
    _note.dispose();
    _paid.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double get _total => round2(_lines.fold(0.0, (t, l) => t + l.total));
  double get _paidValue => parseInput(_paid.text) ?? 0;

  void _applyOrder(Json o) {
    for (final l in _lines) {
      l.dispose();
    }
    _lines.clear();
    _order = o;
    _supplier = o.obj('fournisseur') ?? _supplier;
    for (final l in o.list('lignes')) {
      final q = l.dbl('quantite');
      final r = l.dbl('quantite_recue');
      final remaining = q - r;
      if (remaining <= 0) continue;
      final a = l.obj('article') ?? {'id': l['article_id'], 'nom': tr('Article #{id}', {'id': l['article_id']})};
      final price = l.dbl('prix_unitaire') > 0 ? l.dbl('prix_unitaire') : a.prixAchat;
      _lines.add(DocLine(
        a,
        quantity: remaining,
        price: priceInput(price),
        orderLineId: l.intOrNull('id'),
        info: r > 0
            ? tr('Commandé {commande} · reçu {recu}', {'commande': qty(q), 'recu': qty(r)})
            : tr('Commandé {commande}', {'commande': qty(q)}),
      ));
    }
  }

  Future<void> _pickOrder() async {
    final supplier = _supplier;
    final api = context.api;
    final orders = await runBusy(context, () async {
      final out = <Json>[];
      for (final st in ['confirmee', 'partielle']) {
        final p = await api.page('achats/commandes', (j) => j,
            perPage: 50, query: {'statut': st, if (supplier != null) 'fournisseur_id': supplier.integer('id')});
        out.addAll(p.items);
      }
      return out;
    });
    if (orders == null || !mounted) return;
    if (orders.isEmpty) {
      showInfo(
          context,
          supplier != null
              ? tr('Aucun bon de commande confirmé à réceptionner pour ce fournisseur.')
              : tr('Aucun bon de commande confirmé à réceptionner.'));
      return;
    }
    final picked = await showModalBottomSheet<Json>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.75),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(tr('Bons de commande à réceptionner'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final o in orders)
                  ListTile(
                    leading: IconSquare(Icons.receipt_long_outlined, color: orderStatusColor(o.str('statut'))),
                    title: Text(o.str('numero'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${o.obj('fournisseur')?.str('nom') ?? ''} · ${date(o['date_commande'])} · ${orderStatusLabel(o.str('statut'))}'),
                    trailing: Text(moneyShort(o['total']), style: const TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () => Navigator.pop(c, o),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final full = await runBusy(context, () async => (await api.get('achats/commandes/${picked.integer('id')}') as Map).cast<String, dynamic>());
    if (full == null || !mounted) return;
    setState(() => _applyOrder(full));
    if (_lines.isEmpty) showInfo(context, tr('Toutes les lignes de ce bon ont déjà été reçues.'));
  }

  void _detachOrder() {
    setState(() {
      _order = null;
      for (final l in _lines) {
        l.dispose();
      }
      _lines.clear();
    });
  }

  Future<void> _save() async {
    final errors = <String, List<String>>{};
    if (_supplier == null) errors['fournisseur_id'] = [tr('Choisissez un fournisseur.')];
    if (_lines.isEmpty) errors['lignes'] = [tr('Ajoutez au moins un article.')];
    for (var i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      if (l.qtyValue < 0 || parseInput(l.quantity.text) == null) errors['lignes.$i.quantite'] = [tr('Quantité invalide')];
      if (parseInput(l.price.text) == null) errors['lignes.$i.prix_achat'] = [tr('Prix d’achat requis')];
    }
    if (_paid.text.trim().isNotEmpty && parseInput(_paid.text) == null) errors['montant_paye'] = [tr('Montant invalide.')];
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      showError(context, ApiException(tr('Vérifiez les champs en rouge.')));
      return;
    }
    if (_paidValue > _total + 0.001) {
      final ok = await confirm(context, tr('Montant payé supérieur'),
          tr('Le montant payé ({paye}) dépasse le total ({total}). Continuer ?', {'paye': money(_paidValue), 'total': money(_total)}));
      if (!ok || !mounted) return;
    }
    setState(() {
      _busy = true;
      _errors = {};
    });
    final body = {
      'fournisseur_id': _supplier!.integer('id'),
      'commande_achat_id': _order?.integer('id'),
      'date_reception': _date,
      'reference_fournisseur': _ref.text.trim().isEmpty ? null : _ref.text.trim(),
      'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
      if (_paidValue > 0) 'montant_paye': _paidValue,
      if (_paidValue > 0) 'mode_paiement': _mode,
      'lignes': [
        for (final l in _lines)
          {
            'article_id': l.articleId,
            'quantite': l.qtyValue,
            'prix_achat': l.priceValue,
            if (l.salePriceValue != null && l.salePriceValue! > 0) 'prix_vente': l.salePriceValue,
            if (l.orderLineId != null) 'ligne_commande_achat_id': l.orderLineId,
          },
      ],
    };
    try {
      final res = await context.api.post('achats/receptions', body);
      if (!mounted) return;
      showSuccess(context, tr('Réception enregistrée : stock et prix d’achat mis à jour.'));
      final id = res is Map ? res.cast<String, dynamic>().intOrNull('id') : null;
      if (widget.order == null && id != null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ReceiptDetailScreen(receiptId: id)));
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
    final credit = _total - _paidValue;
    return Scaffold(
      appBar: darkAppBar(tr('Nouvelle réception'), subtitle: _order?.str('numero')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        EntityField(
          label: tr('Fournisseur *'),
          icon: Icons.local_shipping_outlined,
          text: _supplier?.str('nom'),
          subtitle: _supplier != null && _supplier!.dbl('solde') > 0 ? tr('Crédit actuel : {montant}', {'montant': money(_supplier!['solde'])}) : null,
          error: _errors['fournisseur_id']?.first,
          onTap: _order != null
              ? null
              : () async {
                  final s = await pickSupplier(context);
                  if (s != null) setState(() => _supplier = s);
                },
        ),
        const SizedBox(height: 12),
        if (_order == null)
          OutlinedButton.icon(
            onPressed: _pickOrder,
            icon: const Icon(Icons.receipt_long_outlined),
            label: Text(tr('Depuis un bon de commande')),
          )
        else
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 6, 6),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.link, color: AppColors.info),
              const SizedBox(width: 10),
              Expanded(
                child: Text(tr('Bon de commande {numero}', {'numero': _order!.str('numero')}),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.info)),
              ),
              if (widget.order == null) IconButton(icon: const Icon(Icons.close), tooltip: tr('Détacher'), onPressed: _detachOrder),
            ]),
          ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: DateField(label: tr('Date'), value: _date, onChanged: (v) => setState(() => _date = v))),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _ref,
              decoration: InputDecoration(labelText: tr('N° BL fournisseur'), errorText: _errors['reference_fournisseur']?.first),
            ),
          ),
        ]),
        GroupLabel(tr('Articles reçus')),
        LinesEditor(
          lines: _lines,
          onChanged: () => setState(() {}),
          priceLabel: tr('Prix d’achat'),
          showSalePrice: true,
          errors: _errors,
        ),
        GroupLabel(tr('Paiement')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TotalLine(tr('Total de la réception'), money(_total), bold: true),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _paid,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: tr('Montant payé (facultatif)'), suffixText: tr('DH'), errorText: _errors['montant_paye']?.first),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: () => setState(() => _paid.text = priceInput(_total)), child: Text(tr('Tout'))),
              ]),
              if (_paidValue > 0) ...[
                const SizedBox(height: 10),
                PaymentModePicker(value: _mode, modes: supplierPaymentModes, onChanged: (m) => setState(() => _mode = m)),
              ],
              const SizedBox(height: 10),
              TotalLine(tr('Reste en crédit fournisseur'), money(credit > 0 ? credit : 0), bold: true, color: credit > 0 ? AppColors.warning : AppColors.success),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        TextField(controller: _note, maxLines: 2, decoration: InputDecoration(labelText: tr('Note (facultatif)'))),
      ]),
      bottomNavigationBar: BottomAction(
        leading: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(_lines.length > 1 ? tr('{n} lignes', {'n': _lines.length}) : tr('{n} ligne', {'n': _lines.length}), style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          FittedBox(child: Text(money(_total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
        ]),
        label: tr('Valider'),
        icon: Icons.move_to_inbox_outlined,
        busy: _busy,
        onPressed: _save,
      ),
    );
  }
}

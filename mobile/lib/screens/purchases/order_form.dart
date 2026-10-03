import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/lines_editor.dart';
import '../../widgets/pickers.dart';
import 'orders_screens.dart';

/// Création / modification (brouillon) d'un bon de commande.
class OrderForm extends StatefulWidget {
  const OrderForm({super.key, this.order});

  final Json? order;

  @override
  State<OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends State<OrderForm> {
  Json? _supplier;
  String? _date = apiDate(DateTime.now());
  String? _expected;
  final _note = TextEditingController();
  final _lines = <DocLine>[];
  bool _busy = false;
  Map<String, List<String>> _errors = {};

  @override
  void initState() {
    super.initState();
    final o = widget.order;
    if (o != null) {
      _supplier = o.obj('fournisseur');
      _date = o.strOrNull('date_commande')?.substring(0, 10);
      _expected = o.strOrNull('date_prevue')?.substring(0, 10);
      _note.text = o.str('note');
      for (final l in o.list('lignes')) {
        _lines.add(DocLine(l.obj('article') ?? {'id': l['article_id'], 'nom': 'Article #${l['article_id']}'},
            quantity: l.dbl('quantite'), price: priceInput(l['prix_unitaire'])));
      }
    }
  }

  @override
  void dispose() {
    _note.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double get _total => _lines.fold(0.0, (t, l) => t + l.total);

  Future<void> _save() async {
    final errors = <String, List<String>>{};
    if (_supplier == null) errors['fournisseur_id'] = ['Choisissez un fournisseur.'];
    if (_lines.isEmpty) errors['lignes'] = ['Ajoutez au moins un article.'];
    for (var i = 0; i < _lines.length; i++) {
      if (_lines[i].qtyValue <= 0) errors['lignes.$i.quantite'] = ['Quantité > 0'];
    }
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }
    setState(() {
      _busy = true;
      _errors = {};
    });
    final body = {
      'fournisseur_id': _supplier!.integer('id'),
      'date_commande': _date,
      'date_prevue': _expected,
      'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
      'lignes': [
        for (final l in _lines) {'article_id': l.articleId, 'quantite': l.qtyValue, 'prix_unitaire': l.priceValue},
      ],
    };
    try {
      final api = context.api;
      final res = widget.order == null
          ? await api.post('achats/commandes', body)
          : await api.put('achats/commandes/${widget.order!.integer('id')}', body);
      if (!mounted) return;
      showSuccess(context, widget.order == null ? 'Bon de commande créé.' : 'Bon de commande modifié.');
      final id = res is Map ? res.cast<String, dynamic>().intOrNull('id') : null;
      if (widget.order == null && id != null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: id)));
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
      appBar: darkAppBar(widget.order == null ? 'Nouveau bon de commande' : 'Modifier ${widget.order!.str('numero')}'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        EntityField(
          label: 'Fournisseur *',
          icon: Icons.local_shipping_outlined,
          text: _supplier?.str('nom'),
          error: _errors['fournisseur_id']?.first,
          onTap: () async {
            final s = await pickSupplier(context);
            if (s != null) setState(() => _supplier = s);
          },
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: DateField(label: 'Date', value: _date, onChanged: (v) => setState(() => _date = v))),
          const SizedBox(width: 10),
          Expanded(
            child: DateField(label: 'Livraison prévue', value: _expected, allowClear: true, onChanged: (v) => setState(() => _expected = v)),
          ),
        ]),
        const SizedBox(height: 12),
        TextField(controller: _note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note (facultatif)')),
        const GroupLabel('Articles'),
        LinesEditor(
          lines: _lines,
          onChanged: () => setState(() {}),
          priceLabel: 'Prix unitaire',
          priceErrorKey: 'prix_unitaire',
          errors: _errors,
        ),
      ]),
      bottomNavigationBar: BottomAction(
        leading: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Text('Total', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          FittedBox(child: Text(money(_total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
        ]),
        label: 'Enregistrer',
        busy: _busy,
        onPressed: _save,
      ),
    );
  }
}

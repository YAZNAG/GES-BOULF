import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/article.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/pickers.dart';
import '../sales/sales_screens.dart';
import 'pos_screen.dart';

/// Encaissement : client, mode de paiement, montant reçu, rendu / crédit.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.items, required this.onSuccess});

  final List<CartItem> items;
  final VoidCallback onSuccess;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  Json? _client;
  String _mode = 'especes';
  late final _received = TextEditingController(text: priceInput(_total, keepZero: true));
  bool _busy = false;

  double get _total => round2(widget.items.fold(0.0, (t, e) => t + e.total));
  double get _receivedValue => parseInput(_received.text) ?? 0;
  double get _paid => round2(_receivedValue > _total ? _total : _receivedValue);
  double get _change => _receivedValue > _total ? round2(_receivedValue - _total) : 0;
  double get _credit => _receivedValue < _total ? round2(_total - _receivedValue) : 0;

  String? get _blocking {
    if (_received.text.trim().isNotEmpty && parseInput(_received.text) == null) return 'Montant reçu invalide.';
    if (_credit > 0 && _client == null) {
      return 'Client de passage : le paiement complet est obligatoire. Choisissez un client pour vendre à crédit.';
    }
    return null;
  }

  @override
  void dispose() {
    _received.dispose();
    super.dispose();
  }

  void _setReceived(double v) => setState(() => _received.text = priceInput(v, keepZero: true));

  List<double> _suggestions() {
    final t = _total;
    final out = <double>{};
    for (final step in [10.0, 20.0, 50.0, 100.0, 200.0]) {
      final v = (t / step).ceil() * step;
      if (v > t) out.add(v);
      if (out.length >= 3) break;
    }
    return out.toList()..sort();
  }

  Future<void> _pickClient() async {
    final c = await pickClient(context);
    if (c != null) setState(() => _client = c);
  }

  Future<void> _submit() async {
    final err = _blocking;
    if (err != null) {
      showError(context, ApiException(err));
      return;
    }
    if (_credit > 0) {
      final ok = await confirm(
        context,
        'Vente à crédit',
        '${money(_credit)} seront ajoutés au crédit de ${_client!.str('nom')}. Continuer ?',
        ok: 'Valider',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final res = await context.api.post('pos/sale', {
        'client_id': _client?.integer('id'),
        'items': [
          for (final i in widget.items)
            {'article_id': i.id, 'quantite': i.quantity, 'prix_unitaire': i.unitPrice},
        ],
        'montant_total': _total,
        'montant_paye': _paid,
        'mode_paiement': _mode,
      });
      final r = res is Map ? res.cast<String, dynamic>() : <String, dynamic>{};
      widget.onSuccess();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => SaleSuccessScreen(
          invoiceNumber: r.strOrNull('numero_facture'),
          saleId: r.intOrNull('vente_id'),
          total: _total,
          paid: _paid,
          change: _change,
          credit: _credit,
          clientName: _client?.str('nom'),
          mode: _mode,
        ),
      ));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocking = _blocking;
    final count = widget.items.length;
    return Scaffold(
      appBar: darkAppBar('Encaissement'),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total à payer · $count article${count > 1 ? 's' : ''}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(money(_total), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
            ),
          ]),
        ),
        const GroupLabel('Client'),
        Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            leading: IconSquare(_client == null ? Icons.directions_walk : Icons.person, color: _client == null ? AppColors.muted : AppColors.violet),
            title: Text(_client?.str('nom') ?? 'Client de passage', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(_client == null
                ? 'Paiement complet obligatoire'
                : [
                    if (_client!.strOrNull('telephone') != null) _client!.str('telephone'),
                    'Crédit actuel : ${money(_client!['solde'])}',
                  ].join(' · ')),
            trailing: _client == null
                ? TextButton(onPressed: _pickClient, child: const Text('Choisir'))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(tooltip: 'Changer', icon: const Icon(Icons.swap_horiz), onPressed: _pickClient),
                    IconButton(tooltip: 'Client de passage', icon: const Icon(Icons.close), onPressed: () => setState(() => _client = null)),
                  ]),
            onTap: _pickClient,
          ),
        ),
        const GroupLabel('Mode de paiement'),
        PaymentModePicker(
          value: _mode,
          onChanged: (m) => setState(() {
            _mode = m;
            if (m != 'especes' && _receivedValue > _total) _setReceived(_total);
          }),
        ),
        const GroupLabel('Montant reçu'),
        TextField(
          controller: _received,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            suffixText: 'DH',
            prefixIcon: const Icon(Icons.payments_outlined),
            suffixIcon: IconButton(tooltip: 'Effacer', icon: const Icon(Icons.backspace_outlined), onPressed: () => setState(_received.clear)),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ActionChip(
            avatar: const Icon(Icons.done_all, size: 18),
            label: const Text('Montant exact'),
            onPressed: () => _setReceived(_total),
          ),
          if (_mode == 'especes')
            for (final v in _suggestions()) ActionChip(label: Text(moneyShort(v)), onPressed: () => _setReceived(v)),
          if (_client != null) ActionChip(avatar: const Icon(Icons.schedule, size: 18), label: const Text('Tout à crédit'), onPressed: () => _setReceived(0)),
        ]),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              TotalLine('Total', money(_total)),
              TotalLine('Reçu', money(_receivedValue)),
              if (_change > 0) ...[
                const Divider(height: 18),
                TotalLine('Rendu monnaie', money(_change), big: true, color: AppColors.success),
              ],
              if (_credit > 0 && _client != null) ...[
                const Divider(height: 18),
                TotalLine('Reste en crédit client', money(_credit), big: true, color: AppColors.warning),
              ],
              if (_change == 0 && _credit == 0) ...[
                const Divider(height: 18),
                const TotalLine('Paiement', 'Complet', bold: true, color: AppColors.success),
              ],
            ]),
          ),
        ),
        if (blocking != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.info_outline, color: AppColors.danger),
              const SizedBox(width: 10),
              Expanded(child: Text(blocking, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600))),
            ]),
          ),
        ],
        const GroupLabel('Articles'),
        Card(
          child: Column(children: [
            for (final (i, it) in widget.items.indexed) ...[
              if (i > 0) const Divider(height: 1, indent: 16),
              ListTile(
                dense: true,
                title: Text(it.article.articleName, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${qty(it.quantity)} × ${money(it.unitPrice)}'),
                trailing: Text(money(it.total), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
        ),
      ]),
      bottomNavigationBar: BottomAction(
        label: 'Valider la vente',
        icon: Icons.check_circle_outline,
        busy: _busy,
        onPressed: blocking == null ? _submit : null,
      ),
    );
  }
}

/// Écran de succès après une vente.
class SaleSuccessScreen extends StatelessWidget {
  const SaleSuccessScreen({
    super.key,
    required this.invoiceNumber,
    required this.saleId,
    required this.total,
    required this.paid,
    required this.change,
    required this.credit,
    required this.clientName,
    required this.mode,
  });

  final String? invoiceNumber;
  final int? saleId;
  final double total;
  final double paid;
  final double change;
  final double credit;
  final String? clientName;
  final String mode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: SafeArea(
          child: Column(children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.4, end: 1),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.elasticOut,
                      builder: (_, v, child) => Transform.scale(scale: v, child: child),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle, boxShadow: [
                          BoxShadow(color: AppColors.success.withValues(alpha: 0.45), blurRadius: 30),
                        ]),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 60),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text('Vente enregistrée', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(
                      invoiceNumber == null ? 'Facture créée' : 'Facture n° $invoiceNumber',
                      style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 26),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(children: [
                          TotalLine('Client', clientName ?? 'Client de passage'),
                          TotalLine('Mode', paymentModeLabel(mode)),
                          const Divider(height: 18),
                          TotalLine('Total', money(total), bold: true),
                          TotalLine('Payé', money(paid)),
                          if (change > 0) TotalLine('Rendu monnaie', money(change), big: true, color: AppColors.success),
                          if (credit > 0) TotalLine('Ajouté au crédit', money(credit), big: true, color: AppColors.warning),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Nouvelle vente'),
                ),
                if (saleId != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)),
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => SaleDetailScreen(saleId: saleId!)),
                    ),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Voir le détail'),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

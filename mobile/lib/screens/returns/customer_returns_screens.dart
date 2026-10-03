import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/article.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';
import '../../widgets/pickers.dart';
import '../sales/sales_screens.dart';

/// Mode de remboursement d'un retour client.
String refundLabel(String? r) => switch (r) {
      'especes' => 'Espèces',
      'credit' => 'Déduit du crédit client',
      'aucun' => 'Aucun remboursement',
      null || '' => '—',
      _ => r,
    };

IconData _refundIcon(String? r) => switch (r) {
      'especes' => Icons.payments_outlined,
      'credit' => Icons.account_balance_wallet_outlined,
      _ => Icons.block,
    };

/// Nom du client d'une vente (client, client de passage nommé, ou « Client de passage »).
String _saleClient(Json? v) =>
    v?.obj('client')?.strOrNull('nom') ?? v?.strOrNull('nom_passage') ?? 'Client de passage';

/// Choix de la vente à retourner (ventes récentes, recherche par n° de facture ou client).
Future<Json?> pickSaleForReturn(BuildContext context) {
  final api = context.api;
  return pickEntity(
    context,
    title: 'Vente à retourner',
    searchHint: 'N° de facture, client…',
    fetch: (page, q) => api.page('m/ventes', (j) => j, page: page, query: {'q': q}),
    label: (v) => _saleClient(v),
    subtitle: (v) => [
      ?v.obj('facture')?.strOrNull('numero_facture'),
      dateTime(v['date_vente'] ?? v['created_at']),
      if (v.intOrNull('items_count') != null) '${v.integer('items_count')} art.',
    ].join(' · '),
    leading: (v) => const IconSquare(Icons.receipt_long, color: AppColors.success),
    trailing: (v) => Text(money(v['montant_total']), style: const TextStyle(fontWeight: FontWeight.w800)),
  );
}

/// Liste des retours clients.
class CustomerReturnsScreen extends StatefulWidget {
  const CustomerReturnsScreen({super.key});

  @override
  State<CustomerReturnsScreen> createState() => _CustomerReturnsScreenState();
}

class _CustomerReturnsScreenState extends State<CustomerReturnsScreen> {
  final _list = GlobalKey<PagedListState<Json>>();

  Future<void> _create() async {
    final sale = await pickSaleForReturn(context);
    if (sale == null || !mounted) return;
    final numero = await context.push<String>(CustomerReturnForm(saleId: sale.integer('id')));
    _list.currentState?.reload();
    if (numero != null && mounted) context.push(CustomerReturnDetailScreen(numero: numero));
  }

  @override
  Widget build(BuildContext context) {
    final api = context.api;
    return Scaffold(
      appBar: darkAppBar('Retours clients'),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'customer-return-add',
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau retour'),
      ),
      body: PagedList<Json>(
        key: _list,
        searchHint: 'N° de retour (RC-…)',
        emptyIcon: Icons.assignment_return_outlined,
        emptyTitle: 'Aucun retour client',
        headerBuilder: (context, raw) {
          final s = raw.obj('stats');
          if (s == null) return null;
          return StatsRow(children: [
            MiniStat(label: 'Retours du mois', value: qty(s['mois_nombre'])),
            MiniStat(label: 'Montant du mois', value: moneyShort(s['mois_montant']), color: AppColors.danger),
          ]);
        },
        fetch: (page, q) => api.page('retours-clients', (j) => j, page: page, query: {'q': q}),
        itemBuilder: (ctx, r, reload) {
          final v = r.obj('vente');
          return ListTile(
            leading: IconSquare(Icons.assignment_return_outlined, color: r.str('remboursement') == 'aucun' ? AppColors.muted : AppColors.danger),
            title: Text(r.str('numero'), style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
              [
                _saleClient(v),
                ?v?.obj('facture')?.strOrNull('numero_facture'),
                dateTime(r['date_retour']),
                refundLabel(r.strOrNull('remboursement')),
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5),
            ),
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(money(r['montant']), style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('${qty(r['quantite'])} art.', style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
            ]),
            onTap: () => ctx.push(CustomerReturnDetailScreen(numero: r.str('numero'))),
          );
        },
      ),
    );
  }
}

/// Détail d'un retour client (GET retours-clients/{numero}).
class CustomerReturnDetailScreen extends StatelessWidget {
  const CustomerReturnDetailScreen({super.key, required this.numero});

  final String numero;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: darkAppBar('Retour client'),
      body: AsyncView<Json>(
        load: () async => (await context.api.get('retours-clients/${Uri.encodeComponent(numero)}') as Map).cast<String, dynamic>(),
        builder: (context, r, reload) {
          final v = r.obj('vente');
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
                      child: Text(r.str('numero', numero),
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    ),
                    Badge2(refundLabel(r.strOrNull('remboursement')), color: const Color(0xFFFCA5A5)),
                  ]),
                  const SizedBox(height: 4),
                  Text(_saleClient(v), style: const TextStyle(color: Colors.white70, fontSize: 15)),
                  const SizedBox(height: 12),
                  Text(money(r['montant']), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(dateTime(r['date_retour']), style: const TextStyle(color: Colors.white60)),
                ]),
              ),
              const SizedBox(height: 14),
              SectionCard(title: 'Informations', icon: Icons.info_outline, children: [
                if (v != null)
                  InfoRow('Vente', '',
                      valueWidget: Align(
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          onTap: () => context.push(SaleDetailScreen(saleId: v.integer('id'))),
                          child: Text(
                            v.obj('facture')?.strOrNull('numero_facture') ?? 'Vente n° ${v.integer('id')}',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ),
                      )),
                InfoRow('Client', _saleClient(v)),
                InfoRow('Remboursement', refundLabel(r.strOrNull('remboursement'))),
                InfoRow('Motif', r.str('motif')),
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
                TotalLine('Montant du retour', money(r['montant']), bold: true, color: AppColors.danger),
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
    final enStock = l.flag('en_stock', true);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        ItemThumb(path: a['image'], label: a.articleName, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.articleName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (ar != null) Align(alignment: Alignment.centerLeft, child: ArabicText(ar, maxLines: 1)),
            const SizedBox(height: 3),
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(qty(l['quantite'], a.unit), style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
              Badge2(enStock ? 'Remis en stock' : 'Non remis en stock', color: enStock ? AppColors.success : AppColors.muted),
            ]),
          ]),
        ),
        Text(money(l['montant']), style: const TextStyle(fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _ReturnLine {
  _ReturnLine(this.data) : quantity = TextEditingController(text: '0');

  final Json data;
  final TextEditingController quantity;

  Json get article => data.obj('article') ?? {};
  int get articleId => data.integer('article_id');
  double get price => data.dbl('prix_unitaire');
  double get sold => data.dbl('vendu');
  double get alreadyReturned => data.dbl('deja_retourne');
  double get returnable => data.dbl('retournable');
  double get value => parseInput(quantity.text) ?? 0;
  bool get invalid =>
      (quantity.text.trim().isNotEmpty && parseInput(quantity.text) == null) || value < 0 || value > returnable + 0.0001;
  double get total => round2(value * price);
}

/// Création d'un retour client pour une vente (GET ventes/{id}/retournable → POST retours-clients).
/// Renvoie le numéro du retour créé.
class CustomerReturnForm extends StatefulWidget {
  const CustomerReturnForm({super.key, required this.saleId});

  final int saleId;

  @override
  State<CustomerReturnForm> createState() => _CustomerReturnFormState();
}

class _CustomerReturnFormState extends State<CustomerReturnForm> {
  Json? _sale;
  final _lines = <_ReturnLine>[];
  Object? _error;
  bool _loading = true;
  bool _busy = false;
  bool _enStock = true;
  String _refund = 'especes';
  final _motif = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _motif.dispose();
    for (final l in _lines) {
      l.quantity.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = (await context.api.get('ventes/${widget.saleId}/retournable') as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() {
        for (final l in _lines) {
          l.quantity.dispose();
        }
        _lines
          ..clear()
          ..addAll(res.list('lignes').map(_ReturnLine.new));
        _sale = res.obj('vente') ?? {'id': widget.saleId};
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _hasClient => _sale?.obj('client') != null || (_sale?.intOrNull('client_id') ?? 0) > 0;
  double get _total => round2(_lines.fold(0.0, (t, l) => t + (l.invalid ? 0 : l.total)));
  int get _count => _lines.where((l) => !l.invalid && l.value > 0).length;

  void _step(_ReturnLine l, double delta) {
    final v = (l.value + delta).clamp(0, l.returnable).toDouble();
    setState(() => l.quantity.text = qtyInput(v));
  }

  Future<void> _submit() async {
    if (_lines.any((l) => l.invalid)) {
      showError(context, ApiException('Une quantité dépasse le maximum retournable.'));
      return;
    }
    if (_count == 0) {
      showError(context, ApiException('Saisissez la quantité retournée d’au moins un article.'));
      return;
    }
    final ok = await confirm(
      context,
      'Valider le retour',
      '$_count article${_count > 1 ? 's' : ''} · ${money(_total)}\n'
          'Remboursement : ${refundLabel(_refund)}\n'
          '${_enStock ? 'Les articles sont remis en stock.' : 'Les articles ne sont pas remis en stock.'}',
      ok: 'Valider',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final res = await context.api.post('retours-clients', {
        'vente_id': widget.saleId,
        'remboursement': _refund,
        'en_stock': _enStock,
        if (_motif.text.trim().isNotEmpty) 'motif': _motif.text.trim(),
        'lignes': [
          for (final l in _lines)
            if (l.value > 0) {'article_id': l.articleId, 'quantite': l.value},
        ],
      });
      if (!mounted) return;
      final r = res is Map ? res.cast<String, dynamic>() : <String, dynamic>{};
      final numero = r.str('numero');
      showSuccess(context, 'Retour ${numero.isEmpty ? '' : '$numero '}enregistré · ${money(r['montant'] ?? _total)}');
      Navigator.pop(context, numero);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: darkAppBar('Nouveau retour client', subtitle: _sale?.obj('facture')?.strOrNull('numero_facture') ?? 'Vente n° ${widget.saleId}'),
      body: _loading
          ? const SkeletonList(count: 5)
          : _error != null
              ? ErrorState(error: _error!, onRetry: _load)
              : _form(),
      bottomNavigationBar: _loading || _error != null
          ? null
          : BottomAction(
              leading: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('$_count article${_count > 1 ? 's' : ''} · à rembourser', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                FittedBox(child: Text(money(_total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
              ]),
              label: 'Valider',
              icon: Icons.assignment_return_outlined,
              busy: _busy,
              onPressed: _submit,
            ),
    );
  }

  Widget _form() {
    final s = _sale!;
    final client = s.obj('client');
    final hasReturnable = _lines.any((l) => l.returnable > 0);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_saleClient(s), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(
            [?s.obj('facture')?.strOrNull('numero_facture'), dateTime(s['date_vente'])].join(' · '),
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 10),
          Text('Total de la vente : ${money(s['montant_total'])}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          if (client != null && client.dbl('solde') > 0)
            Text('Crédit client : ${money(client['solde'])}', style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13)),
        ]),
      ),
      GroupLabel('Articles (${_lines.length})'),
      if (!hasReturnable)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Text('Tous les articles de cette vente ont déjà été retournés.', style: TextStyle(color: AppColors.muted)),
          ),
        ),
      for (final l in _lines) _lineCard(l),
      const GroupLabel('Options'),
      Card(
        child: SwitchListTile(
          title: const Text('Remettre en stock', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Désactivez si l’article est abîmé ou périmé.'),
          value: _enStock,
          activeThumbColor: AppColors.primary,
          onChanged: (v) => setState(() => _enStock = v),
        ),
      ),
      const GroupLabel('Remboursement'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (k, label) in [
          ('especes', 'Espèces'),
          if (_hasClient) ('credit', 'Déduire du crédit client'),
          ('aucun', 'Aucun'),
        ])
          ChoiceChip(
            avatar: Icon(_refundIcon(k), size: 18, color: _refund == k ? AppColors.primary : AppColors.muted),
            label: Text(label),
            selected: _refund == k,
            showCheckmark: false,
            selectedColor: AppColors.primary.withValues(alpha: 0.12),
            side: BorderSide(color: _refund == k ? AppColors.primary : AppColors.border),
            labelStyle: TextStyle(
              color: _refund == k ? AppColors.primary : AppColors.ink,
              fontWeight: _refund == k ? FontWeight.w700 : FontWeight.w500,
            ),
            onSelected: (_) => setState(() => _refund = k),
          ),
      ]),
      if (!_hasClient)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('« Déduire du crédit » n’est possible que pour une vente à un client enregistré.',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ),
      const SizedBox(height: 14),
      TextField(controller: _motif, maxLines: 2, decoration: const InputDecoration(labelText: 'Motif (facultatif)')),
      const SizedBox(height: 14),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TotalLine(_refund == 'aucun' ? 'Valeur du retour' : 'À rembourser', money(_total), big: true, color: AppColors.danger),
        ),
      ),
    ]);
  }

  Widget _lineCard(_ReturnLine l) {
    final a = l.article;
    final ar = a.articleNameAr;
    final disabled = l.returnable <= 0;
    final invalid = l.invalid;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: invalid ? AppColors.danger : (l.value > 0 ? AppColors.primary : AppColors.border)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            ItemThumb(path: a['image'], label: a.articleName, size: 46),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.articleName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (ar != null) Align(alignment: Alignment.centerLeft, child: ArabicText(ar, maxLines: 1)),
                Text('${money(l.price)} / ${a.unit.isEmpty ? 'unité' : a.unit}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            Badge2('Vendu ${qty(l.sold)}', color: AppColors.info),
            if (l.alreadyReturned > 0) Badge2('Déjà retourné ${qty(l.alreadyReturned)}', color: AppColors.warning),
            Badge2(disabled ? 'Rien à retourner' : 'Retournable ${qty(l.returnable)}', color: disabled ? AppColors.muted : AppColors.success),
          ]),
          if (!disabled) ...[
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconButton.outlined(onPressed: l.value <= 0 ? null : () => _step(l, -1), icon: const Icon(Icons.remove)),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: l.quantity,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Qté retournée',
                    isDense: true,
                    errorText: invalid ? 'Max ${qty(l.returnable)}' : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 4),
              IconButton.outlined(onPressed: l.value >= l.returnable ? null : () => _step(l, 1), icon: const Icon(Icons.add)),
              const SizedBox(width: 8),
              TextButton(onPressed: () => setState(() => l.quantity.text = qtyInput(l.returnable)), child: const Text('Tout')),
            ]),
            if (l.value > 0 && !invalid)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Montant : ${money(l.total)}',
                    textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted)),
              ),
          ],
        ]),
      ),
    );
  }
}

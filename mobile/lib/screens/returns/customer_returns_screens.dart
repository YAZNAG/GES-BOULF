import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/article.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';
import '../../widgets/pickers.dart';
import '../sales/sales_screens.dart';

/// Mode de remboursement d'un retour client.
String refundLabel(String? r) => switch (r) {
      'especes' => tr('Espèces'),
      'credit' => tr('Déduit du crédit client'),
      'aucun' => tr('Aucun remboursement'),
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
    v?.obj('client')?.strOrNull('nom') ?? v?.strOrNull('nom_passage') ?? tr('Client de passage');

/// Choix de la vente à retourner (ventes récentes, recherche par n° de facture ou client).
Future<Json?> pickSaleForReturn(BuildContext context) {
  final api = context.api;
  return pickEntity(
    context,
    title: tr('Vente à retourner'),
    searchHint: tr('N° de facture, client…'),
    fetch: (page, q) => api.page('m/ventes', (j) => j, page: page, query: {'q': q}),
    label: (v) => _saleClient(v),
    subtitle: (v) => [
      ?v.obj('facture')?.strOrNull('numero_facture'),
      dateTime(v['date_vente'] ?? v['created_at']),
      if (v.intOrNull('items_count') != null) tr('{n} art.', {'n': v.integer('items_count')}),
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
      appBar: darkAppBar(tr('Retours clients')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'customer-return-add',
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: Text(tr('Nouveau retour')),
      ),
      body: PagedList<Json>(
        key: _list,
        searchHint: tr('N° de retour (RC-…)'),
        emptyIcon: Icons.assignment_return_outlined,
        emptyTitle: tr('Aucun retour client'),
        headerBuilder: (context, raw) {
          final s = raw.obj('stats');
          if (s == null) return null;
          return StatsRow(children: [
            MiniStat(label: tr('Retours du mois'), value: qty(s['mois_nombre'])),
            MiniStat(label: tr('Montant du mois'), value: moneyShort(s['mois_montant']), color: AppColors.danger),
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
              Text(tr('{n} art.', {'n': qty(r['quantite'])}), style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
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
      appBar: darkAppBar(tr('Retour client')),
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
              SectionCard(title: tr('Informations'), icon: Icons.info_outline, children: [
                if (v != null)
                  InfoRow(tr('Vente'), '',
                      valueWidget: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: InkWell(
                          onTap: () => context.push(SaleDetailScreen(saleId: v.integer('id'))),
                          child: Text(
                            v.obj('facture')?.strOrNull('numero_facture') ?? tr('Vente n° {id}', {'id': v.integer('id')}),
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ),
                      )),
                InfoRow(tr('Client'), _saleClient(v)),
                InfoRow(tr('Remboursement'), refundLabel(r.strOrNull('remboursement'))),
                InfoRow(tr('Motif'), r.str('motif')),
                InfoRow(tr('Enregistré par'), r.obj('utilisateur')?.str('nom') ?? ''),
              ]),
              const SizedBox(height: 14),
              SectionCard(
                title: tr('Articles retournés ({n})', {'n': lignes.length}),
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
                TotalLine(tr('Montant du retour'), money(r['montant']), bold: true, color: AppColors.danger),
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
            if (ar != null)
              Text(ar, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 3),
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(qty(l['quantite'], a.unit), style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
              Badge2(enStock ? tr('Remis en stock') : tr('Non remis en stock'), color: enStock ? AppColors.success : AppColors.muted),
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
      showError(context, ApiException(tr('Une quantité dépasse le maximum retournable.')));
      return;
    }
    if (_count == 0) {
      showError(context, ApiException(tr('Saisissez la quantité retournée d’au moins un article.')));
      return;
    }
    final ok = await confirm(
      context,
      tr('Valider le retour'),
      '${_count > 1 ? tr('{n} articles', {'n': _count}) : tr('{n} article', {'n': _count})} · ${money(_total)}\n'
          '${tr('Remboursement : {mode}', {'mode': refundLabel(_refund)})}\n'
          '${_enStock ? tr('Les articles sont remis en stock.') : tr('Les articles ne sont pas remis en stock.')}',
      ok: tr('Valider'),
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
      showSuccess(
          context,
          numero.isEmpty
              ? tr('Retour enregistré · {montant}', {'montant': money(r['montant'] ?? _total)})
              : tr('Retour {numero} enregistré · {montant}', {'numero': numero, 'montant': money(r['montant'] ?? _total)}));
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
      appBar: darkAppBar(tr('Nouveau retour client'),
          subtitle: _sale?.obj('facture')?.strOrNull('numero_facture') ?? tr('Vente n° {id}', {'id': widget.saleId})),
      body: _loading
          ? const SkeletonList(count: 5)
          : _error != null
              ? ErrorState(error: _error!, onRetry: _load)
              : _form(),
      bottomNavigationBar: _loading || _error != null
          ? null
          : BottomAction(
              leading: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(_count > 1 ? tr('{n} articles · à rembourser', {'n': _count}) : tr('{n} article · à rembourser', {'n': _count}), style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                FittedBox(child: Text(money(_total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
              ]),
              label: tr('Valider'),
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
          Text(tr('Total de la vente : {montant}', {'montant': money(s['montant_total'])}), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          if (client != null && client.dbl('solde') > 0)
            Text(tr('Crédit client : {montant}', {'montant': money(client['solde'])}), style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13)),
        ]),
      ),
      GroupLabel(tr('Articles ({n})', {'n': _lines.length})),
      if (!hasReturnable)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(tr('Tous les articles de cette vente ont déjà été retournés.'), style: const TextStyle(color: AppColors.muted)),
          ),
        ),
      for (final l in _lines) _lineCard(l),
      GroupLabel(tr('Options')),
      Card(
        child: SwitchListTile(
          title: Text(tr('Remettre en stock'), style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(tr('Désactivez si l’article est abîmé ou périmé.')),
          value: _enStock,
          activeThumbColor: AppColors.primary,
          onChanged: (v) => setState(() => _enStock = v),
        ),
      ),
      GroupLabel(tr('Remboursement')),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (k, label) in [
          ('especes', tr('Espèces')),
          if (_hasClient) ('credit', tr('Déduire du crédit client')),
          ('aucun', tr('Aucun')),
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
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(tr('« Déduire du crédit » n’est possible que pour une vente à un client enregistré.'),
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ),
      const SizedBox(height: 14),
      TextField(controller: _motif, maxLines: 2, decoration: InputDecoration(labelText: tr('Motif (facultatif)'))),
      const SizedBox(height: 14),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TotalLine(_refund == 'aucun' ? tr('Valeur du retour') : tr('À rembourser'), money(_total), big: true, color: AppColors.danger),
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
                if (ar != null)
                  Text(ar, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                Text('${money(l.price)} / ${a.unit.isEmpty ? tr('unité') : a.unit}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            Badge2(tr('Vendu {qte}', {'qte': qty(l.sold)}), color: AppColors.info),
            if (l.alreadyReturned > 0) Badge2(tr('Déjà retourné {qte}', {'qte': qty(l.alreadyReturned)}), color: AppColors.warning),
            Badge2(disabled ? tr('Rien à retourner') : tr('Retournable {qte}', {'qte': qty(l.returnable)}), color: disabled ? AppColors.muted : AppColors.success),
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
                    labelText: tr('Qté retournée'),
                    isDense: true,
                    errorText: invalid ? tr('Max {qte}', {'qte': qty(l.returnable)}) : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 4),
              IconButton.outlined(onPressed: l.value >= l.returnable ? null : () => _step(l, 1), icon: const Icon(Icons.add)),
              const SizedBox(width: 8),
              TextButton(onPressed: () => setState(() => l.quantity.text = qtyInput(l.returnable)), child: Text(tr('Tout'))),
            ]),
            if (l.value > 0 && !invalid)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(tr('Montant : {montant}', {'montant': money(l.total)}),
                    textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted)),
              ),
          ],
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/article.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';
import '../../widgets/pickers.dart';
import 'sales_screens.dart';

/// Nom affiché d'une vente à un client de passage.
String passageName(Json v) => v.strOrNull('nom_passage') ?? tr('Client de passage');

/// Reste à encaisser d'une vente (montant_total − montant_paye, jamais négatif).
double saleRemaining(Json v) {
  final r = round2(v.dbl('montant_total') - v.dbl('montant_paye'));
  return r > 0.009 ? r : 0;
}

/// Encaissement du reste d'une vente de passage (POST m/passage/{id}/encaisser). Renvoie true si enregistré.
Future<bool> collectPassagePayment(BuildContext context, Json sale, {bool showSaleLink = false}) async {
  final res = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PassagePaymentSheet(sale: sale, showSaleLink: showSaleLink),
  );
  if (res == 'detail' && context.mounted) {
    await context.push(SaleDetailScreen(saleId: sale.integer('id')));
    return true;
  }
  return res == true;
}

class _PassagePaymentSheet extends StatefulWidget {
  const _PassagePaymentSheet({required this.sale, required this.showSaleLink});

  final Json sale;
  final bool showSaleLink;

  @override
  State<_PassagePaymentSheet> createState() => _PassagePaymentSheetState();
}

class _PassagePaymentSheetState extends State<_PassagePaymentSheet> {
  late final double _reste = saleRemaining(widget.sale);
  late final _amount = TextEditingController(text: priceInput(_reste));
  final _note = TextEditingController();
  String _mode = 'especes';
  bool _busy = false;
  Map<String, List<String>> _errors = {};

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = parseInput(_amount.text);
    if (v == null || v <= 0) {
      setState(() => _errors = {'montant': [tr('Saisissez un montant supérieur à 0.')]});
      return;
    }
    if (v > _reste + 0.001) {
      setState(() => _errors = {'montant': [tr('Le montant dépasse le reste ({reste}).', {'reste': money(_reste)})]});
      return;
    }
    setState(() {
      _busy = true;
      _errors = {};
    });
    try {
      final res = await context.api.post('m/passage/${widget.sale.integer('id')}/encaisser', {
        'montant': v,
        'mode': _mode,
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      });
      if (!mounted) return;
      final r = res is Map ? res.cast<String, dynamic>() : <String, dynamic>{};
      final reste = r.dbl('reste');
      showSuccess(
          context,
          reste > 0.009
              ? tr('Encaissé {montant} · reste {reste}.', {'montant': money(v), 'reste': money(reste)})
              : tr('Encaissé {montant} · vente soldée.', {'montant': money(v)}));
      Navigator.pop(context, true);
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
    final v = widget.sale;
    final tel = v.strOrNull('telephone_passage');
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(tr('Encaisser le reste'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            [passageName(v), ?tel, tr('Vente n° {id}', {'id': v.integer('id')})].join(' · '),
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              TotalLine(tr('Total'), money(v['montant_total'])),
              TotalLine(tr('Déjà payé'), money(v['montant_paye']), color: AppColors.success),
              TotalLine(tr('Reste'), money(_reste), bold: true, color: AppColors.danger),
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                decoration: InputDecoration(labelText: tr('Montant'), suffixText: tr('DH'), errorText: _errors['montant']?.first, errorMaxLines: 2),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: () => setState(() => _amount.text = priceInput(_reste)), child: Text(tr('Tout'))),
          ]),
          const SizedBox(height: 12),
          PaymentModePicker(value: _mode, onChanged: (m) => setState(() => _mode = m)),
          const SizedBox(height: 12),
          TextField(controller: _note, decoration: InputDecoration(labelText: tr('Note (facultatif)'))),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: Text(tr('Enregistrer l’encaissement')),
          ),
          if (widget.showSaleLink) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () => Navigator.pop(context, 'detail'),
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(tr('Voir le détail de la vente')),
            ),
          ],
        ]),
      ),
    );
  }
}

enum _PassageView { impaye, tout, encaissements }

/// Clients de passage : ventes avec un reste à encaisser, historique, encaissements.
class PassageScreen extends StatefulWidget {
  const PassageScreen({super.key});

  @override
  State<PassageScreen> createState() => _PassageScreenState();
}

class _PassageScreenState extends State<PassageScreen> {
  _PassageView _view = _PassageView.impaye;
  Json? _stats;

  Future<Paginated<Json>> _fetch(ApiClient api, int page, String q) async {
    if (_view == _PassageView.encaissements) {
      return api.page('m/passage/encaissements', (j) => j, page: page);
    }
    final p = await api.page('m/passage', (j) => j,
        page: page, query: {'statut': _view == _PassageView.impaye ? 'impaye' : 'tout', 'q': q});
    final s = p.raw.obj('stats');
    if (s != null && mounted) setState(() => _stats = s);
    return p;
  }

  @override
  Widget build(BuildContext context) {
    final api = context.api;
    final enc = _view == _PassageView.encaissements;
    return Scaffold(
      appBar: darkAppBar(tr('Clients de passage')),
      body: PagedList<Json>(
        key: ValueKey(_view),
        showSearch: !enc,
        searchHint: tr('Nom ou téléphone'),
        emptyIcon: enc ? Icons.payments_outlined : Icons.directions_walk,
        emptyTitle: switch (_view) {
          _PassageView.impaye => tr('Rien à encaisser'),
          _PassageView.tout => tr('Aucune vente'),
          _PassageView.encaissements => tr('Aucun encaissement'),
        },
        emptyMessage: _view == _PassageView.impaye ? tr('Toutes les ventes de passage sont soldées.') : null,
        filters: FilterChips<_PassageView>(
          options: [
            (_PassageView.impaye, tr('À encaisser')),
            (_PassageView.tout, tr('Historique')),
            (_PassageView.encaissements, tr('Encaissements')),
          ],
          value: _view,
          onChanged: (v) {
            if (v != null) setState(() => _view = v);
          },
        ),
        headerBuilder: (context, raw) {
          final s = _stats;
          if (s == null) return null;
          return StatsRow(children: [
            MiniStat(label: tr('Reste total'), value: moneyShort(s['reste_total']), color: AppColors.danger),
            MiniStat(label: tr('Ventes impayées'), value: qty(s['ventes_impayees']), color: AppColors.warning),
            MiniStat(label: tr('Encaissé ce mois'), value: moneyShort(s['encaisse_mois']), color: AppColors.success),
          ]);
        },
        fetch: (page, q) => _fetch(api, page, q),
        itemBuilder: (ctx, item, reload) => enc ? _encaissementTile(ctx, item) : _saleTile(ctx, item, reload),
      ),
    );
  }

  Widget _saleTile(BuildContext ctx, Json v, VoidCallback reload) {
    final reste = saleRemaining(v);
    final tel = v.strOrNull('telephone_passage');
    final facture = v.obj('facture')?.strOrNull('numero_facture');
    return ListTile(
      leading: IconSquare(Icons.directions_walk, color: reste > 0 ? AppColors.danger : AppColors.success),
      title: Text(passageName(v), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        [?tel, dateTime(v['date_vente'] ?? v['created_at']), ?facture].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12.5),
      ),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(money(v['montant_total']), style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(tr('Payé {montant}', {'montant': money(v['montant_paye'])}), style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
        if (reste > 0)
          Text(tr('Reste {montant}', {'montant': money(reste)}), style: const TextStyle(fontSize: 11.5, color: AppColors.danger, fontWeight: FontWeight.w800)),
      ]),
      onTap: () async {
        if (reste > 0) {
          await collectPassagePayment(ctx, v, showSaleLink: true);
        } else {
          await ctx.push(SaleDetailScreen(saleId: v.integer('id')));
        }
        reload();
      },
      onLongPress: () => ctx.push(SaleDetailScreen(saleId: v.integer('id'))),
    );
  }

  Widget _encaissementTile(BuildContext ctx, Json e) {
    final v = e.obj('vente') ?? {};
    final tel = v.strOrNull('telephone_passage');
    return ListTile(
      leading: IconSquare(PaymentModePicker.icon(e.str('mode')), color: AppColors.success),
      title: Text(money(e['montant']), style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(
        [
          passageName(v),
          ?tel,
          dateTime(e['created_at']),
          paymentModeLabel(e.strOrNull('mode')),
          ?e.obj('utilisateur')?.strOrNull('nom'),
          ?e.strOrNull('note'),
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12.5),
      ),
      trailing: Text(tr('Vente n° {id}', {'id': e.integer('vente_id')}), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      onTap: () => ctx.push(SaleDetailScreen(saleId: e.integer('vente_id'))),
    );
  }
}

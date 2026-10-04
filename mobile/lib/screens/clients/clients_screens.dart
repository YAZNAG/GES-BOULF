import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/article.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/delete_helper.dart';
import '../../widgets/paged_list.dart';
import '../../widgets/pickers.dart';
import '../sales/sales_screens.dart';

/// Liste des clients (option : uniquement ceux qui ont un crédit).
class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key, this.creditOnly = false});

  final bool creditOnly;

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _list = GlobalKey<PagedListState<Json>>();
  late bool _credit = widget.creditOnly;

  @override
  Widget build(BuildContext context) {
    final api = context.api;
    return Scaffold(
      appBar: darkAppBar(widget.creditOnly ? tr('Crédit clients') : tr('Clients')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'client-add',
        onPressed: () async {
          final ok = await context.push<bool>(const ClientForm());
          if (ok == true) _list.currentState?.reload();
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(tr('Client')),
      ),
      body: PagedList<Json>(
        key: _list,
        searchHint: tr('Nom ou téléphone'),
        emptyIcon: Icons.people_outline,
        emptyTitle: _credit ? tr('Aucun crédit en cours') : tr('Aucun client'),
        emptyMessage: _credit ? tr('Tous les clients sont à jour de leurs paiements.') : null,
        filters: FilterChips<bool>(
          options: [(false, tr('Tous les clients')), (true, tr('Avec crédit'))],
          value: _credit,
          onChanged: (v) {
            setState(() => _credit = v ?? false);
            _list.currentState?.reload();
          },
        ),
        headerBuilder: (context, raw) {
          final s = raw.obj('stats');
          if (s == null) return null;
          return StatsRow(children: [
            MiniStat(label: tr('Clients'), value: qty(s['total'])),
            MiniStat(label: tr('Avec crédit'), value: qty(s['avec_credit']), color: AppColors.warning),
            MiniStat(label: tr('Crédit total'), value: moneyShort(s['credit_total']), color: AppColors.danger),
          ]);
        },
        fetch: (page, q) => api.page('m/clients', (j) => j, page: page, query: {'q': q, if (_credit) 'avec_credit': 1}),
        itemBuilder: (ctx, c, reload) => ListTile(
          leading: ItemThumb(label: c.str('nom'), color: AppColors.violet, size: 44),
          title: Row(children: [
            Flexible(child: Text(c.str('nom'), overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
            if (!c.flag('actif', true)) Padding(padding: const EdgeInsetsDirectional.only(start: 6), child: Badge2(tr('Inactif'))),
          ]),
          subtitle: Text(
            [
              c.strOrNull('telephone') ?? tr('Pas de téléphone'),
              if (c.str('type_client') == 'gros') tr('Gros'),
              c.integer('ventes_count') > 1 ? tr('{n} ventes', {'n': c.integer('ventes_count')}) : tr('{n} vente', {'n': c.integer('ventes_count')}),
            ].join(' · '),
            style: const TextStyle(fontSize: 12.5),
          ),
          trailing: c.dbl('solde') > 0
              ? Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(money(c['solde']), style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
                  Text(tr('crédit'), style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                ])
              : const Icon(Icons.chevron_right),
          onTap: () async {
            await ctx.push(ClientDetailScreen(clientId: c.integer('id')));
            reload();
          },
        ),
      ),
    );
  }
}

/// Encaissement d'un règlement client (POST paiements). Renvoie true si enregistré.
Future<bool> recordClientPayment(BuildContext context, Json client) async {
  final res = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ClientPaymentSheet(client: client),
  );
  return res ?? false;
}

class _ClientPaymentSheet extends StatefulWidget {
  const _ClientPaymentSheet({required this.client});

  final Json client;

  @override
  State<_ClientPaymentSheet> createState() => _ClientPaymentSheetState();
}

class _ClientPaymentSheetState extends State<_ClientPaymentSheet> {
  late final _amount = TextEditingController(text: priceInput(widget.client.dbl('solde')));
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
    final solde = widget.client.dbl('solde');
    if (solde > 0 && v > solde + 0.001) {
      final ok = await confirm(context, tr('Montant supérieur au crédit'),
          tr('Le montant ({montant}) dépasse le crédit ({credit}). Le client aura un solde en sa faveur. Continuer ?',
              {'montant': money(v), 'credit': money(solde)}));
      if (!ok || !mounted) return;
    }
    setState(() {
      _busy = true;
      _errors = {};
    });
    try {
      await context.api.post('paiements', {
        'client_id': widget.client.integer('id'),
        'montant': v,
        'mode': _mode,
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      });
      if (!mounted) return;
      showSuccess(context, tr('Règlement de {montant} enregistré.', {'montant': money(v)}));
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
    final c = widget.client;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(tr('Encaisser un règlement'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${c.str('nom')} · ${tr('crédit {montant}', {'montant': money(c['solde'])})}', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            decoration: InputDecoration(labelText: tr('Montant'), suffixText: tr('DH'), errorText: _errors['montant']?.first),
          ),
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
            label: Text(tr('Enregistrer le règlement')),
          ),
        ]),
      ),
    );
  }
}

/// Fiche client : coordonnées, crédit, historique des ventes et règlements.
class ClientDetailScreen extends StatefulWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final int clientId;

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  final _view = GlobalKey<AsyncViewState<Json>>();

  Future<void> _edit(Json c, Future<void> Function() reload) async {
    final ok = await context.push<bool>(ClientForm(client: c));
    if (ok == true) reload();
  }

  Future<void> _toggle(Json c, Future<void> Function() reload) async {
    final api = context.api;
    final actif = c.flag('actif', true);
    final ok = await confirm(
      context,
      actif ? tr('Désactiver le client') : tr('Activer le client'),
      actif
          ? tr('« {nom} » ne sera plus proposé en caisse. Son historique et son crédit sont conservés.', {'nom': c.str('nom')})
          : tr('« {nom} » sera de nouveau proposé en caisse.', {'nom': c.str('nom')}),
      ok: actif ? tr('Désactiver') : tr('Activer'),
      danger: actif,
    );
    if (!ok || !mounted) return;
    final res = await runBusy(context, () => api.put('clients/${widget.clientId}', {'actif': !actif}),
        success: actif ? tr('Client désactivé.') : tr('Client activé.'));
    if (res != null) reload();
  }

  Future<void> _delete(Json c, Future<void> Function() reload) async {
    final api = context.api;
    var deleted = false;
    final changed = await deleteWithFallback(
      context,
      what: tr('le client « {nom} »', {'nom': c.str('nom')}),
      delete: () async {
        await api.delete('clients/${widget.clientId}');
        deleted = true;
      },
      deactivate: c.flag('actif', true) ? () => api.put('clients/${widget.clientId}', {'actif': false}) : null,
      success: tr('Client supprimé.'),
      deactivated: tr('Client désactivé.'),
    );
    if (!changed || !mounted) return;
    if (deleted) {
      Navigator.of(context).pop(true);
    } else {
      reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: darkAppBar(tr('Fiche client')),
      body: AsyncView<Json>(
        key: _view,
        load: () async => (await context.api.get('clients/${widget.clientId}/history') as Map).cast<String, dynamic>(),
        builder: (context, d, reload) {
          final c = d.obj('client') ?? {};
          final ventes = d.list('ventes');
          final paiements = d.list('paiements');
          final solde = c.dbl('solde');
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.circular(20)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary,
                      child: Text(c.str('nom', '?').characters.first.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.str('nom'), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                        Text(
                          [c.str('type_client') == 'gros' ? tr('Client gros') : tr('Client détail'), if (!c.flag('actif', true)) tr('Désactivé')]
                              .join(' · '),
                          style: TextStyle(color: c.flag('actif', true) ? Colors.white60 : const Color(0xFFFCA5A5)),
                        ),
                      ]),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.white),
                      tooltip: tr('Modifier'),
                      onPressed: () => _edit(c, reload),
                    ),
                    PopupMenuButton<String>(
                      tooltip: tr('Actions'),
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (v) => switch (v) {
                        'edit' => _edit(c, reload),
                        'toggle' => _toggle(c, reload),
                        _ => _delete(c, reload),
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'edit', child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(tr('Modifier')))),
                        PopupMenuItem(
                          value: 'toggle',
                          child: ListTile(
                            leading: Icon(c.flag('actif', true) ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            title: Text(c.flag('actif', true) ? tr('Désactiver') : tr('Activer')),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                            title: Text(tr('Supprimer'), style: const TextStyle(color: AppColors.danger)),
                          ),
                        ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr('Crédit en cours'), style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
                        Text(money(solde),
                            style: TextStyle(
                                color: solde > 0 ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                                fontSize: 22,
                                fontWeight: FontWeight.w900)),
                      ]),
                    ),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr('Total des achats'), style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
                        Text(money(d['total_spent']), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  if (await recordClientPayment(context, c)) reload();
                },
                icon: const Icon(Icons.payments_outlined),
                label: Text(tr('Encaisser un règlement')),
              ),
              const SizedBox(height: 14),
              SectionCard(title: tr('Coordonnées'), icon: Icons.contact_phone_outlined, children: [
                InfoRow(tr('Téléphone'), c.str('telephone')),
                InfoRow(tr('E-mail'), c.str('email')),
                InfoRow(tr('Adresse'), c.str('adresse')),
              ]),
              GroupLabel(
                tr('Ventes ({n})', {'n': ventes.length}),
                trailing: ventes.isEmpty
                    ? null
                    : TextButton(
                        onPressed: () => context.push(SalesScreen(clientId: widget.clientId, clientName: c.str('nom'))),
                        child: Text(tr('Tout voir')),
                      ),
              ),
              if (ventes.isEmpty)
                Card(child: Padding(padding: const EdgeInsets.all(18), child: Text(tr('Aucune vente.'), style: const TextStyle(color: AppColors.muted))))
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    for (final (i, v) in ventes.take(15).indexed) ...[
                      if (i > 0) const Divider(height: 1, indent: 72),
                      SaleTile(sale: {...v, 'client': c}, onTap: () => context.push(SaleDetailScreen(saleId: v.integer('id')))),
                    ],
                  ]),
                ),
              GroupLabel(tr('Règlements ({n})', {'n': paiements.length})),
              if (paiements.isEmpty)
                Card(child: Padding(padding: const EdgeInsets.all(18), child: Text(tr('Aucun règlement.'), style: const TextStyle(color: AppColors.muted))))
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    for (final (i, p) in paiements.take(30).indexed) ...[
                      if (i > 0) const Divider(height: 1, indent: 72),
                      ListTile(
                        leading: IconSquare(PaymentModePicker.icon(p.str('mode')), color: AppColors.success),
                        title: Text(money(p['montant']), style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text([dateTime(p['created_at']), paymentModeLabel(p.strOrNull('mode')), ?p.strOrNull('note')].join(' · ')),
                      ),
                    ],
                  ]),
                ),
            ]),
          );
        },
      ),
    );
  }
}

/// Création / modification d'un client.
class ClientForm extends StatefulWidget {
  const ClientForm({super.key, this.client, this.returnClient = false});

  final Json? client;

  /// true : renvoie le client créé (Json) au lieu de true — utilisé par la caisse pour le sélectionner aussitôt.
  final bool returnClient;

  @override
  State<ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends State<ClientForm> {
  final _form = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.client?.str('nom'));
  late final _tel = TextEditingController(text: widget.client?.str('telephone'));
  late final _email = TextEditingController(text: widget.client?.str('email'));
  late final _adresse = TextEditingController(text: widget.client?.str('adresse'));
  late String _type = widget.client?.str('type_client', 'detail') ?? 'detail';
  late bool _actif = widget.client?.flag('actif', true) ?? true;
  bool _busy = false;
  Map<String, List<String>> _errors = {};

  @override
  void dispose() {
    for (final c in [_nom, _tel, _email, _adresse]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _errors = {};
    });
    final body = {
      'nom': _nom.text.trim(),
      'telephone': _tel.text.trim().isEmpty ? null : _tel.text.trim(),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      'adresse': _adresse.text.trim().isEmpty ? null : _adresse.text.trim(),
      'type_client': _type,
      'actif': _actif,
    };
    try {
      final dynamic saved = widget.client == null
          ? await context.api.post('clients', body)
          : await context.api.put('clients/${widget.client!.integer('id')}', body);
      if (!mounted) return;
      showSuccess(context, widget.client == null ? tr('Client créé.') : tr('Client modifié.'));
      Navigator.pop(context, widget.returnClient && saved is Map ? saved.cast<String, dynamic>() : true);
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
      appBar: darkAppBar(widget.client == null ? tr('Nouveau client') : tr('Modifier le client')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(
            controller: _nom,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: tr('Nom *'), prefixIcon: const Icon(Icons.person_outline), errorText: _errors['nom']?.first),
            validator: (v) => (v == null || v.trim().isEmpty) ? tr('Le nom est obligatoire.') : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _tel,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: tr('Téléphone (facultatif)'),
              helperText: tr('Un numéro ne peut appartenir qu’à un seul client.'),
              prefixIcon: const Icon(Icons.phone_outlined),
              errorText: _errors['telephone']?.first,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: tr('E-mail (facultatif)'), prefixIcon: const Icon(Icons.mail_outline), errorText: _errors['email']?.first),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _adresse,
            maxLines: 2,
            decoration: InputDecoration(labelText: tr('Adresse'), prefixIcon: const Icon(Icons.place_outlined)),
          ),
          const SizedBox(height: 16),
          Text(tr('Type de client'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'detail', label: Text(tr('Détail')), icon: const Icon(Icons.person)),
              ButtonSegment(value: 'gros', label: Text(tr('Gros')), icon: const Icon(Icons.store)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          if (widget.client != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('Client actif')),
              value: _actif,
              activeThumbColor: AppColors.primary,
              onChanged: (v) => setState(() => _actif = v),
            ),
        ]),
      ),
      bottomNavigationBar: BottomAction(label: tr('Enregistrer'), busy: _busy, onPressed: _save),
    );
  }
}

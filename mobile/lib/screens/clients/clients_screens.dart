import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/article.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
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
      appBar: darkAppBar(widget.creditOnly ? 'Crédit clients' : 'Clients'),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'client-add',
        onPressed: () async {
          final ok = await context.push<bool>(const ClientForm());
          if (ok == true) _list.currentState?.reload();
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Client'),
      ),
      body: PagedList<Json>(
        key: _list,
        searchHint: 'Nom ou téléphone',
        emptyIcon: Icons.people_outline,
        emptyTitle: _credit ? 'Aucun crédit en cours' : 'Aucun client',
        emptyMessage: _credit ? 'Tous les clients sont à jour de leurs paiements.' : null,
        filters: FilterChips<bool>(
          options: const [(false, 'Tous les clients'), (true, 'Avec crédit')],
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
            MiniStat(label: 'Clients', value: qty(s['total'])),
            MiniStat(label: 'Avec crédit', value: qty(s['avec_credit']), color: AppColors.warning),
            MiniStat(label: 'Crédit total', value: moneyShort(s['credit_total']), color: AppColors.danger),
          ]);
        },
        fetch: (page, q) => api.page('m/clients', (j) => j, page: page, query: {'q': q, if (_credit) 'avec_credit': 1}),
        itemBuilder: (ctx, c, reload) => ListTile(
          leading: ItemThumb(label: c.str('nom'), color: AppColors.violet, size: 44),
          title: Text(c.str('nom'), style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            [
              c.strOrNull('telephone') ?? 'Pas de téléphone',
              if (c.str('type_client') == 'gros') 'Gros',
              '${c.integer('ventes_count')} vente${c.integer('ventes_count') > 1 ? 's' : ''}',
            ].join(' · '),
            style: const TextStyle(fontSize: 12.5),
          ),
          trailing: c.dbl('solde') > 0
              ? Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(money(c['solde']), style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
                  const Text('crédit', style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
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
      setState(() => _errors = {'montant': ['Saisissez un montant supérieur à 0.']});
      return;
    }
    final solde = widget.client.dbl('solde');
    if (solde > 0 && v > solde + 0.001) {
      final ok = await confirm(context, 'Montant supérieur au crédit',
          'Le montant (${money(v)}) dépasse le crédit (${money(solde)}). Le client aura un solde en sa faveur. Continuer ?');
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
      showSuccess(context, 'Règlement de ${money(v)} enregistré.');
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
          const Text('Encaisser un règlement', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${c.str('nom')} · crédit ${money(c['solde'])}', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            decoration: InputDecoration(labelText: 'Montant', suffixText: 'DH', errorText: _errors['montant']?.first),
          ),
          const SizedBox(height: 12),
          PaymentModePicker(value: _mode, onChanged: (m) => setState(() => _mode = m)),
          const SizedBox(height: 12),
          TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note (facultatif)')),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: const Text('Enregistrer le règlement'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: darkAppBar('Fiche client'),
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
                        Text(c.str('type_client') == 'gros' ? 'Client gros' : 'Client détail', style: const TextStyle(color: Colors.white60)),
                      ]),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.white),
                      tooltip: 'Modifier',
                      onPressed: () async {
                        final ok = await context.push<bool>(ClientForm(client: c));
                        if (ok == true) reload();
                      },
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Crédit en cours', style: TextStyle(color: Colors.white60, fontSize: 12.5)),
                        Text(money(solde),
                            style: TextStyle(
                                color: solde > 0 ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                                fontSize: 22,
                                fontWeight: FontWeight.w900)),
                      ]),
                    ),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Total des achats', style: TextStyle(color: Colors.white60, fontSize: 12.5)),
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
                label: const Text('Encaisser un règlement'),
              ),
              const SizedBox(height: 14),
              SectionCard(title: 'Coordonnées', icon: Icons.contact_phone_outlined, children: [
                InfoRow('Téléphone', c.str('telephone')),
                InfoRow('E-mail', c.str('email')),
                InfoRow('Adresse', c.str('adresse')),
              ]),
              GroupLabel(
                'Ventes (${ventes.length})',
                trailing: ventes.isEmpty
                    ? null
                    : TextButton(
                        onPressed: () => context.push(SalesScreen(clientId: widget.clientId, clientName: c.str('nom'))),
                        child: const Text('Tout voir'),
                      ),
              ),
              if (ventes.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('Aucune vente.', style: TextStyle(color: AppColors.muted))))
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
              GroupLabel('Règlements (${paiements.length})'),
              if (paiements.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('Aucun règlement.', style: TextStyle(color: AppColors.muted))))
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
  const ClientForm({super.key, this.client});

  final Json? client;

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
      if (widget.client == null) {
        await context.api.post('clients', body);
      } else {
        await context.api.put('clients/${widget.client!.integer('id')}', body);
      }
      if (!mounted) return;
      showSuccess(context, widget.client == null ? 'Client créé.' : 'Client modifié.');
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
    return Scaffold(
      appBar: darkAppBar(widget.client == null ? 'Nouveau client' : 'Modifier le client'),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(
            controller: _nom,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: 'Nom *', prefixIcon: const Icon(Icons.person_outline), errorText: _errors['nom']?.first),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Le nom est obligatoire.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _tel,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: 'Téléphone', prefixIcon: const Icon(Icons.phone_outlined), errorText: _errors['telephone']?.first),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: 'E-mail', prefixIcon: const Icon(Icons.mail_outline), errorText: _errors['email']?.first),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _adresse,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Adresse', prefixIcon: Icon(Icons.place_outlined)),
          ),
          const SizedBox(height: 16),
          const Text('Type de client', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'detail', label: Text('Détail'), icon: Icon(Icons.person)),
              ButtonSegment(value: 'gros', label: Text('Gros'), icon: Icon(Icons.store)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          if (widget.client != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Client actif'),
              value: _actif,
              activeThumbColor: AppColors.primary,
              onChanged: (v) => setState(() => _actif = v),
            ),
        ]),
      ),
      bottomNavigationBar: BottomAction(label: 'Enregistrer', busy: _busy, onPressed: _save),
    );
  }
}

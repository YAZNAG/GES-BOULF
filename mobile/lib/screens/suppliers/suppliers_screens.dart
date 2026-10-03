import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/article.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';
import '../../widgets/pickers.dart';
import '../purchases/orders_screens.dart';
import '../purchases/receipts_screens.dart';

const supplierPaymentModes = [...paymentModes, ('effet', 'Effet')];

/// Liste des fournisseurs (option : uniquement ceux à régler).
class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key, this.creditOnly = false});

  final bool creditOnly;

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _list = GlobalKey<PagedListState<Json>>();
  late bool _credit = widget.creditOnly;

  @override
  Widget build(BuildContext context) {
    final api = context.api;
    return Scaffold(
      appBar: darkAppBar(widget.creditOnly ? 'Crédit fournisseurs' : 'Fournisseurs', actions: [
        IconButton(
          tooltip: 'Historique des paiements',
          icon: const Icon(Icons.history),
          onPressed: () => context.push(const SupplierPaymentsScreen()),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'supplier-add',
        onPressed: () async {
          final ok = await context.push<bool>(const SupplierForm());
          if (ok == true) _list.currentState?.reload();
        },
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Fournisseur'),
      ),
      body: PagedList<Json>(
        key: _list,
        searchHint: 'Nom, téléphone, ville…',
        emptyIcon: Icons.local_shipping_outlined,
        emptyTitle: _credit ? 'Aucun crédit fournisseur' : 'Aucun fournisseur',
        emptyMessage: _credit ? 'Tous les fournisseurs sont réglés.' : null,
        filters: FilterChips<bool>(
          options: const [(false, 'Tous'), (true, 'À régler')],
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
            MiniStat(label: 'Fournisseurs', value: qty(s['total'])),
            MiniStat(label: 'À régler', value: qty(s['avec_credit']), color: AppColors.warning),
            MiniStat(label: 'Crédit total', value: moneyShort(s['credit_total']), color: AppColors.danger),
          ]);
        },
        fetch: (page, q) => api.page('fournisseurs', (j) => j, page: page, query: {'q': q, if (_credit) 'avec_credit': 1}),
        itemBuilder: (ctx, f, reload) {
          final plafond = f.dblOrNull('plafond_credit');
          final over = plafond != null && plafond > 0 && f.dbl('solde') > plafond;
          return ListTile(
            leading: ItemThumb(label: f.str('nom'), color: AppColors.info, size: 44),
            title: Text(f.str('nom'), style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              [
                ?f.strOrNull('ville'),
                ?f.strOrNull('telephone'),
                '${f.integer('receptions_count')} réception${f.integer('receptions_count') > 1 ? 's' : ''}',
              ].join(' · '),
              style: const TextStyle(fontSize: 12.5),
            ),
            trailing: f.dbl('solde') > 0
                ? Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(money(f['solde']), style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
                    Text(over ? 'plafond dépassé' : 'à régler',
                        style: TextStyle(fontSize: 11.5, color: over ? AppColors.danger : AppColors.muted, fontWeight: over ? FontWeight.w700 : null)),
                  ])
                : const Icon(Icons.chevron_right),
            onTap: () async {
              await ctx.push(SupplierDetailScreen(supplierId: f.integer('id')));
              reload();
            },
          );
        },
      ),
    );
  }
}

/// Règlement d'un fournisseur (POST achats/paiements). Renvoie true si enregistré.
Future<bool> paySupplier(BuildContext context, Json supplier, {Json? reception}) async {
  final res = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SupplierPaymentSheet(supplier: supplier, reception: reception),
  );
  return res ?? false;
}

class _SupplierPaymentSheet extends StatefulWidget {
  const _SupplierPaymentSheet({required this.supplier, this.reception});

  final Json supplier;
  final Json? reception;

  @override
  State<_SupplierPaymentSheet> createState() => _SupplierPaymentSheetState();
}

class _SupplierPaymentSheetState extends State<_SupplierPaymentSheet> {
  late final _amount = TextEditingController(
      text: priceInput(widget.reception != null ? widget.reception!.dbl('reste') : widget.supplier.dbl('solde')));
  final _ref = TextEditingController();
  final _note = TextEditingController();
  String _mode = 'especes';
  String? _date = apiDate(DateTime.now());
  bool _busy = false;
  Map<String, List<String>> _errors = {};

  @override
  void dispose() {
    _amount.dispose();
    _ref.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = parseInput(_amount.text);
    if (v == null || v <= 0) {
      setState(() => _errors = {'montant': ['Saisissez un montant supérieur à 0.']});
      return;
    }
    setState(() {
      _busy = true;
      _errors = {};
    });
    try {
      await context.api.post('achats/paiements', {
        'fournisseur_id': widget.supplier.integer('id'),
        'montant': v,
        'mode': _mode,
        'date_paiement': _date,
        if (_ref.text.trim().isNotEmpty) 'reference': _ref.text.trim(),
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
        if (widget.reception != null) 'reception_id': widget.reception!.integer('id'),
      });
      if (!mounted) return;
      showSuccess(context, 'Paiement de ${money(v)} enregistré.');
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
    final s = widget.supplier;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          const Text('Régler le fournisseur', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            widget.reception != null
                ? '${s.str('nom')} · ${widget.reception!.str('numero')} (reste ${money(widget.reception!['reste'])})'
                : '${s.str('nom')} · crédit ${money(s['solde'])}',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            decoration: InputDecoration(labelText: 'Montant', suffixText: 'DH', errorText: _errors['montant']?.first),
          ),
          const SizedBox(height: 12),
          PaymentModePicker(value: _mode, modes: supplierPaymentModes, onChanged: (m) => setState(() => _mode = m)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: DateField(label: 'Date', value: _date, onChanged: (v) => setState(() => _date = v))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _ref, decoration: const InputDecoration(labelText: 'Référence', hintText: 'N° chèque…'))),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note (facultatif)')),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: const Text('Enregistrer le paiement'),
          ),
        ]),
      ),
    );
  }
}

/// Fiche fournisseur : crédit, achats, actions (régler, relevé, documents).
class SupplierDetailScreen extends StatelessWidget {
  const SupplierDetailScreen({super.key, required this.supplierId});

  final int supplierId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: darkAppBar('Fiche fournisseur'),
      body: AsyncView<Json>(
        load: () async => (await context.api.get('fournisseurs/$supplierId') as Map).cast<String, dynamic>(),
        builder: (context, f, reload) {
          final solde = f.dbl('solde');
          final plafond = f.dblOrNull('plafond_credit');
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.circular(20)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.info,
                      child: Icon(Icons.local_shipping, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(f.str('nom'), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                        Text([?f.strOrNull('code'), ?f.strOrNull('ville')].join(' · '), style: const TextStyle(color: Colors.white60)),
                      ]),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.white),
                      tooltip: 'Modifier',
                      onPressed: () async {
                        final ok = await context.push<bool>(SupplierForm(supplier: f));
                        if (ok == true) reload();
                      },
                    ),
                  ]),
                  const SizedBox(height: 16),
                  const Text('Crédit (à régler)', style: TextStyle(color: Colors.white60, fontSize: 12.5)),
                  Text(money(solde),
                      style: TextStyle(color: solde > 0 ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC), fontSize: 26, fontWeight: FontWeight.w900)),
                  if (plafond != null && plafond > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (solde / plafond).clamp(0, 1).toDouble(),
                        minHeight: 6,
                        backgroundColor: Colors.white12,
                        color: solde > plafond ? AppColors.danger : const Color(0xFFFBBF24),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Plafond ${money(plafond)}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      if (await paySupplier(context, f)) reload();
                    },
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Régler'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(64, 50)),
                    onPressed: () => context.push(SupplierStatementScreen(supplierId: supplierId, name: f.str('nom'))),
                    icon: const Icon(Icons.summarize_outlined),
                    label: const Text('Relevé'),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: MiniStat(label: 'Total achats', value: moneyShort(f['total_achats']))),
                const SizedBox(width: 8),
                Expanded(child: MiniStat(label: 'Total payé', value: moneyShort(f['total_paye']), color: AppColors.success)),
              ]),
              const SizedBox(height: 14),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  ListTile(
                    leading: const IconSquare(Icons.receipt_long_outlined, color: AppColors.info),
                    title: const Text('Bons de commande', style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(qty(f['commandes_count']), style: const TextStyle(color: AppColors.muted)),
                      const Icon(Icons.chevron_right),
                    ]),
                    onTap: () => context.push(OrdersScreen(supplierId: supplierId, supplierName: f.str('nom'))),
                  ),
                  const Divider(height: 1, indent: 72),
                  ListTile(
                    leading: const IconSquare(Icons.move_to_inbox_outlined, color: AppColors.success),
                    title: const Text('Bons de réception', style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(qty(f['receptions_count']), style: const TextStyle(color: AppColors.muted)),
                      const Icon(Icons.chevron_right),
                    ]),
                    onTap: () => context.push(ReceiptsScreen(supplierId: supplierId, supplierName: f.str('nom'))),
                  ),
                  const Divider(height: 1, indent: 72),
                  ListTile(
                    leading: const IconSquare(Icons.history, color: AppColors.violet),
                    title: const Text('Paiements', style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(SupplierPaymentsScreen(supplierId: supplierId, supplierName: f.str('nom'))),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              SectionCard(title: 'Coordonnées', icon: Icons.contact_phone_outlined, children: [
                InfoRow('Contact', f.str('contact')),
                InfoRow('Téléphone', f.str('telephone')),
                InfoRow('E-mail', f.str('email')),
                InfoRow('Adresse', f.str('adresse')),
                InfoRow('ICE', f.str('ice')),
                InfoRow('RC', f.str('rc')),
                InfoRow('Délai de paiement', f.intOrNull('delai_paiement') == null ? '' : '${f.integer('delai_paiement')} jours'),
                if (f.strOrNull('note') != null) InfoRow('Note', f.str('note')),
              ]),
            ]),
          );
        },
      ),
    );
  }
}

/// Relevé de compte fournisseur (réceptions / paiements, solde cumulé).
class SupplierStatementScreen extends StatelessWidget {
  const SupplierStatementScreen({super.key, required this.supplierId, required this.name});

  final int supplierId;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: darkAppBar('Relevé', subtitle: name),
      body: AsyncView<Json>(
        load: () async => (await context.api.get('achats/fournisseurs/$supplierId/releve') as Map).cast<String, dynamic>(),
        builder: (context, d, reload) {
          final lignes = d.list('lignes');
          final debit = lignes.fold<double>(0, (t, l) => t + l.dbl('debit'));
          final credit = lignes.fold<double>(0, (t, l) => t + l.dbl('credit'));
          final solde = lignes.isEmpty ? (d.obj('fournisseur')?.dbl('solde') ?? 0) : lignes.last.dbl('solde');
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
              StatsRow(children: [
                MiniStat(label: 'Achats (débit)', value: moneyShort(debit)),
                MiniStat(label: 'Payé (crédit)', value: moneyShort(credit), color: AppColors.success),
                MiniStat(label: 'Solde', value: moneyShort(solde), color: solde > 0 ? AppColors.danger : AppColors.success),
              ]),
              const SizedBox(height: 8),
              if (lignes.isEmpty)
                const SizedBox(height: 300, child: EmptyState(icon: Icons.summarize_outlined, title: 'Aucun mouvement'))
              else
                for (final l in lignes.reversed)
                  Container(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 1),
                    child: ListTile(
                      leading: IconSquare(
                        l.str('type') == 'paiement' ? Icons.payments_outlined : Icons.move_to_inbox_outlined,
                        color: l.str('type') == 'paiement' ? AppColors.success : AppColors.info,
                      ),
                      title: Text(l.str('libelle'), maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text('${date(l['date'])} · solde ${money(l['solde'])}'),
                      trailing: Text(
                        l.dbl('debit') > 0 ? '+ ${money(l['debit'])}' : '− ${money(l['credit'])}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: l.dbl('debit') > 0 ? AppColors.danger : AppColors.success,
                        ),
                      ),
                    ),
                  ),
            ]),
          );
        },
      ),
    );
  }
}

/// Historique des paiements fournisseurs (GET achats/paiements).
class SupplierPaymentsScreen extends StatelessWidget {
  const SupplierPaymentsScreen({super.key, this.supplierId, this.supplierName});

  final int? supplierId;
  final String? supplierName;

  @override
  Widget build(BuildContext context) {
    final api = context.api;
    return Scaffold(
      appBar: darkAppBar('Paiements fournisseurs', subtitle: supplierName),
      body: PagedList<Json>(
        showSearch: false,
        emptyIcon: Icons.payments_outlined,
        emptyTitle: 'Aucun paiement',
        fetch: (page, q) => api.page('achats/paiements', (j) => j, page: page, query: {'fournisseur_id': supplierId}),
        itemBuilder: (ctx, p, _) => ListTile(
          leading: IconSquare(PaymentModePicker.icon(p.str('mode')), color: AppColors.success),
          title: Text(p.obj('fournisseur')?.str('nom') ?? '—', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            [
              date(p['date_paiement']),
              paymentModeLabel(p.strOrNull('mode')),
              ?p.strOrNull('reference'),
              if (p.obj('reception') != null) p.obj('reception')!.str('numero'),
            ].join(' · '),
            style: const TextStyle(fontSize: 12.5),
          ),
          trailing: Text(money(p['montant']), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.success)),
        ),
      ),
    );
  }
}

/// Création / modification d'un fournisseur (le solde n'est pas modifiable).
class SupplierForm extends StatefulWidget {
  const SupplierForm({super.key, this.supplier});

  final Json? supplier;

  @override
  State<SupplierForm> createState() => _SupplierFormState();
}

class _SupplierFormState extends State<SupplierForm> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c = {
    for (final k in ['code', 'nom', 'contact', 'telephone', 'email', 'adresse', 'ville', 'ice', 'rc', 'note'])
      k: TextEditingController(text: widget.supplier?.str(k)),
    'plafond_credit': TextEditingController(text: priceInput(widget.supplier?['plafond_credit'])),
    'delai_paiement': TextEditingController(text: widget.supplier?.strOrNull('delai_paiement') ?? ''),
  };
  late bool _actif = widget.supplier?.flag('actif', true) ?? true;
  bool _busy = false;
  Map<String, List<String>> _errors = {};

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _v(String k) => _c[k]!.text.trim().isEmpty ? null : _c[k]!.text.trim();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _errors = {};
    });
    final body = {
      for (final k in ['code', 'nom', 'contact', 'telephone', 'email', 'adresse', 'ville', 'ice', 'rc', 'note']) k: _v(k),
      'plafond_credit': parseInput(_c['plafond_credit']!.text),
      'delai_paiement': int.tryParse(_c['delai_paiement']!.text.trim()),
      'actif': _actif,
    };
    try {
      if (widget.supplier == null) {
        await context.api.post('fournisseurs', body);
      } else {
        await context.api.put('fournisseurs/${widget.supplier!.integer('id')}', body);
      }
      if (!mounted) return;
      showSuccess(context, widget.supplier == null ? 'Fournisseur créé.' : 'Fournisseur modifié.');
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

  Widget _field(String k, String label, {IconData? icon, TextInputType? type, int lines = 1, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _c[k],
        keyboardType: type,
        maxLines: lines,
        validator: validator,
        decoration: InputDecoration(labelText: label, prefixIcon: icon == null ? null : Icon(icon), errorText: _errors[k]?.first),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: darkAppBar(widget.supplier == null ? 'Nouveau fournisseur' : 'Modifier le fournisseur'),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _field('nom', 'Nom *', icon: Icons.business_outlined,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Le nom est obligatoire.' : null),
          Row(children: [
            Expanded(child: _field('code', 'Code')),
            const SizedBox(width: 10),
            Expanded(child: _field('ville', 'Ville')),
          ]),
          _field('contact', 'Personne à contacter', icon: Icons.person_outline),
          _field('telephone', 'Téléphone', icon: Icons.phone_outlined, type: TextInputType.phone),
          _field('email', 'E-mail', icon: Icons.mail_outline, type: TextInputType.emailAddress),
          _field('adresse', 'Adresse', icon: Icons.place_outlined, lines: 2),
          Row(children: [
            Expanded(child: _field('ice', 'ICE')),
            const SizedBox(width: 10),
            Expanded(child: _field('rc', 'RC')),
          ]),
          Row(children: [
            Expanded(child: _field('plafond_credit', 'Plafond crédit (DH)', type: const TextInputType.numberWithOptions(decimal: true))),
            const SizedBox(width: 10),
            Expanded(child: _field('delai_paiement', 'Délai (jours)', type: TextInputType.number)),
          ]),
          _field('note', 'Note', lines: 2),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fournisseur actif'),
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

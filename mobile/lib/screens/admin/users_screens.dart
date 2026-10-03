import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';
import '../../widgets/pickers.dart';

String roleLabel(String r) => switch (r.toLowerCase()) {
      'admin' => 'Administrateur',
      'vendeur' => 'Vendeur',
      'magasinier' => 'Magasinier',
      'agent' => 'Agent',
      'livreur' => 'Livreur',
      '' => '—',
      _ => r[0].toUpperCase() + r.substring(1),
    };

/// Utilisateurs : liste, création, activation / désactivation.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _list = GlobalKey<PagedListState<Json>>();

  Future<void> _toggle(Json u, VoidCallback reload) async {
    final api = context.api;
    final actif = u.flag('actif', true);
    final name = [u.str('prenom'), u.str('nom')].where((e) => e.isNotEmpty).join(' ');
    final ok = await confirm(
      context,
      actif ? 'Désactiver le compte' : 'Activer le compte',
      actif ? '$name ne pourra plus se connecter.' : '$name pourra de nouveau se connecter.',
      ok: actif ? 'Désactiver' : 'Activer',
      danger: actif,
    );
    if (!ok || !mounted) return;
    final res = await runBusy(context, () => api.put('utilisateurs/${u.integer('id')}', {'actif': !actif}),
        success: actif ? 'Compte désactivé.' : 'Compte activé.');
    if (res != null) reload();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.api;
    final me = context.session.user?.integer('id');
    return Scaffold(
      appBar: darkAppBar('Utilisateurs'),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'user-add',
        onPressed: () async {
          final ok = await context.push<bool>(const UserForm());
          if (ok == true) _list.currentState?.reload();
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Utilisateur'),
      ),
      body: PagedList<Json>(
        key: _list,
        showSearch: false,
        emptyIcon: Icons.people_outline,
        emptyTitle: 'Aucun utilisateur',
        fetch: (page, q) => api.page('utilisateurs', (j) => j, page: page),
        itemBuilder: (ctx, u, reload) {
          final name = [u.str('prenom'), u.str('nom')].where((e) => e.isNotEmpty).join(' ');
          final actif = u.flag('actif', true);
          final role = u.obj('role')?.str('nom') ?? '';
          return ListTile(
            leading: ItemThumb(label: name, color: actif ? AppColors.info : AppColors.muted, size: 44),
            title: Row(children: [
              Flexible(child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
              if (u.integer('id') == me) const Padding(padding: EdgeInsets.only(left: 6), child: Badge2('Vous', color: AppColors.primary)),
            ]),
            subtitle: Text('${u.str('email')}\n${roleLabel(role)}', style: const TextStyle(fontSize: 12.5)),
            isThreeLine: true,
            trailing: Switch(
              value: actif,
              activeThumbColor: AppColors.success,
              onChanged: u.integer('id') == me ? null : (_) => _toggle(u, reload),
            ),
            onTap: () async {
              final ok = await ctx.push<bool>(UserForm(user: u));
              if (ok == true) reload();
            },
          );
        },
      ),
    );
  }
}

/// Création / modification d'un utilisateur.
class UserForm extends StatefulWidget {
  const UserForm({super.key, this.user});

  final Json? user;

  @override
  State<UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<UserForm> {
  final _form = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.user?.str('nom'));
  late final _prenom = TextEditingController(text: widget.user?.str('prenom'));
  late final _email = TextEditingController(text: widget.user?.str('email'));
  final _password = TextEditingController();
  late int? _roleId = widget.user?.intOrNull('role_id') ?? widget.user?.obj('role')?.intOrNull('id');
  late bool _actif = widget.user?.flag('actif', true) ?? true;
  bool _obscure = true;
  bool _busy = false;
  Map<String, List<String>> _errors = {};

  bool get _isNew => widget.user == null;

  @override
  void dispose() {
    for (final c in [_nom, _prenom, _email, _password]) {
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
      'role_id': _roleId,
      'nom': _nom.text.trim(),
      'prenom': _prenom.text.trim().isEmpty ? null : _prenom.text.trim(),
      'email': _email.text.trim(),
      if (_password.text.isNotEmpty) 'mot_de_passe': _password.text,
      'actif': _actif,
    };
    try {
      if (_isNew) {
        await context.api.post('utilisateurs', body);
      } else {
        await context.api.put('utilisateurs/${widget.user!.integer('id')}', body);
      }
      if (!mounted) return;
      showSuccess(context, _isNew ? 'Utilisateur créé.' : 'Utilisateur modifié.');
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
      appBar: darkAppBar(_isNew ? 'Nouvel utilisateur' : 'Modifier l’utilisateur'),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _prenom,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: 'Prénom', errorText: _errors['prenom']?.first),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _nom,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: 'Nom *', errorText: _errors['nom']?.first),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire.' : null,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: 'E-mail *', prefixIcon: const Icon(Icons.mail_outline), errorText: _errors['email']?.first),
            validator: (v) => (v == null || !v.contains('@')) ? 'Adresse e-mail invalide.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: _isNew ? 'Mot de passe *' : 'Nouveau mot de passe (facultatif)',
              prefixIcon: const Icon(Icons.lock_outline),
              errorText: _errors['mot_de_passe']?.first,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) {
              if (_isNew && (v == null || v.length < 6)) return '6 caractères minimum.';
              if (!_isNew && v != null && v.isNotEmpty && v.length < 6) return '6 caractères minimum.';
              return null;
            },
          ),
          const SizedBox(height: 12),
          RefDropdown(
            label: 'Rôle *',
            path: 'roles',
            prefixIcon: Icons.badge_outlined,
            value: _roleId,
            itemLabel: (r) => roleLabel(r.str('nom')),
            onChanged: (v) => setState(() => _roleId = v),
            validator: (v) => v == null ? 'Choisissez un rôle.' : null,
          ),
          if (_errors['role_id'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 12),
              child: Text(_errors['role_id']!.first, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Compte actif'),
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

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/delete_helper.dart';
import '../../widgets/paged_list.dart';
import '../../widgets/pickers.dart';
import 'user_profile_screen.dart';

String roleLabel(String r) => switch (r.toLowerCase()) {
      'admin' => tr('Administrateur'),
      'vendeur' => tr('Vendeur'),
      'magasinier' => tr('Magasinier'),
      'agent' => tr('Agent'),
      'livreur' => tr('Livreur'),
      '' => '—',
      _ => r[0].toUpperCase() + r.substring(1),
    };

String userFullName(Json u) => [u.str('prenom'), u.str('nom')].where((e) => e.isNotEmpty).join(' ');

/// Active / désactive un compte utilisateur (avec confirmation). Renvoie true si modifié.
Future<bool> toggleUserActive(BuildContext context, Json u) async {
  final api = context.api;
  final actif = u.flag('actif', true);
  final name = userFullName(u);
  final ok = await confirm(
    context,
    actif ? tr('Désactiver le compte') : tr('Activer le compte'),
    actif ? tr('{nom} ne pourra plus se connecter.', {'nom': name}) : tr('{nom} pourra de nouveau se connecter.', {'nom': name}),
    ok: actif ? tr('Désactiver') : tr('Activer'),
    danger: actif,
  );
  if (!ok || !context.mounted) return false;
  final res = await runBusy(context, () => api.put('utilisateurs/${u.integer('id')}', {'actif': !actif}),
      success: actif ? tr('Compte désactivé.') : tr('Compte activé.'));
  return res != null;
}

/// Supprime un utilisateur ; s'il a un historique, propose de le désactiver.
/// Renvoie 'deleted', 'deactivated' ou null.
Future<String?> deleteUser(BuildContext context, Json u) async {
  final api = context.api;
  final id = u.integer('id');
  var deleted = false;
  final changed = await deleteWithFallback(
    context,
    what: tr('le compte de {nom}', {'nom': userFullName(u)}),
    delete: () async {
      await api.delete('utilisateurs/$id');
      deleted = true;
    },
    deactivate: u.flag('actif', true) ? () => api.put('utilisateurs/$id', {'actif': false}) : null,
    success: tr('Utilisateur supprimé.'),
    deactivated: tr('Compte désactivé.'),
  );
  if (!changed) return null;
  return deleted ? 'deleted' : 'deactivated';
}

/// Utilisateurs : liste, création, activation / désactivation.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _list = GlobalKey<PagedListState<Json>>();

  Future<void> _toggle(Json u, VoidCallback reload) async {
    if (await toggleUserActive(context, u)) reload();
  }

  Future<void> _actions(BuildContext ctx, Json u, VoidCallback reload, bool isMe) async {
    final actif = u.flag('actif', true);
    final action = await showModalBottomSheet<String>(
      context: ctx,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(userFullName(u), style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(u.str('email'))),
          ListTile(leading: const Icon(Icons.person_outline), title: Text(tr('Voir le profil')), onTap: () => Navigator.pop(c, 'view')),
          ListTile(leading: const Icon(Icons.edit_outlined), title: Text(tr('Modifier')), onTap: () => Navigator.pop(c, 'edit')),
          if (!isMe)
            ListTile(
              leading: Icon(actif ? Icons.block : Icons.check_circle_outline),
              title: Text(actif ? tr('Désactiver le compte') : tr('Activer le compte')),
              onTap: () => Navigator.pop(c, 'toggle'),
            ),
          if (!isMe)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: Text(tr('Supprimer'), style: const TextStyle(color: AppColors.danger)),
              onTap: () => Navigator.pop(c, 'delete'),
            ),
        ]),
      ),
    );
    if (action == null || !ctx.mounted) return;
    switch (action) {
      case 'view':
        await ctx.push(UserProfileScreen(userId: u.integer('id'), self: isMe));
        reload();
      case 'edit':
        final ok = await ctx.push<bool>(UserForm(user: u));
        if (ok == true) reload();
      case 'toggle':
        _toggle(u, reload);
      case 'delete':
        if (await deleteUser(ctx, u) != null) reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.api;
    final me = context.session.user?.integer('id');
    return Scaffold(
      appBar: darkAppBar(tr('Utilisateurs')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'user-add',
        onPressed: () async {
          final ok = await context.push<bool>(const UserForm());
          if (ok == true) _list.currentState?.reload();
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(tr('Utilisateur')),
      ),
      body: PagedList<Json>(
        key: _list,
        showSearch: false,
        emptyIcon: Icons.people_outline,
        emptyTitle: tr('Aucun utilisateur'),
        fetch: (page, q) => api.page('utilisateurs', (j) => j, page: page),
        itemBuilder: (ctx, u, reload) {
          final name = [u.str('prenom'), u.str('nom')].where((e) => e.isNotEmpty).join(' ');
          final actif = u.flag('actif', true);
          final role = u.obj('role')?.str('nom') ?? '';
          return ListTile(
            leading: ItemThumb(label: name, color: actif ? AppColors.info : AppColors.muted, size: 44),
            title: Row(children: [
              Flexible(child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
              if (u.integer('id') == me) Padding(padding: const EdgeInsetsDirectional.only(start: 6), child: Badge2(tr('Vous'), color: AppColors.primary)),
            ]),
            subtitle: Text('${u.str('email')}\n${roleLabel(role)}', style: const TextStyle(fontSize: 12.5)),
            isThreeLine: true,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Switch(
                value: actif,
                activeThumbColor: AppColors.success,
                onChanged: u.integer('id') == me ? null : (_) => _toggle(u, reload),
              ),
              IconButton(
                tooltip: tr('Actions'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.more_vert),
                onPressed: () => _actions(ctx, u, reload, u.integer('id') == me),
              ),
            ]),
            onTap: () async {
              await ctx.push(UserProfileScreen(userId: u.integer('id'), self: u.integer('id') == me));
              reload();
            },
            onLongPress: () => _actions(ctx, u, reload, u.integer('id') == me),
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
      showSuccess(context, _isNew ? tr('Utilisateur créé.') : tr('Utilisateur modifié.'));
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
      appBar: darkAppBar(_isNew ? tr('Nouvel utilisateur') : tr('Modifier l’utilisateur')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _prenom,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: tr('Prénom'), errorText: _errors['prenom']?.first),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _nom,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: tr('Nom *'), errorText: _errors['nom']?.first),
                validator: (v) => (v == null || v.trim().isEmpty) ? tr('Obligatoire.') : null,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: tr('E-mail *'), prefixIcon: const Icon(Icons.mail_outline), errorText: _errors['email']?.first),
            validator: (v) => (v == null || !v.contains('@')) ? tr('Adresse e-mail invalide.') : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: _isNew ? tr('Mot de passe *') : tr('Nouveau mot de passe (facultatif)'),
              prefixIcon: const Icon(Icons.lock_outline),
              errorText: _errors['mot_de_passe']?.first,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) {
              if (_isNew && (v == null || v.length < 6)) return tr('6 caractères minimum.');
              if (!_isNew && v != null && v.isNotEmpty && v.length < 6) return tr('6 caractères minimum.');
              return null;
            },
          ),
          const SizedBox(height: 12),
          RefDropdown(
            label: tr('Rôle *'),
            path: 'roles',
            prefixIcon: Icons.badge_outlined,
            value: _roleId,
            itemLabel: (r) => roleLabel(r.str('nom')),
            onChanged: (v) => setState(() => _roleId = v),
            validator: (v) => v == null ? tr('Choisissez un rôle.') : null,
          ),
          if (_errors['role_id'] != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 6, start: 12),
              child: Text(_errors['role_id']!.first, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('Compte actif')),
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

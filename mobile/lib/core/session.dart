import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'i18n.dart';

const defaultServer = 'https://boulfrik.optizaworks.com';

/// Session de l'utilisateur : jeton, profil, rôle et permissions.
class Session extends ChangeNotifier {
  Session._(this.api);

  static const _storage = FlutterSecureStorage();

  final ApiClient api;
  Json? user;
  bool ready = false;

  bool get isLoggedIn => api.token != null && user != null;

  Json? get role => user?.obj('role');
  String get roleName => role?.str('nom') ?? '';
  bool get isAdmin => roleName.toLowerCase() == 'admin';

  Set<String> get permissions {
    final p = role?['permissions'];
    return p is List ? p.map((e) => e.toString()).toSet() : <String>{};
  }

  String get firstName => user?.str('prenom') ?? '';
  String get lastName => user?.str('nom') ?? '';
  String get userName => [firstName, lastName].where((e) => e.isNotEmpty).join(' ');
  String get userEmail => user?.str('email') ?? '';

  String get roleLabel => switch (roleName.toLowerCase()) {
        'admin' => tr('Administrateur'),
        'vendeur' => tr('Vendeur'),
        'magasinier' => tr('Magasinier'),
        'agent' => tr('Agent'),
        'livreur' => tr('Livreur'),
        '' => '—',
        _ => roleName[0].toUpperCase() + roleName.substring(1),
      };

  /// Le rôle « admin » a tous les droits.
  bool can(String permission) => isAdmin || permissions.contains(permission);
  bool canAny(Iterable<String> list) => isAdmin || list.any(permissions.contains);

  static Future<Session> start() async {
    final prefs = await SharedPreferences.getInstance();
    final server = prefs.getString('server') ?? defaultServer;
    final session = Session._(ApiClient(baseUrl: server));
    session.api.onUnauthenticated = session._expired;
    String? token;
    try {
      token = await _storage.read(key: 'token');
    } catch (_) {
      token = null;
    }
    if (token != null && token.isNotEmpty) {
      session.api.token = token;
      // Profil mis en cache : l'application s'ouvre même hors ligne.
      final cached = prefs.getString('user');
      if (cached != null) {
        try {
          session.user = _decode(cached);
        } catch (_) {}
      }
      try {
        await session.refresh();
      } on ApiException catch (e) {
        if (e.isUnauthenticated || e.status == 403) await session._clear();
      } catch (_) {}
    }
    session.ready = true;
    return session;
  }

  Future<void> setServer(String url) async {
    var clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (clean.endsWith('/api')) clean = clean.substring(0, clean.length - 4);
    api.baseUrl = clean.startsWith('http') ? clean : 'https://$clean';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server', api.baseUrl);
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final res = await api.post('auth/login', {'email': email.trim(), 'password': password}) as Json;
    final token = res.strOrNull('token');
    final u = res.obj('user');
    if (token == null || u == null) throw ApiException(tr('Réponse de connexion invalide.'));
    api.token = token;
    await _storage.write(key: 'token', value: token);
    await _setUser(u);
  }

  Future<void> refresh() async {
    final res = await api.get('auth/me') as Json;
    final u = res.obj('user') ?? (res.containsKey('email') ? res : null);
    if (u != null) await _setUser(u);
  }

  Future<void> logout() async {
    try {
      await api.post('auth/logout');
    } catch (_) {}
    await _clear();
  }

  Future<void> _setUser(Json u) async {
    user = u;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', _encode(u));
    notifyListeners();
  }

  void _expired() {
    _clear();
  }

  Future<void> _clear() async {
    api.token = null;
    user = null;
    try {
      await _storage.delete(key: 'token');
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    notifyListeners();
  }
}

String _encode(Json j) => jsonEncode(j);
Json _decode(String s) => (jsonDecode(s) as Map).cast<String, dynamic>();

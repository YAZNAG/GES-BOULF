import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Erreur renvoyée par l'API (format Laravel : {message, errors?}).
class ApiException implements Exception {
  ApiException(this.message, {this.status = 0, this.errors = const {}});

  final String message;
  final int status;
  final Map<String, List<String>> errors;

  bool get isUnauthenticated => status == 401;

  /// Premier message d'erreur d'un champ (ex. `lignes.0.quantite`), ou null.
  String? field(String name) => errors[name]?.first;

  /// Message détaillé : message principal + erreurs de champs distinctes.
  String get details {
    final extra = errors.values.expand((e) => e).where((e) => e != message).toSet();
    if (extra.isEmpty) return message;
    return [message, ...extra].join('\n');
  }

  @override
  String toString() => message;
}

/// Page d'une liste paginée Laravel « classique » : {current_page, data, last_page, total}.
class Paginated<T> {
  Paginated(this.items, this.currentPage, this.lastPage, this.total, [this.raw = const {}]);

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;

  /// Réponse brute (pour lire `stats`, `resume`…).
  final Map<String, dynamic> raw;

  bool get hasMore => currentPage < lastPage;
}

typedef Json = Map<String, dynamic>;

/// Client HTTP de l'API Boulfrik (jeton Sanctum).
class ApiClient {
  ApiClient({required this.baseUrl, this.token, this.onUnauthenticated});

  String baseUrl;
  String? token;
  void Function()? onUnauthenticated;

  final http.Client _http = http.Client();
  static const _timeout = Duration(seconds: 30);

  String get serverRoot => baseUrl.replaceAll(RegExp(r'/+$'), '');

  /// URL absolue d'une image (« /storage/… » est relatif au serveur).
  String? imageUrl(Object? path) {
    final p = path?.toString().trim() ?? '';
    if (p.isEmpty || p == 'null') return null;
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    return '$serverRoot${p.startsWith('/') ? '' : '/'}$p';
  }

  Uri uri(String path, [Map<String, dynamic>? query]) {
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v == null) return;
      final s = v is bool ? (v ? '1' : '0') : v.toString();
      if (s.isEmpty) return;
      q[k] = s;
    });
    return Uri.parse('$serverRoot/api/${path.replaceFirst(RegExp(r'^/'), '')}')
        .replace(queryParameters: q.isEmpty ? null : q);
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> get(String path, [Map<String, dynamic>? query]) =>
      _send(() => _http.get(uri(path, query), headers: _headers));

  Future<dynamic> post(String path, [Object? body]) =>
      _send(() => _http.post(uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> put(String path, [Object? body]) =>
      _send(() => _http.put(uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> delete(String path, [Map<String, dynamic>? query]) =>
      _send(() => _http.delete(uri(path, query), headers: _headers));

  /// Envoi multipart (champs + photo facultative), toujours en POST.
  /// Pour une modification Laravel, passer `_method: PUT` dans les champs.
  Future<dynamic> multipart(String path, Map<String, Object?> fields, {File? file, String fileField = 'image'}) {
    return _send(() async {
      final req = http.MultipartRequest('POST', uri(path));
      req.headers.addAll({'Accept': 'application/json', if (token != null) 'Authorization': 'Bearer $token'});
      fields.forEach((k, v) {
        if (v != null && '$v'.isNotEmpty) req.fields[k] = '$v';
      });
      if (file != null) req.files.add(await http.MultipartFile.fromPath(fileField, file.path));
      return http.Response.fromStream(await _http.send(req));
    });
  }

  /// Liste paginée : `mapper` convertit chaque élément.
  Future<Paginated<T>> page<T>(String path, T Function(Json) mapper,
      {Map<String, dynamic>? query, int page = 1, int perPage = 25}) async {
    final res = await get(path, {...?query, 'page': page, 'per_page': perPage});
    final json = res is Map ? res.cast<String, dynamic>() : <String, dynamic>{'data': res};
    final list = json['data'] is List ? json['data'] as List : const [];
    final items = list.whereType<Map>().map((e) => mapper(e.cast<String, dynamic>())).toList();
    return Paginated(
      items,
      json.integer('current_page', page),
      json.integer('last_page', page),
      json.integer('total', items.length),
      json,
    );
  }

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    http.Response res;
    try {
      res = await call().timeout(_timeout);
    } on SocketException {
      throw ApiException('Pas de connexion au serveur. Vérifiez votre réseau.');
    } on TimeoutException {
      throw ApiException('Le serveur ne répond pas. Réessayez.');
    } on HandshakeException {
      throw ApiException('Connexion sécurisée impossible avec le serveur.');
    } on http.ClientException {
      throw ApiException('Connexion au serveur impossible.');
    } on FormatException {
      throw ApiException('Adresse du serveur invalide.');
    }

    dynamic body;
    if (res.body.isNotEmpty) {
      try {
        body = jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        body = null;
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body == null && res.body.isNotEmpty && res.body.trimLeft().startsWith('<')) {
        throw ApiException('Réponse inattendue du serveur. Vérifiez l’adresse du serveur.');
      }
      return body;
    }

    final json = body is Map ? body.cast<String, dynamic>() : <String, dynamic>{};
    final errors = <String, List<String>>{};
    if (json['errors'] is Map) {
      (json['errors'] as Map).forEach((k, v) {
        errors[k.toString()] = v is List ? v.map((e) => e.toString()).toList() : [v.toString()];
      });
    }
    var message = json['message']?.toString() ?? json['error']?.toString() ?? '';
    // Messages techniques Laravel (anglais) → message français générique.
    final technical = message.startsWith('No query results') ||
        message == 'Server Error' ||
        message.startsWith('SQLSTATE') ||
        message.contains('Exception') ||
        message == 'This action is unauthorized.';
    if (message.isEmpty || technical || (res.statusCode >= 500 && message.length > 160)) {
      message = _defaultMessage(res.statusCode);
    }
    if (res.statusCode == 401) message = 'Session expirée. Reconnectez-vous.';
    final ex = ApiException(message, status: res.statusCode, errors: errors);
    if (ex.isUnauthenticated && token != null) onUnauthenticated?.call();
    throw ex;
  }

  static String _defaultMessage(int status) => switch (status) {
        401 => 'Session expirée. Reconnectez-vous.',
        403 => 'Action non autorisée.',
        404 => 'Ressource introuvable.',
        419 => 'Session expirée. Reconnectez-vous.',
        422 => 'Données invalides.',
        429 => 'Trop de tentatives. Réessayez dans une minute.',
        >= 500 => 'Erreur du serveur. Réessayez plus tard.',
        _ => 'Une erreur est survenue ($status).',
      };
}

double _toDouble(Object? v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}'.trim().replaceAll(' ', '').replaceAll(',', '.')) ?? double.nan;
}

/// Lecture tolérante des valeurs JSON (les nombres arrivent souvent en chaînes « 4.50 »).
extension JsonRead on Json {
  String str(String k, [String fallback = '']) {
    final v = this[k];
    if (v == null) return fallback;
    final s = v.toString();
    return s.isEmpty ? fallback : s;
  }

  String? strOrNull(String k) {
    final v = this[k];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  int integer(String k, [int fallback = 0]) {
    final d = _toDouble(this[k]);
    return d.isNaN ? fallback : d.round();
  }

  int? intOrNull(String k) => this[k] == null ? null : integer(k);

  double dbl(String k, [double fallback = 0]) {
    final d = _toDouble(this[k]);
    return d.isNaN ? fallback : d;
  }

  double? dblOrNull(String k) {
    final d = _toDouble(this[k]);
    return d.isNaN ? null : d;
  }

  bool flag(String k, [bool fallback = false]) {
    final v = this[k];
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return fallback;
  }

  Json? obj(String k) => this[k] is Map ? (this[k] as Map).cast<String, dynamic>() : null;

  List<Json> list(String k) =>
      (this[k] is List) ? (this[k] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : [];
}

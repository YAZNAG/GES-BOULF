import 'package:intl/intl.dart';

import 'i18n.dart';

final _amount = NumberFormat('#,##0.00', 'fr_FR');
final _number = NumberFormat('#,##0', 'fr_FR');
final _decimal = NumberFormat('#,##0.###', 'fr_FR');
final _date = DateFormat('dd/MM/yyyy', 'fr_FR');
final _dateTime = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
final _apiDate = DateFormat('yyyy-MM-dd');

/// Conversion tolérante : 4.5, "4.50", "4,50", null → double.
double toNum(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}'.replaceAll(',', '.').replaceAll(RegExp(r'\s'), '')) ?? 0;

/// Espaces fines insécables → espaces simples (affichage homogène).
String _clean(String s) => s.replaceAll(' ', ' ').replaceAll(' ', ' ');

/// « 1 234,50 DH »
String money(Object? v) => '${_clean(_amount.format(toNum(v)))} ${tr('DH')}';

/// Montant compact sans décimales si entier : « 1 234 DH ».
String moneyShort(Object? v) {
  final n = toNum(v);
  if (n.abs() >= 1000000) return '${_clean(NumberFormat('#,##0.0', 'fr_FR').format(n / 1000000))} ${tr('M DH')}';
  if (n == n.roundToDouble()) return '${_clean(_number.format(n))} ${tr('DH')}';
  return money(n);
}

/// Quantité sans décimales inutiles : « 12 », « 1,5 ».
String qty(Object? v, [String? unit]) {
  final n = toNum(v);
  final s = _clean(n == n.roundToDouble() ? _number.format(n) : _decimal.format(n));
  return unit == null || unit.isEmpty ? s : '$s $unit';
}

/// Quantité pour un champ de saisie : « 1.5 » → « 1,5 », « 12.000 » → « 12 ».
String qtyInput(double n) => n == n.roundToDouble() ? n.round().toString() : n.toString().replaceAll('.', ',');

/// Prix pour un champ de saisie : « 4.50 » → « 4,50 », 0 → ''.
String priceInput(Object? v, {bool keepZero = false}) {
  final n = toNum(v);
  if (n == 0 && !keepZero) return '';
  return n.toStringAsFixed(2).replaceAll('.', ',');
}

String percent(Object? v) => v == null ? '—' : '${_clean(NumberFormat('#,##0.0', 'fr_FR').format(toNum(v)))} %';

DateTime? parseDate(Object? iso) {
  final s = '${iso ?? ''}'.trim();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s.contains(' ') && !s.contains('T') ? s.replaceFirst(' ', 'T') : s);
}

/// « 03/10/2026 »
String date(Object? iso) {
  final d = parseDate(iso);
  if (d == null) return '—';
  // Une date seule (AAAA-MM-JJ) ne doit pas être décalée par le fuseau.
  final s = '$iso';
  return _date.format(s.length <= 10 ? d : d.toLocal());
}

/// « 03/10/2026 14:05 »
String dateTime(Object? iso) {
  final d = parseDate(iso);
  if (d == null) return '—';
  final s = '$iso';
  if (s.length <= 10) return _date.format(d);
  return _dateTime.format(s.endsWith('Z') || s.contains('+') ? d.toLocal() : d);
}

String apiDate(DateTime d) => _apiDate.format(d);

/// Saisie utilisateur → nombre (« 12,5 » → 12.5), null si vide/invalide.
double? parseInput(String s) {
  final t = s.trim().replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

/// Arrondi monétaire à 2 décimales.
double round2(double v) => (v * 100).roundToDouble() / 100;

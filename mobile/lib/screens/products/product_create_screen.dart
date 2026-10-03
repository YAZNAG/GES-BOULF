import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/photo_field.dart';
import '../../widgets/pickers.dart';
import '../../widgets/scanner.dart';
import 'quick_add_screen.dart';

/// Ajout manuel d'un produit, avec ou sans code-barres (vrac, produit maison…).
/// Sans code, le serveur attribue un code interne EAN-13 (préfixe 20) imprimable en étiquette.
class ProductCreateScreen extends StatefulWidget {
  const ProductCreateScreen({super.key});

  @override
  State<ProductCreateScreen> createState() => _ProductCreateScreenState();
}

class _ProductCreateScreenState extends State<ProductCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _nameFr = TextEditingController();
  final _nameAr = TextEditingController();
  final _marque = TextEditingController();
  final _code = TextEditingController();
  final _prixVente = TextEditingController();
  final _prixAchat = TextEditingController();
  int? _sousCategorie;
  String _unite = 'pièce';
  List<String> _unites = const ['pièce', 'kg', 'L'];
  File? _photo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadUnites();
  }

  @override
  void dispose() {
    for (final c in [_nameFr, _nameAr, _marque, _code, _prixVente, _prixAchat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUnites() async {
    try {
      final res = await context.api.get('unites', {'per_page': 200}) as Json;
      final noms = res.list('data').where((u) => u['actif'] != false).map((u) => u.str('nom')).where((n) => n.isNotEmpty).toList();
      if (mounted && noms.isNotEmpty) {
        setState(() {
          _unites = noms;
          if (!_unites.contains(_unite)) _unite = _unites.first;
        });
      }
    } catch (_) {
      // Liste par défaut conservée.
    }
  }

  /// Un code-barres scanné ici : s'il existe dans une base ouverte, on passe à la fiche préremplie.
  Future<void> _scanCode() async {
    final code = await ScannerPage.scan(context, title: 'Code-barres du produit');
    if (code == null || !mounted) return;
    final existant = await runBusy(context, () => lookupArticle(context.api, code));
    if (!mounted) return;
    if (existant != null) {
      showInfo(context, 'Ce code existe déjà : ${existant.str('name_fr', existant.str('nom'))}.');
      return;
    }
    if (_nameFr.text.trim().isEmpty) {
      // Formulaire vide : la fiche automatique fait gagner du temps.
      final article = await QuickAddScreen.open(context, code);
      if (article != null && mounted) Navigator.pop(context, article);
      return;
    }
    setState(() => _code.text = code);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final created = await context.api.multipart('articles/rapide', {
        'code_article': _code.text.trim(),
        'name_fr': _nameFr.text.trim(),
        'name_ar': _nameAr.text.trim(),
        'marque': _marque.text.trim(),
        'sous_categorie_id': _sousCategorie,
        'unite': _unite,
        'prix_vente': parseInput(_prixVente.text),
        'prix_achat': parseInput(_prixAchat.text),
      }, file: _photo);
      if (!mounted) return;
      final a = (created as Map).cast<String, dynamic>();
      showSuccess(context, 'Produit ajouté — code ${a.str('code_article')}.');
      Navigator.pop(context, a);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _price(String? v, {bool required = false}) {
    if (v == null || v.trim().isEmpty) return required ? 'Indiquez le prix de vente.' : null;
    final n = parseInput(v);
    if (n == null || n < 0 || (required && n == 0)) return 'Prix invalide.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: darkAppBar('Nouveau produit'),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
          Center(child: PhotoField(file: _photo, onChanged: (f) => setState(() => _photo = f))),
          const GroupLabel('Produit'),
          TextFormField(
            controller: _nameFr,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nom en français *', hintText: 'ex. Olives vertes en vrac'),
            validator: (v) => (v == null || v.trim().length < 2) ? 'Indiquez le nom du produit.' : null,
          ),
          const SizedBox(height: 12),
          Directionality(
            textDirection: TextDirection.rtl,
            child: TextFormField(controller: _nameAr, decoration: const InputDecoration(labelText: 'الاسم بالعربية')),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _marque,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Marque (facultatif)'),
          ),
          const SizedBox(height: 12),
          RefDropdown(
            label: 'Sous-catégorie *',
            path: 'sous_categories',
            value: _sousCategorie,
            onChanged: (v) => setState(() => _sousCategorie = v),
            itemLabel: (j) => j.str('name_fr', j.str('nom')),
            validator: (v) => v == null ? 'Choisissez la sous-catégorie.' : null,
            prefixIcon: Icons.category_outlined,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _unite,
            decoration: const InputDecoration(labelText: 'Unité de vente', prefixIcon: Icon(Icons.straighten)),
            items: [for (final u in _unites) DropdownMenuItem(value: u, child: Text(u))],
            onChanged: (v) => setState(() => _unite = v ?? _unite),
          ),
          const GroupLabel('Prix'),
          TextFormField(
            controller: _prixVente,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              labelText: 'Prix de vente *',
              suffixText: _unite == 'pièce' ? 'DH' : 'DH / $_unite',
              prefixIcon: const Icon(Icons.sell_outlined),
            ),
            validator: (v) => _price(v, required: true),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _prixAchat,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Prix d’achat (facultatif)', suffixText: 'DH', prefixIcon: Icon(Icons.shopping_bag_outlined)),
            validator: _price,
          ),
          const GroupLabel('Code-barres'),
          TextFormField(
            controller: _code,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Code-barres (facultatif)',
              helperText: 'Laissez vide : un code interne sera créé automatiquement.',
              prefixIcon: const Icon(Icons.qr_code_2),
              suffixIcon: IconButton(tooltip: 'Scanner', icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary), onPressed: _scanCode),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: BottomAction(label: 'Ajouter le produit', icon: Icons.add_circle_outline, busy: _saving, onPressed: _save),
    );
  }
}

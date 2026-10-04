import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/article.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/photo_field.dart';
import '../../widgets/pickers.dart';
import '../../widgets/scanner.dart';

/// Choix d'une marque (recherche serveur, ~900 marques). Null si annulé.
Future<Json?> pickBrand(BuildContext context) {
  final api = context.api;
  return pickEntity(
    context,
    title: tr('Choisir une marque'),
    searchHint: tr('Nom de la marque'),
    fetch: (page, q) => api.page('marques', (j) => j, page: page, perPage: 50, query: {'q': q}),
    label: (j) => j.str('nom'),
    leading: (j) => ItemThumb(path: brandImagePath(j), label: j.str('nom'), color: AppColors.info, size: 40),
  );
}

/// Modification de la fiche d'un article : photo, noms, marque, sous-catégorie, unité, code-barres.
/// Renvoie true si enregistré.
class ProductEditScreen extends StatefulWidget {
  const ProductEditScreen({super.key, required this.article});

  final Json article;

  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  final _form = GlobalKey<FormState>();
  late final Json a = widget.article;
  late final _nameFr = TextEditingController(text: a.strOrNull('name_fr') ?? a.str('nom'));
  late final _nameAr = TextEditingController(text: a.str('name_ar'));
  late final _code = TextEditingController(text: a.str('code_article'));
  late int? _sousCategorie = a.intOrNull('sous_categorie_id') ?? a.obj('sous_categorie')?.intOrNull('id');
  late int? _marqueId = a.intOrNull('marque_id') ?? a.obj('marque')?.intOrNull('id');
  late String? _marqueNom = a.brandName;
  late String _unite = a.str('unite', 'pièce');
  List<String> _unites = const [];
  File? _photo;
  bool _removePhoto = false;
  bool _saving = false;
  Map<String, List<String>> _errors = {};

  int get _id => a.integer('id');

  @override
  void initState() {
    super.initState();
    _loadUnites();
  }

  @override
  void dispose() {
    for (final c in [_nameFr, _nameAr, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUnites() async {
    try {
      final res = await context.api.get('unites', {'per_page': 200}) as Json;
      final noms = res.list('data').where((u) => u['actif'] != false).map((u) => u.str('nom')).where((n) => n.isNotEmpty).toList();
      if (mounted) setState(() => _unites = noms);
    } catch (_) {
      // L'unité actuelle reste proposée.
    }
  }

  Future<void> _scanCode() async {
    final code = await ScannerPage.scan(context, title: tr('Code-barres du produit'));
    if (code != null && mounted) setState(() => _code.text = code);
  }

  Future<void> _chooseBrand() async {
    final m = await pickBrand(context);
    if (m != null && mounted) {
      setState(() {
        _marqueId = m.integer('id');
        _marqueNom = m.str('nom');
      });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _errors = {};
    });
    final api = context.api;
    final code = _code.text.trim();
    try {
      await api.put('articles/$_id', {
        'name_fr': _nameFr.text.trim(),
        'name_ar': _nameAr.text.trim().isEmpty ? null : _nameAr.text.trim(),
        'sous_categorie_id': _sousCategorie,
        'marque_id': _marqueId,
        'unite': _unite,
        if (code.isNotEmpty) 'code_article': code,
      });
      if (_photo != null) {
        await api.multipart('images/articles/$_id', {}, file: _photo);
      } else if (_removePhoto) {
        await api.delete('images/articles/$_id');
      }
      if (!mounted) return;
      showSuccess(context, tr('Fiche article enregistrée.'));
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errors = e.errors);
      showError(context, e);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unites = {..._unites, if (_unite.isNotEmpty) _unite}.toList();
    return Scaffold(
      appBar: darkAppBar(tr('Modifier la fiche'), subtitle: a.articleName),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
          Center(
            child: PhotoField(
              file: _photo,
              imagePath: _removePhoto ? null : a.strOrNull('image'),
              onChanged: (f) => setState(() => _photo = f),
              onRemove: () => setState(() => _removePhoto = true),
            ),
          ),
          if (_removePhoto && _photo == null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(tr('La photo sera supprimée à l’enregistrement.'),
                  textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ),
          GroupLabel(tr('Produit')),
          TextFormField(
            controller: _nameFr,
            textCapitalization: TextCapitalization.sentences,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: tr('Nom en français *'), errorText: _errors['name_fr']?.first ?? _errors['nom']?.first),
            validator: (v) => (v == null || v.trim().length < 2) ? tr('Indiquez le nom du produit.') : null,
          ),
          const SizedBox(height: 12),
          Directionality(
            textDirection: TextDirection.rtl,
            child: TextFormField(
              controller: _nameAr,
              decoration: InputDecoration(labelText: 'الاسم بالعربية', errorText: _errors['name_ar']?.first),
            ),
          ),
          const SizedBox(height: 12),
          EntityField(
            label: tr('Marque'),
            text: _marqueNom,
            icon: Icons.verified_outlined,
            error: _errors['marque_id']?.first,
            onTap: _chooseBrand,
            onClear: () => setState(() {
              _marqueId = null;
              _marqueNom = null;
            }),
          ),
          const SizedBox(height: 12),
          RefDropdown(
            label: tr('Sous-catégorie *'),
            path: 'sous_categories',
            query: const {'per_page': 1000},
            value: _sousCategorie,
            onChanged: (v) => setState(() => _sousCategorie = v),
            itemLabel: (j) => catName(j),
            validator: (v) => v == null ? tr('Choisissez la sous-catégorie.') : null,
            prefixIcon: Icons.category_outlined,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(unites.length),
            initialValue: _unite.isEmpty ? null : _unite,
            decoration: InputDecoration(
              labelText: tr('Unité de vente'),
              prefixIcon: const Icon(Icons.straighten),
              errorText: _errors['unite']?.first,
            ),
            items: [for (final u in unites) DropdownMenuItem(value: u, child: Text(u))],
            onChanged: (v) => setState(() => _unite = v ?? _unite),
          ),
          GroupLabel(tr('Code-barres')),
          TextFormField(
            controller: _code,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: tr('Code-barres'),
              prefixIcon: const Icon(Icons.qr_code_2),
              errorText: _errors['code_article']?.first,
              suffixIcon: IconButton(tooltip: tr('Scanner'), icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary), onPressed: _scanCode),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) && a.barcode.isNotEmpty ? tr('Le code-barres ne peut pas être vidé.') : null,
          ),
        ]),
      ),
      bottomNavigationBar: BottomAction(label: tr('Enregistrer'), busy: _saving, onPressed: _save),
    );
  }
}

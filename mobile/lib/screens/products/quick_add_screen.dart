import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/pickers.dart';

/// Ajout rapide d'un article scanné mais absent de la base.
///
/// Le serveur prépare la fiche (bases ouvertes Open Food Facts… + assistant IA s'il est configuré) :
/// photo, nom français, nom arabe, marque, sous-catégorie. L'utilisateur vérifie et saisit le prix de vente.
/// Renvoie l'article créé (ou existant) via Navigator.pop.
class QuickAddScreen extends StatefulWidget {
  const QuickAddScreen({super.key, required this.code});

  final String code;

  static Future<Json?> open(BuildContext context, String code) =>
      Navigator.of(context).push<Json>(MaterialPageRoute(builder: (_) => QuickAddScreen(code: code)));

  @override
  State<QuickAddScreen> createState() => _QuickAddScreenState();
}

class _QuickAddScreenState extends State<QuickAddScreen> {
  final _form = GlobalKey<FormState>();
  final _nameFr = TextEditingController();
  final _nameAr = TextEditingController();
  final _marque = TextEditingController();
  final _prixVente = TextEditingController();
  final _prixAchat = TextEditingController();
  final _venteFocus = FocusNode();
  int? _sousCategorie;
  String? _imageUrl;
  String? _source;
  bool _ia = false;
  bool _loading = true;
  bool _saving = false;
  bool _trouve = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_nameFr, _nameAr, _marque, _prixVente, _prixAchat]) {
      c.dispose();
    }
    _venteFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await context.api.get('articles/fiche', {'code': widget.code}) as Json;
      if (!mounted) return;
      // Créé entre-temps (autre caisse) : on le renvoie directement.
      final existant = res.obj('deja_existant');
      if (existant != null) {
        Navigator.pop(context, existant);
        return;
      }
      final f = res.obj('fiche') ?? {};
      setState(() {
        _nameFr.text = f.str('name_fr');
        _nameAr.text = f.str('name_ar');
        _marque.text = f.str('marque');
        _imageUrl = f.strOrNull('image_url');
        _sousCategorie = f.intOrNull('sous_categorie_id');
        _source = f.strOrNull('source');
        _ia = f.flag('ia');
        _trouve = f.flag('trouve');
        _loading = false;
      });
      // Tout est prérempli : le curseur va directement au prix de vente.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _trouve) _venteFocus.requestFocus();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, e);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final created = await context.api.post('articles/rapide', {
        'code_article': widget.code,
        'name_fr': _nameFr.text.trim(),
        'name_ar': _nameAr.text.trim().isEmpty ? null : _nameAr.text.trim(),
        'marque': _marque.text.trim().isEmpty ? null : _marque.text.trim(),
        'sous_categorie_id': _sousCategorie,
        'image_url': _imageUrl,
        'prix_vente': parseInput(_prixVente.text),
        'prix_achat': parseInput(_prixAchat.text),
      });
      if (!mounted) return;
      showSuccess(context, 'Article ajouté au catalogue.');
      Navigator.pop(context, (created as Map).cast<String, dynamic>());
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
      body: _loading
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 18),
                const Text('Recherche du produit…', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 6),
                Text('Code ${widget.code}', style: const TextStyle(color: AppColors.muted)),
              ]),
            )
          : Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
                // Bandeau : trouvé automatiquement ou non.
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (_trouve ? AppColors.success : AppColors.warning).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    Icon(_trouve ? Icons.auto_awesome : Icons.info_outline, color: _trouve ? AppColors.success : AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _trouve
                            ? 'Produit absent du magasin : fiche préparée automatiquement'
                                '${_source != null ? ' ($_source${_ia ? ' + assistant IA' : ''})' : _ia ? ' (assistant IA)' : ''}. '
                                'Vérifiez puis saisissez le prix de vente.'
                            : 'Produit inconnu des bases ouvertes. Saisissez son nom, sa catégorie et son prix de vente.',
                        style: const TextStyle(fontSize: 13.5, height: 1.35),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _imageUrl != null
                        ? Image.network(_imageUrl!, fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported_outlined, size: 40, color: AppColors.muted))
                        : const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.muted),
                  ),
                ),
                const SizedBox(height: 8),
                Center(child: Text(widget.code, style: const TextStyle(color: AppColors.muted, fontFamily: 'monospace'))),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _prixVente,
                  focusNode: _venteFocus,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  decoration: const InputDecoration(labelText: 'Prix de vente *', suffixText: 'DH', prefixIcon: Icon(Icons.sell_outlined)),
                  validator: (v) => _price(v, required: true),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _prixAchat,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Prix d’achat (facultatif)', suffixText: 'DH', prefixIcon: Icon(Icons.shopping_bag_outlined)),
                  validator: _price,
                ),
                const SizedBox(height: 20),
                const GroupLabel('Fiche produit'),
                TextFormField(
                  controller: _nameFr,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Nom en français *'),
                  validator: (v) => (v == null || v.trim().length < 2) ? 'Indiquez le nom du produit.' : null,
                ),
                const SizedBox(height: 12),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: TextFormField(
                    controller: _nameAr,
                    decoration: const InputDecoration(labelText: 'الاسم بالعربية'),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _marque,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Marque'),
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
              ]),
            ),
      bottomNavigationBar: _loading
          ? null
          : BottomAction(
              label: 'Ajouter au catalogue',
              icon: Icons.add_circle_outline,
              busy: _saving,
              onPressed: _save,
            ),
    );
  }
}

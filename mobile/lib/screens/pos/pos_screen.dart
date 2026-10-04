import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/article.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/pickers.dart';
import '../../widgets/price_editor.dart';
import '../../widgets/scanner.dart';
import 'checkout_screen.dart';
import '../../widgets/unknown_product.dart';

/// Article dans le panier.
class CartItem {
  CartItem(this.article, [this.quantity = 1]);

  Json article;
  double quantity;

  /// Prix accordé pour cette vente seulement (remise, prix négocié) ; null = prix du catalogue.
  double? priceOverride;

  int get id => article.integer('id');
  double get catalogPrice => article.sellPrice;
  bool get priceChanged => priceOverride != null && priceOverride != catalogPrice;
  double get unitPrice => priceOverride ?? catalogPrice;
  double get total => round2(unitPrice * quantity);
}

/// Caisse : scan / recherche, panier, encaissement.
class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _cart = <CartItem>[];
  final _search = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<Json> _results = [];
  bool _searching = false;
  Object? _searchError;
  int _gen = 0;

  /// Articles déjà trouvés par code-barres (vidé après chaque vente pour reprendre les prix à jour).
  final Map<String, Json> _byCode = {};

  double get _total => round2(_cart.fold(0.0, (t, e) => t + e.total));
  double get _count => _cart.fold(0.0, (t, e) => t + e.quantity);

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  static bool _looksLikeBarcode(String s) => RegExp(r'^\d{4,}$').hasMatch(s.trim());

  /// Ajoute un article au panier. Renvoie un message d'erreur (ou null si ajouté).
  String? _add(Json a) {
    if (!a.isActive) return tr('« {article} » est inactif : il ne peut pas être vendu.', {'article': a.articleName});
    if (!a.isPriced) return tr('« {article} » n’a pas de prix de vente. Tarifez-le avant de le vendre.', {'article': a.articleName});
    final existing = _cart.where((c) => c.id == a.integer('id')).firstOrNull;
    setState(() {
      if (existing != null) {
        existing.quantity += 1;
        // Remonte la ligne en haut du panier.
        _cart
          ..remove(existing)
          ..insert(0, existing);
      } else {
        _cart.insert(0, CartItem(a));
      }
    });
    HapticFeedback.selectionClick();
    return null;
  }

  void _tryAdd(Json a) {
    final err = _add(a);
    if (err == null) {
      _clearSearch();
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(err),
        backgroundColor: AppColors.danger,
        action: SnackBarAction(
                label: tr('TARIFER'),
                textColor: Colors.white,
                onPressed: () async {
                  final ok = await editPrices(context, a);
                  if (ok && mounted) {
                    final fresh = await _reload(a.integer('id'));
                    if (fresh != null && mounted) _tryAdd(fresh);
                  }
                },
              ),
      ));
  }

  Future<Json?> _reload(int id) async {
    try {
      final r = await context.api.get('articles/$id');
      return (r as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  void _clearSearch() {
    _debounce?.cancel();
    _gen++;
    setState(() {
      _search.clear();
      _results = [];
      _searching = false;
      _searchError = null;
    });
  }

  void _onChanged(String v) {
    setState(() {});
    _debounce?.cancel();
    if (v.trim().isEmpty) {
      _clearSearch();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(v.trim()));
  }

  Future<void> _runSearch(String q) async {
    final gen = ++_gen;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final page = await context.api.page('articles', (j) => j, query: {'q': q, 'sort': 'nom'}, perPage: 30);
      if (!mounted || gen != _gen) return;
      setState(() => _results = page.items);
    } catch (e) {
      if (mounted && gen == _gen) setState(() => _searchError = e);
    } finally {
      if (mounted && gen == _gen) setState(() => _searching = false);
    }
  }

  /// Validation du champ : un code-barres ajoute directement l'article.
  Future<void> _onSubmitted(String v) async {
    final q = v.trim();
    if (q.isEmpty) return;
    _debounce?.cancel();
    if (_looksLikeBarcode(q)) {
      // Chaque scan est traité indépendamment : le champ est vidé tout de suite pour le scan suivant,
      // et l'article est ajouté à l'arrivée de la réponse (les scans rapides ne se perdent pas).
      _clearSearch();
      _focus.requestFocus();
      try {
        final a = _byCode[q] ?? await lookupArticle(context.api, q);
        if (!mounted) return;
        if (a != null) {
          _byCode[q] = a;
          _tryAdd(a);
          return;
        }
        // Code-barres complet inconnu : proposer l'ajout immédiat du produit.
        if (q.length >= 8) {
          await _unknownCode(q);
          return;
        }
        // Code court : peut-être un code saisi partiellement → recherche classique.
        _search.text = q;
      } catch (e) {
        if (mounted) showError(context, e);
        return;
      }
    }
    await _runSearch(q);
    if (mounted && _results.length == 1) _tryAdd(_results.first);
  }

  /// Code scanné absent du magasin : message, puis fiche d'ajout préremplie automatiquement.
  Future<void> _unknownCode(String code) async {
    final article = await offerAddProduct(context, code);
    if (article == null || !mounted) return;
    _byCode[code] = article;
    _tryAdd(article);
  }

  /// Scan caméra : un code à la fois, la caméra se ferme et on revient au panier.
  Future<void> _scan() async {
    FocusScope.of(context).unfocus();
    final code = await ScannerPage.scan(context, title: tr('Scanner un article'));
    if (code == null || !mounted) return;
    try {
      final a = _byCode[code] ?? await runBusy<Json?>(context, () => lookupArticle(context.api, code));
      if (!mounted) return;
      if (a == null) {
        await _unknownCode(code);
        return;
      }
      _byCode[code] = a;
      final err = _add(a);
      if (err != null) {
        _tryAdd(a); // affiche le message (inactif, non tarifé) avec le raccourci « Tarifer »
        return;
      }
      final line = _cart.firstWhere((c) => c.id == a.integer('id'));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(tr('{article} × {qte} — total {total}', {'article': a.articleName, 'qte': qty(line.quantity), 'total': money(_total)})),
          action: SnackBarAction(label: tr('SCANNER'), onPressed: _scan),
        ));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _editQty(CartItem item) async {
    final ctrl = TextEditingController(text: qtyInput(item.quantity));
    final v = await showDialog<double>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Quantité')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(item.article.articleName, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(suffixText: item.article.unit, helperText: tr('Décimales acceptées pour le vrac (ex. 1,250)')),
            onSubmitted: (t) => Navigator.pop(c, parseInput(t)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Annuler'))),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 42)),
            onPressed: () => Navigator.pop(c, parseInput(ctrl.text)),
            child: Text(tr('Valider')),
          ),
        ],
      ),
    );
    if (v == null) return;
    setState(() {
      if (v <= 0) {
        _cart.remove(item);
      } else {
        item.quantity = v;
      }
    });
  }

  void _step(CartItem item, double delta) {
    setState(() {
      final v = item.quantity + delta;
      if (v <= 0) {
        _cart.remove(item);
      } else {
        item.quantity = (v * 1000).roundToDouble() / 1000;
      }
    });
  }

  /// Détail d'une ligne du panier : photo, infos, prix pour cette vente, prix du catalogue.
  Future<void> _showDetail(CartItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheet) => StatefulBuilder(builder: (sheet, setSheet) {
        final a = item.article;
        final ar = a.articleNameAr;
        final url = context.api.imageUrl(a['image']);
        void refresh() {
          setSheet(() {});
          if (mounted) setState(() {});
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: url != null
                      ? Image.network(url, fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(Icons.inventory_2_outlined, size: 56, color: AppColors.muted))
                      : const Icon(Icons.inventory_2_outlined, size: 56, color: AppColors.muted),
                ),
              ),
              const SizedBox(height: 14),
              if (a.brandName != null)
                Text(a.brandName!.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.6)),
              Text(a.articleName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              if (ar != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(ar, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ),
              const SizedBox(height: 14),
              InfoRow(tr('Code-barres'), a.barcode),
              if (a.subCategoryName != null) InfoRow(tr('Catégorie'), a.subCategoryName!),
              InfoRow(tr('Stock'), a.stockQty == null ? '—' : qty(a.stockQty, a.unit)),
              InfoRow(tr('Prix du catalogue'), money(item.catalogPrice)),
              InfoRow(tr('Quantité'), qty(item.quantity, a.unit)),
              const Divider(height: 24),
              Row(children: [
                Expanded(child: Text(tr('Prix pour cette vente'), style: const TextStyle(fontWeight: FontWeight.w700))),
                Text(money(item.unitPrice),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: item.priceChanged ? AppColors.warning : AppColors.ink)),
              ]),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  final v = await _askPrice(item);
                  if (v == null) return;
                  item.priceOverride = (v - item.catalogPrice).abs() < 0.005 ? null : v;
                  refresh();
                },
                icon: const Icon(Icons.edit_outlined),
                label: Text(tr('Changer le prix pour cette vente')),
              ),
              if (item.priceChanged) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    item.priceOverride = null;
                    refresh();
                  },
                  icon: const Icon(Icons.undo),
                  label: Text(tr('Revenir au prix du catalogue')),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  // Modifie le tarif de l'article pour toutes les ventes (PUT tarifs/{id}).
                  final ok = await editPrices(context, a);
                  if (!ok) return;
                  final fresh = await _reload(item.id);
                  if (fresh != null) {
                    item.article = fresh;
                    item.priceOverride = null;
                    _byCode.removeWhere((_, v) => v.integer('id') == item.id);
                  }
                  refresh();
                },
                icon: const Icon(Icons.sell_outlined),
                label: Text(tr('Modifier le prix du produit (catalogue)')),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () {
                  Navigator.pop(sheet);
                  _remove(item);
                },
                icon: const Icon(Icons.delete_outline),
                label: Text(tr('Retirer du panier')),
              ),
            ]),
          ),
        );
      }),
    );
  }

  Future<double?> _askPrice(CartItem item) async {
    final ctrl = TextEditingController(text: priceInput(item.unitPrice));
    final v = await showDialog<double>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Prix pour cette vente')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ProductHeader(article: item.article, size: 64),
          const SizedBox(height: 12),
          Text(tr('Prix du catalogue : {prix}', {'prix': money(item.catalogPrice)}), style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: tr('Prix unitaire'),
                suffixText: item.article.unit.isEmpty ? tr('DH') : tr('DH / {unite}', {'unite': item.article.unit})),
            onSubmitted: (t) => Navigator.pop(c, parseInput(t)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Annuler'))),
          FilledButton(onPressed: () => Navigator.pop(c, parseInput(ctrl.text)), child: Text(tr('Appliquer'))),
        ],
      ),
    );
    ctrl.dispose();
    if (v == null) return null;
    if (v <= 0) {
      if (mounted) showInfo(context, tr('Le prix doit être supérieur à 0.'));
      return null;
    }
    return round2(v);
  }

  void _remove(CartItem item) {
    final index = _cart.indexOf(item);
    setState(() => _cart.remove(item));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(tr('« {article} » retiré du panier.', {'article': item.article.articleName})),
        action: SnackBarAction(
          label: tr('ANNULER'),
          onPressed: () => setState(() => _cart.insert(index.clamp(0, _cart.length), item)),
        ),
      ));
  }

  Future<void> _clearCart() async {
    if (_cart.isEmpty) return;
    if (await confirm(context, tr('Vider le panier'), tr('Retirer tous les articles du panier ?'), ok: tr('Vider'), danger: true)) {
      setState(_cart.clear);
    }
  }

  Future<void> _checkout() async {
    FocusScope.of(context).unfocus();
    await context.push(CheckoutScreen(
      items: List.of(_cart),
      onSuccess: () {
        _byCode.clear();
        if (mounted) setState(_cart.clear);
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim();
    return Scaffold(
      appBar: darkAppBar(tr('Caisse'), actions: [
        if (_cart.isNotEmpty) IconButton(tooltip: tr('Vider le panier'), icon: const Icon(Icons.delete_sweep_outlined), onPressed: _clearCart),
      ]),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _search,
                focusNode: _focus,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: tr('Code-barres, nom FR ou عربي'),
                  prefixIcon: const Icon(Icons.search),
                  fillColor: AppColors.surface,
                  isDense: true,
                  suffixIcon: query.isEmpty ? null : IconButton(icon: const Icon(Icons.close), onPressed: _clearSearch),
                ),
                onChanged: _onChanged,
                onSubmitted: _onSubmitted,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 48,
              width: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(48, 48)),
                onPressed: _scan,
                child: const Icon(Icons.qr_code_scanner, size: 26),
              ),
            ),
          ]),
        ),
        if (_searching) const LinearProgressIndicator(minHeight: 2) else const Divider(height: 1),
        Expanded(child: query.isNotEmpty ? _resultsView(query) : _cartView()),
      ]),
      bottomNavigationBar: _cart.isEmpty || query.isNotEmpty ? null : _summaryBar(),
    );
  }

  Widget _resultsView(String query) {
    if (_searchError != null && _results.isEmpty) {
      return ErrorState(error: _searchError!, onRetry: () => _runSearch(query));
    }
    if (_results.isEmpty) {
      if (_searching) return const SkeletonList(count: 6);
      return EmptyState(
        icon: Icons.search_off,
        title: tr('Aucun article'),
        message: _looksLikeBarcode(query)
            ? tr('Aucun article pour « {q} ». Appuyez sur Entrée pour rechercher le code exact.', {'q': query})
            : tr('Aucun article ne correspond à « {q} ».', {'q': query}),
      );
    }
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final a = _results[i];
        final inCart = _cart.where((c) => c.id == a.integer('id')).firstOrNull;
        return Container(
          color: Colors.white,
          child: ArticleTile(
            article: a,
            onTap: () => _tryAdd(a),
            trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(a.isPriced ? money(a.sellPrice) : '—',
                  style: TextStyle(fontWeight: FontWeight.w800, color: a.isPriced ? AppColors.ink : AppColors.muted)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: a.isPriced && a.isActive ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: inCart != null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text('× ${qty(inCart.quantity)}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                      )
                    : const Icon(Icons.add, color: Colors.white, size: 18),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _cartView() {
    if (_cart.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 40),
        EmptyState(
          icon: Icons.shopping_cart_outlined,
          title: tr('Panier vide'),
          message: tr('Scannez un article avec la caméra ou recherchez-le par code-barres, nom français ou arabe.'),
          action: FilledButton.icon(
            onPressed: _scan,
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(tr('Scanner un article')),
          ),
        ),
      ]);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: _cart.length + 1,
      itemBuilder: (_, i) {
        if (i == _cart.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(tr('Glissez à gauche pour retirer · à droite pour le détail et le prix.'),
                textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          );
        }
        final item = _cart[i];
        return Dismissible(
          key: ObjectKey(item),
          direction: DismissDirection.horizontal,
          // Vers la droite : détail du produit (la ligne reste) ; vers la gauche : retrait.
          confirmDismiss: (dir) async {
            if (dir == DismissDirection.startToEnd) {
              _showDetail(item);
              return false;
            }
            return true;
          },
          onDismissed: (_) => _remove(item),
          background: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: AlignmentDirectional.centerStart,
            decoration: BoxDecoration(color: AppColors.info, borderRadius: BorderRadius.circular(18)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.info_outline, color: Colors.white),
              const SizedBox(width: 6),
              Text(tr('Détail · prix'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
          ),
          secondaryBackground: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: AlignmentDirectional.centerEnd,
            decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(18)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.delete_outline, color: Colors.white),
              const SizedBox(width: 6),
              Text(tr('Retirer'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
          ),
          child: _cartLine(item),
        );
      },
    );
  }

  Widget _cartLine(CartItem item) {
    final a = item.article;
    final ar = a.articleNameAr;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ItemThumb(path: a['image'], label: a.articleName, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.articleName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (ar != null)
                Text(ar, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              const SizedBox(height: 2),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
                if (item.priceChanged)
                  Text(money(item.catalogPrice),
                      style: const TextStyle(color: AppColors.muted, fontSize: 12, decoration: TextDecoration.lineThrough)),
                Text('${money(item.unitPrice)}${a.unit.isNotEmpty ? ' / ${a.unit}' : ''}',
                    style: TextStyle(
                        color: item.priceChanged ? AppColors.warning : AppColors.muted,
                        fontSize: 12.5,
                        fontWeight: item.priceChanged ? FontWeight.w700 : FontWeight.w400)),
                if (item.priceChanged) Badge2(tr('Prix modifié'), color: AppColors.warning),
                if (!item.priceChanged && a.hasPromo) Badge2(tr('Promo'), color: AppColors.primary),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _RoundBtn(icon: item.quantity <= 1 ? Icons.delete_outline : Icons.remove, onTap: () => _step(item, -1)),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _editQty(item),
            child: Container(
              constraints: const BoxConstraints(minWidth: 64),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
              child: Text(qty(item.quantity), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
          _RoundBtn(icon: Icons.add, onTap: () => _step(item, 1), filled: true),
          const Spacer(),
          Text(money(item.total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ]),
      ]),
    );
  }

  Widget _summaryBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -4))],
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(
                  '${_cart.length > 1 ? tr('{n} articles', {'n': _cart.length}) : tr('{n} article', {'n': _cart.length})} · '
                  '${_count > 1 ? tr('{n} unités', {'n': qty(_count)}) : tr('{n} unité', {'n': qty(_count)})}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(money(_total), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              ),
            ]),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(150, 54)),
            onPressed: _checkout,
            icon: const Icon(Icons.payments_outlined),
            label: Text(tr('Encaisser')),
          ),
        ]),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap, this.filled = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.primary : Colors.white,
      shape: CircleBorder(side: BorderSide(color: filled ? AppColors.primary : AppColors.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: filled ? Colors.white : AppColors.ink),
        ),
      ),
    );
  }
}

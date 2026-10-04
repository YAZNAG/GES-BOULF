import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api.dart';
import '../../core/article.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/delete_helper.dart';
import '../../widgets/photo_field.dart';
import '../../widgets/price_editor.dart';
import '../../widgets/stock_adjust.dart';
import 'product_edit_screen.dart';

/// Fiche article : photo, noms FR/AR, prix, marge, stock, description. Renvoie true si modifié.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.articleId, this.initial});

  final int articleId;
  final Json? initial;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _view = GlobalKey<AsyncViewState<Json>>();
  bool _changed = false;
  Json? _article;

  Future<Json> _load() async {
    final a = (await context.api.get('articles/${widget.articleId}') as Map).cast<String, dynamic>();
    if (mounted) setState(() => _article = a);
    return a;
  }

  void _reload() {
    _changed = true;
    _view.currentState?.reload();
  }

  Future<void> _editRecord(Json a) async {
    final ok = await context.push<bool>(ProductEditScreen(article: a));
    if (ok == true) _reload();
  }

  Future<void> _setActive(Json a, bool actif) async {
    final api = context.api;
    final ok = await runBusy<bool>(context, () async {
      await api.put('tarifs/${a.integer('id')}', {'actif': actif});
      return true;
    }, success: actif ? tr('Article activé.') : tr('Article désactivé.'));
    if (ok == true) _reload();
  }

  Future<void> _toggleActive(Json a) async {
    final actif = a.isActive;
    final ok = await confirm(
      context,
      actif ? tr('Désactiver l’article') : tr('Activer l’article'),
      actif
          ? tr('« {nom} » ne pourra plus être vendu en caisse. Son historique est conservé.', {'nom': a.articleName})
          : tr('« {nom} » pourra de nouveau être vendu (s’il a un prix de vente).', {'nom': a.articleName}),
      ok: actif ? tr('Désactiver') : tr('Activer'),
      danger: actif,
    );
    if (ok && mounted) await _setActive(a, !actif);
  }

  /// Suppression : on vérifie d'abord les utilisations (ventes, réceptions…) ; sinon on propose de désactiver.
  Future<void> _delete(Json a) async {
    final api = context.api;
    final id = a.integer('id');
    final usage = await runBusy(context, () async => (await api.get('articles/$id/usage') as Map).cast<String, dynamic>());
    if (usage == null || !mounted) return;
    final actif = usage.flag('actif', a.isActive);
    if (!usage.flag('supprimable')) {
      final deactivate = await showInUseDialog(
        context,
        message: actif
            ? tr('Cet article est utilisé dans l’historique : il ne peut pas être supprimé. Vous pouvez le désactiver à la place.')
            : tr('Cet article est utilisé dans l’historique : il ne peut pas être supprimé. Il est déjà désactivé.'),
        usages: usagesOf(usage['utilisations']),
        canDeactivate: actif,
      );
      if (deactivate && mounted) await _setActive(a, false);
      return;
    }
    var deleted = false;
    final changed = await deleteWithFallback(
      context,
      what: tr('l’article « {nom} »', {'nom': a.articleName}),
      confirmMessage: tr('« {nom} » sera supprimé définitivement (avec son prix et son stock).', {'nom': a.articleName}),
      delete: () async {
        await api.delete('articles/$id');
        deleted = true;
      },
      deactivate: actif ? () => api.put('tarifs/$id', {'actif': false}) : null,
      success: tr('Article supprimé.'),
      deactivated: tr('Article désactivé.'),
    );
    if (!changed || !mounted) return;
    if (deleted) {
      Navigator.of(context).pop(true);
    } else {
      _reload();
    }
  }

  Future<void> _photoMenu(Json a) async {
    final url = context.api.imageUrl(a['image']);
    final action = await askPhotoAction(context, hasImage: url != null, title: tr('Photo de l’article'));
    if (action == null || !mounted) return;
    final api = context.api;
    final id = a.integer('id');
    switch (action) {
      case PhotoAction.view:
        _showImage(url!);
      case PhotoAction.camera:
      case PhotoAction.gallery:
        final f = await pickPhotoFile(context, action == PhotoAction.camera ? ImageSource.camera : ImageSource.gallery);
        if (f == null || !mounted) return;
        final ok = await runBusy(context, () => api.multipart('images/articles/$id', {}, file: f), success: tr('Photo mise à jour.'));
        if (ok != null) _reload();
      case PhotoAction.remove:
        final sure = await confirm(context, tr('Supprimer la photo'), tr('La photo de « {nom} » sera supprimée.', {'nom': a.articleName}),
            ok: tr('Supprimer'), danger: true);
        if (!sure || !mounted) return;
        final ok = await runBusy<bool>(context, () async {
          await api.delete('images/articles/$id');
          return true;
        }, success: tr('Photo supprimée.'));
        if (ok == true) _reload();
    }
  }

  void _showImage(String url) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.white,
        child: InteractiveViewer(child: Padding(padding: const EdgeInsets.all(12), child: Image.network(url))),
      ),
    );
  }

  Future<void> _menu(String action) async {
    final a = _article;
    if (a == null) return;
    switch (action) {
      case 'edit':
        await _editRecord(a);
      case 'photo':
        await _photoMenu(a);
      case 'toggle':
        await _toggleActive(a);
      case 'delete':
        await _delete(a);
    }
  }

  Future<void> _editPrices(Json a) async {
    if (await editPrices(context, a)) {
      _changed = true;
      _view.currentState?.reload();
    }
  }

  Future<void> _adjust(Json a) async {
    final res = await adjustStock(context,
        articleId: a.integer('id'), name: a.articleName, current: a.stockQty, seuil: a.obj('stock')?.dblOrNull('seuil_min'), unit: a.unit);
    if (res != null) {
      _changed = true;
      _view.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: darkAppBar(tr('Fiche article'), actions: [
          if (_article != null)
            PopupMenuButton<String>(
              tooltip: tr('Actions'),
              onSelected: _menu,
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(tr('Modifier la fiche')))),
                PopupMenuItem(value: 'photo', child: ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text(tr('Changer la photo')))),
                PopupMenuItem(
                  value: 'toggle',
                  child: ListTile(
                    leading: Icon(_article!.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    title: Text(_article!.isActive ? tr('Désactiver') : tr('Activer')),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                    title: Text(tr('Supprimer'), style: const TextStyle(color: AppColors.danger)),
                  ),
                ),
              ],
            ),
        ]),
        body: AsyncView<Json>(
          key: _view,
          load: _load,
          builder: (context, a, reload) => RefreshIndicator(onRefresh: reload, child: _body(context, a)),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Json a) {
    final ar = a.articleNameAr;
    final stock = a.stockQty;
    final m = a.margin;
    final imageUrl = context.api.imageUrl(a['image']);
    final path = [a.familyName, a.categoryName, a.subCategoryName].whereType<String>().toSet().join(' › ');
    return ListView(padding: EdgeInsets.zero, children: [
      // En-tête : image sur fond clair.
      Container(
        height: 230,
        color: Colors.white,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => _photoMenu(a),
          child: Stack(alignment: Alignment.center, children: [
            imageUrl == null
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    ItemThumb(label: a.articleName, size: 130),
                    const SizedBox(height: 8),
                    Text(tr('Toucher pour ajouter une photo'), style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                  ])
                : Hero(
                    tag: 'article-${a.integer('id')}',
                    child: Image.network(imageUrl, fit: BoxFit.contain, errorBuilder: (_, _, _) => ItemThumb(label: a.articleName, size: 130)),
                  ),
            PositionedDirectional(
              end: 0,
              bottom: 0,
              child: Material(
                color: Colors.white,
                elevation: 2,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: tr('Photo'),
                  icon: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
                  onPressed: () => _photoMenu(a),
                ),
              ),
            ),
          ]),
        ),
      ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(a.articleName, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, height: 1.2)),
          if (ar != null) ...[
            const SizedBox(height: 4),
            appLang.isAr
                ? Text(ar, textDirection: TextDirection.ltr, textAlign: TextAlign.end, style: const TextStyle(fontSize: 18, color: AppColors.muted, fontWeight: FontWeight.w600))
                : ArabicText(ar, textAlign: TextAlign.right, style: const TextStyle(fontSize: 18, color: AppColors.muted, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            a.isActive ? Badge2(tr('Actif'), color: AppColors.success, icon: Icons.check_circle) : Badge2(tr('Inactif'), color: AppColors.muted),
            if (!a.isPriced) Badge2(tr('À tarifer'), color: AppColors.warning, icon: Icons.sell_outlined),
            if (a.hasPromo) Badge2(tr('En promotion'), color: AppColors.primary, icon: Icons.local_offer),
            if (a.brandName != null) Badge2(a.brandName!, color: AppColors.info, icon: Icons.verified_outlined),
          ]),
          const SizedBox(height: 14),
          if (a.barcode.isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.qr_code_2, color: AppColors.ink),
                title: Text(a.barcode, style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
                subtitle: Text(tr('Code-barres')),
                trailing: IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: tr('Copier'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: a.barcode));
                    showInfo(context, tr('Code-barres copié.'));
                  },
                ),
              ),
            ),
          const SizedBox(height: 14),
          SectionCard(
            title: tr('Prix'),
            icon: Icons.sell_outlined,
            trailing: TextButton.icon(onPressed: () => _editPrices(a), icon: const Icon(Icons.edit, size: 18), label: Text(tr('Modifier'))),
            children: [
              Row(children: [
                Expanded(child: _PriceBox(label: tr('Prix de vente'), value: a.prixVente, highlight: true)),
                const SizedBox(width: 10),
                Expanded(child: _PriceBox(label: tr('Prix d’achat'), value: a.prixAchat)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _PriceBox(label: tr('Prix de gros'), value: a.prixGros)),
                const SizedBox(width: 10),
                Expanded(child: _PriceBox(label: tr('Prix promo'), value: a.prixPromo, color: AppColors.primary)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Text(tr('Marge sur vente'), style: const TextStyle(color: AppColors.muted)),
                const Spacer(),
                if (m != null && a.prixVente > 0)
                  Text('${money(a.prixVente - a.prixAchat)}  ·  ', style: const TextStyle(color: AppColors.muted)),
                Text(
                  m == null ? '—' : percent(m),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: m == null ? AppColors.muted : (m < 0 ? AppColors.danger : (m < 10 ? AppColors.warning : AppColors.success)),
                  ),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: tr('Stock'),
            icon: Icons.warehouse_outlined,
            trailing: TextButton.icon(onPressed: () => _adjust(a), icon: const Icon(Icons.tune, size: 18), label: Text(tr('Ajuster'))),
            children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(stock == null ? '—' : qty(stock, a.unit),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: stock == null || stock <= 0 ? AppColors.danger : (stock <= a.stockMin ? AppColors.warning : AppColors.ink),
                        )),
                    Text(tr('Seuil minimum : {seuil}', {'seuil': qty(a.stockMin, a.unit)}), style: const TextStyle(color: AppColors.muted)),
                  ]),
                ),
                Badge2(
                  stock == null || stock <= 0 ? tr('Rupture') : (stock <= a.stockMin ? tr('Sous le seuil') : tr('En stock')),
                  color: stock == null || stock <= 0 ? AppColors.danger : (stock <= a.stockMin ? AppColors.warning : AppColors.success),
                ),
              ]),
              if (stock != null && a.prixAchat > 0) ...[
                const Divider(height: 22),
                InfoRow(tr('Valeur (achat)'), money(stock * a.prixAchat)),
              ],
            ],
          ),
          const SizedBox(height: 14),
          SectionCard(
              title: tr('Classement'),
              icon: Icons.category_outlined,
              trailing: TextButton.icon(onPressed: () => _editRecord(a), icon: const Icon(Icons.edit, size: 18), label: Text(tr('Modifier'))),
              children: [
            InfoRow(tr('Catégorie'), path),
            InfoRow(tr('Marque'), a.brandName ?? ''),
            InfoRow(tr('Unité'), a.unit),
            InfoRow(tr('Référence interne'), '#${a.integer('id')}'),
          ]),
          if (a.strOrNull('description') != null) ...[
            const SizedBox(height: 14),
            SectionCard(title: tr('Description'), icon: Icons.notes, children: [
              Text(a.str('description'), style: const TextStyle(height: 1.45)),
            ]),
          ],
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _toggleActive(a),
                icon: Icon(a.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                label: Text(a.isActive ? tr('Désactiver') : tr('Activer')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () => _delete(a),
                icon: const Icon(Icons.delete_outline),
                label: Text(tr('Supprimer')),
              ),
            ),
          ]),
        ]),
      ),
    ]);
  }
}

class _PriceBox extends StatelessWidget {
  const _PriceBox({required this.label, required this.value, this.highlight = false, this.color});

  final String label;
  final double value;
  final bool highlight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primary.withValues(alpha: 0.07) : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: highlight ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            value > 0 ? money(value) : '—',
            style: TextStyle(
              fontSize: highlight ? 19 : 16,
              fontWeight: FontWeight.w800,
              color: value > 0 ? (highlight ? AppColors.primary : (color ?? AppColors.ink)) : AppColors.muted,
            ),
          ),
        ),
      ]),
    );
  }
}

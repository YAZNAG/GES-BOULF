import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/article.dart';
import '../core/format.dart';
import '../core/theme.dart';
import 'common.dart';
import 'pickers.dart';
import 'scanner.dart';
import 'unknown_product.dart';

/// Ligne de document d'achat (bon de commande, bon de réception).
class DocLine {
  DocLine(this.article, {double quantity = 1, String? price, String? salePrice, this.orderLineId, this.info})
      : quantity = TextEditingController(text: qtyInput(quantity)),
        price = TextEditingController(text: price ?? ''),
        salePrice = TextEditingController(text: salePrice ?? '');

  final Json article;
  final TextEditingController quantity;
  final TextEditingController price;
  final TextEditingController salePrice;
  final int? orderLineId;

  /// Information affichée sous le nom (ex. « Commandé 24 · reste 12 »).
  final String? info;

  int get articleId => article.integer('id');
  String get name => article.articleName;

  double get qtyValue => parseInput(quantity.text) ?? 0;
  double get priceValue => parseInput(price.text) ?? 0;
  double? get salePriceValue => parseInput(salePrice.text);
  double get total => round2(qtyValue * priceValue);

  void dispose() {
    quantity.dispose();
    price.dispose();
    salePrice.dispose();
  }
}

/// Éditeur de lignes : ajout par recherche ou scan continu, quantité, prix d'achat, prix de vente facultatif.
class LinesEditor extends StatefulWidget {
  const LinesEditor({
    super.key,
    required this.lines,
    required this.onChanged,
    this.priceLabel = 'Prix d’achat',
    this.showSalePrice = false,
    this.errors = const {},
    this.priceErrorKey = 'prix_achat',
    this.allowAdd = true,
  });

  final List<DocLine> lines;
  final VoidCallback onChanged;
  final String priceLabel;
  final bool showSalePrice;
  final Map<String, List<String>> errors;
  final String priceErrorKey;
  final bool allowAdd;

  @override
  State<LinesEditor> createState() => _LinesEditorState();
}

class _LinesEditorState extends State<LinesEditor> {
  DocLine _add(Json a) {
    final existing = widget.lines.where((l) => l.articleId == a.integer('id')).firstOrNull;
    if (existing != null) {
      existing.quantity.text = qtyInput(existing.qtyValue + 1);
      widget.onChanged();
      setState(() {});
      return existing;
    }
    final line = DocLine(a, price: priceInput(a.prixAchat));
    widget.lines.add(line);
    widget.onChanged();
    setState(() {});
    return line;
  }

  Future<void> _search() async {
    final a = await pickProduct(context);
    if (a != null) _add(a);
  }

  Future<void> _scan() async {
    final api = context.api;
    final nav = Navigator.of(context);
    String? inconnu;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScannerPage(
          title: 'Scanner les articles',
          onCode: (code) async {
            try {
              final a = await lookupArticle(api, code);
              if (a == null) {
                inconnu = code;
                nav.pop();
                return null;
              }
              final line = _add(a);
              return '${a.articleName} — quantité ${qty(line.qtyValue)}';
            } on ApiException catch (e) {
              return '!${e.message}';
            }
          },
        ),
      ),
    );
    if (inconnu != null && mounted) {
      final a = await offerAddProduct(context, inconnu!);
      if (a != null && mounted) _add(a);
    }
    if (mounted) setState(() {});
  }

  void _step(DocLine l, double delta) {
    final v = (l.qtyValue + delta).clamp(0, double.infinity).toDouble();
    l.quantity.text = qtyInput(v);
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.allowAdd)
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: _search, icon: const Icon(Icons.search), label: const Text('Ajouter'))),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
              onPressed: _scan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scanner'),
            ),
          ),
        ]),
      if (widget.errors['lignes'] != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(widget.errors['lignes']!.first, style: const TextStyle(color: AppColors.danger)),
        ),
      const SizedBox(height: 10),
      if (widget.lines.isEmpty)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            color: AppColors.surface,
          ),
          child: const Column(children: [
            Icon(Icons.playlist_add, size: 32, color: AppColors.muted),
            SizedBox(height: 6),
            Text('Aucune ligne. Ajoutez ou scannez des articles.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
          ]),
        ),
      for (var i = 0; i < widget.lines.length; i++) _line(i, widget.lines[i]),
    ]);
  }

  Widget _line(int i, DocLine l) {
    final qtyErr = widget.errors['lignes.$i.quantite']?.first;
    final priceErr = widget.errors['lignes.$i.${widget.priceErrorKey}']?.first;
    final otherErr = widget.errors['lignes.$i.article_id']?.first;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: qtyErr != null || otherErr != null || priceErr != null ? AppColors.danger : AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          ItemThumb(path: l.article['image'], label: l.name, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                [if (l.article.barcode.isNotEmpty) l.article.barcode, ?l.info].join(' · '),
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            tooltip: 'Retirer',
            onPressed: () {
              widget.lines.removeAt(i).dispose();
              widget.onChanged();
              setState(() {});
            },
          ),
        ]),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconButton.outlined(onPressed: () => _step(l, -1), icon: const Icon(Icons.remove)),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: l.quantity,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Quantité', errorText: qtyErr, errorMaxLines: 3, isDense: true),
              onChanged: (_) => widget.onChanged(),
            ),
          ),
          const SizedBox(width: 4),
          IconButton.outlined(onPressed: () => _step(l, 1), icon: const Icon(Icons.add)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: l.price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: widget.priceLabel, suffixText: 'DH', errorText: priceErr, errorMaxLines: 3, isDense: true),
              onChanged: (_) => widget.onChanged(),
            ),
          ),
          const SizedBox(width: 6),
        ]),
        if (widget.showSalePrice) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: l.salePrice,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Prix de vente (facultatif)',
                  hintText: l.article.prixVente > 0 ? 'Actuel : ${priceInput(l.article.prixVente)}' : 'Non tarifé',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  suffixText: 'DH',
                  isDense: true,
                  errorText: widget.errors['lignes.$i.prix_vente']?.first,
                ),
                onChanged: (_) => widget.onChanged(),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 110,
              child: Text(money(l.total),
                  textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
            ),
            const SizedBox(width: 6),
          ]),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 6),
            child: Text('Total ligne : ${money(l.total)}',
                textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted)),
          ),
        if (otherErr != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(otherErr, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          ),
      ]),
    );
  }
}

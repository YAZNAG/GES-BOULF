import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import 'common.dart';

/// Ajustement de stock (POST stock/ajuster). Renvoie la ligne de stock mise à jour, ou null.
Future<Json?> adjustStock(BuildContext context,
    {required int articleId, required String name, double? current, double? seuil, String? unit}) {
  return showModalBottomSheet<Json>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AdjustSheet(articleId: articleId, name: name, current: current ?? 0, seuil: seuil, unit: unit ?? ''),
  );
}

class _AdjustSheet extends StatefulWidget {
  const _AdjustSheet({required this.articleId, required this.name, required this.current, required this.seuil, required this.unit});

  final int articleId;
  final String name;
  final double current;
  final double? seuil;
  final String unit;

  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> {
  String _mode = 'plus';
  String _motif = 'ajustement';
  final _qty = TextEditingController();
  final _note = TextEditingController();
  late final _seuil = TextEditingController(text: widget.seuil == null ? '' : qtyInput(widget.seuil!));
  bool _busy = false;
  Map<String, List<String>> _errors = {};

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    _seuil.dispose();
    super.dispose();
  }

  double? get _result {
    final q = parseInput(_qty.text);
    if (q == null) return null;
    return switch (_mode) {
      'inventaire' => q,
      'plus' => widget.current + q,
      _ => widget.current - q,
    };
  }

  Future<void> _save() async {
    final q = parseInput(_qty.text);
    if (q == null || q < 0 || (q == 0 && _mode != 'inventaire')) {
      setState(() => _errors = {'quantite': ['Saisissez une quantité valide.']});
      return;
    }
    setState(() {
      _busy = true;
      _errors = {};
    });
    try {
      final seuil = parseInput(_seuil.text);
      final res = await context.api.post('stock/ajuster', {
        'article_id': widget.articleId,
        'mode': _mode,
        'quantite': q,
        if (_mode == 'moins') 'motif': _motif,
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
        if (seuil != null && seuil != widget.seuil) 'seuil_min': seuil,
      });
      if (!mounted) return;
      showSuccess(context, 'Stock mis à jour.');
      Navigator.pop(context, res is Map ? res.cast<String, dynamic>() : <String, dynamic>{});
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errors = e.errors);
      if (e.errors.isEmpty || e.errors.keys.every((k) => k != 'quantite' && k != 'seuil_min')) showError(context, e);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          const Text('Ajuster le stock', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(widget.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'plus', label: Text('Ajouter'), icon: Icon(Icons.add)),
              ButtonSegment(value: 'moins', label: Text('Retirer'), icon: Icon(Icons.remove)),
              ButtonSegment(value: 'inventaire', label: Text('Compter'), icon: Icon(Icons.fact_check_outlined)),
            ],
            selected: {_mode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _qty,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _mode == 'inventaire' ? 'Quantité comptée' : 'Quantité',
              suffixText: widget.unit,
              errorText: _errors['quantite']?.first,
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_mode == 'moins') ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              for (final (k, l) in const [('perte', 'Perte'), ('don', 'Don'), ('retour', 'Retour'), ('ajustement', 'Ajustement')])
                ChoiceChip(
                  label: Text(l),
                  selected: _motif == k,
                  showCheckmark: false,
                  selectedColor: AppColors.primary.withValues(alpha: 0.12),
                  onSelected: (_) => setState(() => _motif = k),
                ),
            ]),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _seuil,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Seuil minimum', errorText: _errors['seuil_min']?.first),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note'))),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Text('Actuel : ${qty(widget.current, widget.unit)}', style: const TextStyle(color: AppColors.muted)),
              const Spacer(),
              const Icon(Icons.arrow_forward, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Text(
                r == null ? '—' : qty(r, widget.unit),
                style: TextStyle(fontWeight: FontWeight.w800, color: r != null && r < 0 ? AppColors.danger : AppColors.ink),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _busy || (r != null && r < 0) ? null : _save,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: const Text('Enregistrer'),
          ),
        ]),
      ),
    );
  }
}

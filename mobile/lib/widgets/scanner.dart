import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/i18n.dart';
import '../core/theme.dart';

/// Scan d'un code-barres. Mode simple : renvoie le code lu.
/// Mode continu (`onCode`) : reste ouvert, chaque code est transmis (inventaire, saisie de lignes).
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key, this.title = 'Scanner un code-barres', this.onCode});

  final String title;
  final Future<String?> Function(String code)? onCode;

  static Future<String?> scan(BuildContext context, {String title = 'Scanner un code-barres'}) =>
      Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => ScannerPage(title: title)));

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.qrCode,
    ],
    detectionSpeed: DetectionSpeed.normal,
  );
  String? _last;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _feedback;
  bool _feedbackOk = true;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final code = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (code == null || _busy) return;
    final now = DateTime.now();
    // Évite de relire le même code en boucle.
    if (code == _last && now.difference(_lastAt) < const Duration(seconds: 2)) return;
    _last = code;
    _lastAt = now;
    HapticFeedback.mediumImpact();

    if (widget.onCode == null) {
      Navigator.of(context).pop(code);
      return;
    }
    setState(() => _busy = true);
    final msg = await widget.onCode!(code);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _feedback = msg ?? code;
      _feedbackOk = msg == null || !msg.startsWith('!');
      if (!_feedbackOk) _feedback = msg!.substring(1);
    });
  }

  Future<void> _manual() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Saisir le code')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: tr('Code-barres')),
          onSubmitted: (v) => Navigator.pop(c, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Annuler'))),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: Text(tr('Valider'))),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;
    await _onDetect(BarcodeCapture(barcodes: [Barcode(rawValue: code.trim())]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        title: Text(tr(widget.title)),
        actions: [
          IconButton(icon: const Icon(Icons.flash_on), tooltip: tr('Lampe'), onPressed: () => _controller.toggleTorch()),
          IconButton(icon: const Icon(Icons.cameraswitch), tooltip: tr('Caméra'), onPressed: () => _controller.switchCamera()),
        ],
      ),
      body: Stack(children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                tr('Caméra indisponible. Autorisez l’accès à la caméra dans les réglages, ou saisissez le code.'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        Center(
          child: Container(
            width: 280,
            height: 170,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_feedback != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _feedbackOk ? AppColors.success : AppColors.danger,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  Icon(_feedbackOk ? Icons.check_circle : Icons.error, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_feedback!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                ]),
              ),
            if (_busy) const LinearProgressIndicator(),
            Text(
              widget.onCode == null ? tr('Placez le code-barres dans le cadre') : tr('Scannez les articles les uns après les autres'),
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                  onPressed: _manual,
                  icon: const Icon(Icons.keyboard),
                  label: Text(tr('Saisir')),
                ),
              ),
              if (widget.onCode != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.done),
                    label: Text(tr('Terminé')),
                  ),
                ),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }
}

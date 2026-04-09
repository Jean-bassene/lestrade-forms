// ============================================================================
// screens/scanner_screen.dart — Scanner QR code + import questionnaire
// ============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import '../services/db_service.dart';
import 'formulaire_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  MobileScannerController? _controller;
  bool _scanning = false;
  bool _processing = false;
  String? _lastResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_scanning) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.stop();
    } else if (state == AppLifecycleState.resumed) {
      _controller?.start();
    }
  }

  void _startScan() {
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    setState(() { _scanning = true; _lastResult = null; });
  }

  void _stopScan() {
    _controller?.stop();
    _controller?.dispose();
    _controller = null;
    setState(() => _scanning = false);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() => _processing = true);
    _stopScan();

    await _processPayload(raw);
    setState(() => _processing = false);
  }

  Future<void> _processPayload(String payload) async {
    setState(() => _lastResult = payload);

    // 1. QR de connexion API : lestrade://192.168.1.x:8765
    if (payload.startsWith('lestrade://')) {
      final uri = Uri.tryParse(payload.replaceFirst('lestrade://', 'http://'));
      if (uri != null && uri.host.isNotEmpty) {
        final url = 'http://${uri.host}:${uri.port}';
        await ApiService.setBaseUrl(url);
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Serveur configuré'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 48),
                const SizedBox(height: 12),
                Text(url, style: const TextStyle(fontFamily: 'monospace')),
                const SizedBox(height: 8),
                const Text('L\'adresse du serveur a été enregistrée automatiquement.'),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

    // 2. QR questionnaire JSON : {"v":"1.0","uid":"LEST-...","ip":"192.168.x.x","port":8765,...}
    if (payload.startsWith('{')) {
      try {
        final Map<String, dynamic> meta = Map<String, dynamic>.from(
          jsonDecode(payload) as Map,
        );
        final uid = meta['uid']?.toString() ?? '';
        final ip  = meta['ip']?.toString()  ?? '';
        final port = meta['port'] is int ? meta['port'] as int : 8765;

        // Auto-configurer le serveur si l'IP est dans le QR
        if (ip.isNotEmpty && ip != '127.0.0.1') {
          final serverUrl = 'http://$ip:$port';
          await ApiService.setBaseUrl(serverUrl);
        }

        if (uid.isEmpty) { _showError('UID introuvable dans le QR'); return; }
        _showImportDialog(uid, payload);
        return;
      } catch (_) {
        // pas du JSON valide → continuer vers détection UID
      }
    }

    // 3. UID seul (ancien format) : LEST-XXXX-XXXX
    final uidMatch = RegExp(r'LEST-[A-Z0-9]{4}-[A-Z0-9]{4}').firstMatch(payload);
    if (uidMatch == null) {
      _showError('QR code non reconnu');
      return;
    }

    final uid = uidMatch.group(0)!;
    _showImportDialog(uid, payload);
  }

  void _showImportDialog(String uid, String raw) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Questionnaire détecté'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('UID : $uid'),
            const SizedBox(height: 8),
            const Text('Voulez-vous importer ce questionnaire depuis le serveur ?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _importByUid(uid);
            },
            child: const Text('Importer'),
          ),
        ],
      ),
    );
  }

  Future<void> _importByUid(String uid) async {
    // Afficher un loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Importation en cours...'),
          ],
        ),
      ),
    );

    try {
      final serverOk = await ApiService.checkHealth();
      if (!serverOk) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        _showError('Serveur inaccessible. Connectez-vous au réseau local.');
        return;
      }

      final full = await ApiService.fetchQuestionnaireByUid(uid);
      await DbService.saveQuestionnaire(full);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Questionnaire "${full.questionnaire.nom}" importé !'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Saisir',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      FormulaireScreen(questId: full.questionnaire.id),
                ),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showError('Erreur lors de l\'importation : $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // ── Saisie manuelle d'UID ────────────────────────────────────────────────
  Future<void> _manualEntry() async {
    final ctrl = TextEditingController();
    final uid = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Saisir un UID'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'LEST-XXXX-XXXX',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim().toUpperCase()),
            child: const Text('Importer'),
          ),
        ],
      ),
    );
    if (uid != null && uid.isNotEmpty) {
      await _importByUid(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard),
            onPressed: _manualEntry,
            tooltip: 'Saisir UID manuellement',
          ),
        ],
      ),
      body: _scanning
          ? _buildScanner()
          : _buildIdle(),
    );
  }

  Widget _buildIdle() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_scanner, size: 100, color: Color(0xFF003366)),
            const SizedBox(height: 24),
            const Text(
              'Scanner un QR code de questionnaire',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Le QR code est affiché dans l\'application Desktop',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Démarrer le scanner'),
              onPressed: _processing ? null : _startScan,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.keyboard),
              label: const Text('Saisir un UID manuellement'),
              onPressed: _manualEntry,
            ),
            if (_lastResult != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lastResult!,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller!,
          onDetect: _onDetect,
        ),
        // Overlay avec cadre de scan
        CustomPaint(
          painter: _ScanOverlayPainter(),
          child: const SizedBox.expand(),
        ),
        // Bouton stop
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.stop),
              label: const Text('Arrêter'),
              onPressed: _stopScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
            ),
          ),
        ),
        // Instructions
        Positioned(
          top: 40,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Pointez la caméra sur le QR code',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Overlay dessiné autour du cadre de scan
class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    const rectSize = 250.0;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: rectSize,
      height: rectSize,
    );

    // Zones sombres autour du carré
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, rect.top), paint);
    canvas.drawRect(Rect.fromLTRB(0, rect.bottom, size.width, size.height), paint);
    canvas.drawRect(Rect.fromLTRB(0, rect.top, rect.left, rect.bottom), paint);
    canvas.drawRect(Rect.fromLTRB(rect.right, rect.top, size.width, rect.bottom), paint);

    // Coins colorés
    final corner = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    const cLen = 24.0;

    // Coin haut-gauche
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(cLen, 0), corner);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, cLen), corner);
    // Coin haut-droit
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(-cLen, 0), corner);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, cLen), corner);
    // Coin bas-gauche
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(cLen, 0), corner);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(0, -cLen), corner);
    // Coin bas-droit
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(-cLen, 0), corner);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(0, -cLen), corner);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ============================================================================
// screens/scanner_screen.dart — Scanner QR code + import questionnaire
// ============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/db_service.dart';
import '../services/sync_service.dart';
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
    final l10n = AppLocalizations.of(context)!;
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
            title: Text(l10n.serverConfigured),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 48),
                const SizedBox(height: 12),
                Text(url, style: const TextStyle(fontFamily: 'monospace')),
                const SizedBox(height: 8),
                Text(l10n.serverAddressSaved),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.ok),
              ),
            ],
          ),
        );
        return;
      }
    }

    // 2. QR questionnaire JSON
    if (payload.startsWith('{')) {
      try {
        final Map<String, dynamic> meta = Map<String, dynamic>.from(
          jsonDecode(payload) as Map,
        );
        final uid = meta['uid']?.toString() ?? '';
        final ip  = meta['ip']?.toString()  ?? '';
        final port = meta['port'] is int ? meta['port'] as int : 8765;

        final panierUrl = meta['panier_url']?.toString() ?? '';
        if (panierUrl.isNotEmpty) {
          await SyncService.setPanierUrl(panierUrl);
        }

        final coordinatorEmail = meta['coordinator_email']?.toString() ?? '';
        if (coordinatorEmail.isNotEmpty) {
          await SyncService.setCoordinatorEmail(coordinatorEmail);
        }

        if (ip.isNotEmpty && ip != '127.0.0.1') {
          final serverUrl = 'http://$ip:$port';
          await ApiService.setBaseUrl(serverUrl);
        }

        if (uid.isEmpty) { _showError(l10n.uidNotFound); return; }
        _showImportDialog(uid, panierUrl: panierUrl.isNotEmpty ? panierUrl : null);
        return;
      } catch (_) {}
    }

    // 3. UID seul (ancien format) : LEST-XXXX-XXXX
    final uidMatch = RegExp(r'LEST-[A-Z0-9]{4}-[A-Z0-9]{4}').firstMatch(payload);
    if (uidMatch == null) {
      _showError(l10n.qrNotRecognized);
      return;
    }

    _showImportDialog(uidMatch.group(0)!);
  }

  void _showImportDialog(String uid, {String? panierUrl}) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.surveyDetected),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.uidLabel(uid)),
            const SizedBox(height: 8),
            Text(l10n.importSurveyQuestion),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _importByUid(uid, panierUrl: panierUrl);
            },
            child: Text(l10n.import),
          ),
        ],
      ),
    );
  }

  Future<void> _importByUid(String uid, {String? panierUrl}) async {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(l10n.importing),
          ],
        ),
      ),
    );

    try {
      final full = await ApiService.fetchQuestionnaireByUid(uid, panierUrl: panierUrl);
      await DbService.saveQuestionnaire(full);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.surveyImported(full.questionnaire.nom)),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: l10n.enter,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FormulaireScreen(questId: full.questionnaire.id),
                ),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showError(l10n.importError(e.toString()));
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> _manualEntry() async {
    final l10n = AppLocalizations.of(context)!;
    final ctrl = TextEditingController();
    final uid = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.enterUidTitle),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'LEST-XXXX-XXXX',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim().toUpperCase()),
            child: Text(l10n.import),
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scannerTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard),
            onPressed: _manualEntry,
            tooltip: l10n.enterUidManuallyTooltip,
          ),
        ],
      ),
      body: _scanning ? _buildScanner(l10n) : _buildIdle(l10n),
    );
  }

  Widget _buildIdle(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_scanner, size: 100, color: Color(0xFF003366)),
            const SizedBox(height: 24),
            Text(
              l10n.scanSurveyQr,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.qrShownInDesktop,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: Text(l10n.startScanner),
              onPressed: _processing ? null : _startScan,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.keyboard),
              label: Text(l10n.enterUidManually),
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

  Widget _buildScanner(AppLocalizations l10n) {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller!,
          onDetect: _onDetect,
        ),
        CustomPaint(
          painter: _ScanOverlayPainter(),
          child: const SizedBox.expand(),
        ),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.stop),
              label: Text(l10n.stopScanner),
              onPressed: _stopScan,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ),
        ),
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
              child: Text(
                l10n.pointCameraAtQr,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

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

    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, rect.top), paint);
    canvas.drawRect(Rect.fromLTRB(0, rect.bottom, size.width, size.height), paint);
    canvas.drawRect(Rect.fromLTRB(0, rect.top, rect.left, rect.bottom), paint);
    canvas.drawRect(Rect.fromLTRB(rect.right, rect.top, size.width, rect.bottom), paint);

    final corner = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    const cLen = 24.0;

    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(cLen, 0), corner);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, cLen), corner);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(-cLen, 0), corner);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, cLen), corner);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(cLen, 0), corner);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(0, -cLen), corner);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(-cLen, 0), corner);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(0, -cLen), corner);
  }

  @override
  bool shouldRepaint(_) => false;
}

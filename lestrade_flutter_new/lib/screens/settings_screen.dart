// ============================================================================
// screens/settings_screen.dart — Paramètres (serveur + infos)
// ============================================================================

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlCtrl = TextEditingController();
  bool _testing = false;
  bool? _testResult;
  String _testMsg = '';
  bool _showManual = false;  // section manuelle masquée par défaut

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final url = await ApiService.getBaseUrl();
    if (mounted) setState(() => _urlCtrl.text = url);
  }

  Future<void> _save() async {
    final raw = _urlCtrl.text.trim();
    if (raw.isEmpty) return;
    final url = ApiService.buildUrl(raw);
    await ApiService.setBaseUrl(url);
    _urlCtrl.text = url;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adresse enregistrée'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _test() async {
    final raw = _urlCtrl.text.trim();
    if (raw.isEmpty) return;
    final url = ApiService.buildUrl(raw);
    setState(() { _testing = true; _testResult = null; });
    final ok = await ApiService.checkHealth(baseUrl: url);
    if (mounted) {
      setState(() {
        _testing = false;
        _testResult = ok;
        _testMsg = ok ? 'Serveur accessible !' : 'Impossible de joindre le serveur';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Statut connexion actuelle ────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Connexion serveur',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.lan, color: Color(0xFF003366)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _urlCtrl.text.isNotEmpty
                              ? _urlCtrl.text
                              : 'Non configuré — scannez le QR du coordinateur',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: _urlCtrl.text.isNotEmpty
                                ? Colors.black87
                                : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Bouton tester
                  OutlinedButton.icon(
                    icon: _testing
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.wifi_find),
                    label: const Text('Tester la connexion'),
                    onPressed: _testing ? null : _test,
                  ),
                  if (_testResult != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _testResult! ? Icons.check_circle : Icons.error,
                          color: _testResult! ? Colors.green : Colors.red,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(_testMsg,
                            style: TextStyle(
                                color: _testResult! ? Colors.green : Colors.red)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Saisie manuelle — masquée par défaut
                  InkWell(
                    onTap: () => setState(() => _showManual = !_showManual),
                    child: Row(
                      children: [
                        Icon(_showManual ? Icons.expand_less : Icons.expand_more,
                            size: 18, color: Colors.grey),
                        const SizedBox(width: 4),
                        const Text('Configurer manuellement',
                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (_showManual) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _urlCtrl,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '192.168.1.10',
                        helperText: 'IP du PC coordinateur (port 8765 ajouté auto)',
                      ),
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Enregistrer'),
                      onPressed: _save,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── À propos ─────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('À propos',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Lestrade Forms — Application de collecte terrain'),
                  const Text('Version 1.0.0'),
                  const SizedBox(height: 8),
                  Text(
                    'Collecte offline · Sync réseau local · Analyse Desktop',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

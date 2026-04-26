// ============================================================================
// screens/settings_screen.dart — Paramètres (serveur + langue + infos)
// ============================================================================

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
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
  bool _showManual = false;

  // Supported languages: (code, native name)
  static const _languages = [
    ('fr', 'Français'),
    ('en', 'English'),
    ('ar', 'العربية'),
  ];

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
    final l10n = AppLocalizations.of(context)!;
    final raw = _urlCtrl.text.trim();
    if (raw.isEmpty) return;
    final url = ApiService.buildUrl(raw);
    await ApiService.setBaseUrl(url);
    _urlCtrl.text = url;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.addressSaved),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _test() async {
    final l10n = AppLocalizations.of(context)!;
    final raw = _urlCtrl.text.trim();
    if (raw.isEmpty) return;
    final url = ApiService.buildUrl(raw);
    setState(() { _testing = true; _testResult = null; });
    final ok = await ApiService.checkHealth(baseUrl: url);
    if (mounted) {
      setState(() {
        _testing = false;
        _testResult = ok;
        _testMsg = ok ? l10n.serverAccessible : l10n.cannotReachServer;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Connexion serveur ────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.serverConnection,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.lan, color: Color(0xFF003366)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _urlCtrl.text.isNotEmpty
                              ? _urlCtrl.text
                              : l10n.notConfigured,
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
                  OutlinedButton.icon(
                    icon: _testing
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.wifi_find),
                    label: Text(l10n.testConnection),
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
                  InkWell(
                    onTap: () => setState(() => _showManual = !_showManual),
                    child: Row(
                      children: [
                        Icon(_showManual ? Icons.expand_less : Icons.expand_more,
                            size: 18, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(l10n.configureManually,
                            style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (_showManual) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _urlCtrl,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: '192.168.1.10',
                        helperText: l10n.coordinatorIpHelper,
                      ),
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: Text(l10n.save),
                      onPressed: _save,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Langue ───────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.language,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ..._languages.map((lang) {
                    final (code, name) = lang;
                    final selected = currentLocale == code;
                    return RadioListTile<String>(
                      title: Text(name),
                      value: code,
                      groupValue: currentLocale,
                      dense: true,
                      activeColor: const Color(0xFF003366),
                      selected: selected,
                      onChanged: (v) {
                        if (v != null) {
                          LestradeApp.of(context)?.setLocale(Locale(v));
                        }
                      },
                    );
                  }),
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
                  Text(l10n.aboutTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(l10n.aboutDesc),
                  Text(l10n.version),
                  const SizedBox(height: 8),
                  Text(
                    l10n.aboutFeatures,
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

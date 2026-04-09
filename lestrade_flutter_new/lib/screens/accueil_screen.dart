// ============================================================================
// screens/accueil_screen.dart — Tableau de bord
// ============================================================================

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/db_service.dart';
import '../services/sync_service.dart';

class AccueilScreen extends StatefulWidget {
  const AccueilScreen({super.key});

  @override
  State<AccueilScreen> createState() => _AccueilScreenState();
}

class _AccueilScreenState extends State<AccueilScreen> {
  bool _serverOnline = false;
  bool _checking = true;
  int _pendingCount = 0;
  int _questCount = 0;
  String _baseUrl = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _checking = true);
    final url = await ApiService.getBaseUrl();
    final online = await ApiService.checkHealth();
    final pending = await DbService.countPending();
    final quests = await DbService.getQuestionnaires();
    if (mounted) {
      setState(() {
        _baseUrl = url;
        _serverOnline = online;
        _pendingCount = pending;
        _questCount = quests.length;
        _checking = false;
      });
    }
  }

  Future<void> _sync() async {
    final result = await SyncService.syncPending();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
    await _refresh();
  }

  Future<void> _downloadQuests() async {
    try {
      final count = await SyncService.downloadQuestionnaires();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count questionnaire(s) téléchargé(s)'),
          backgroundColor: Colors.green,
        ),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lestrade Forms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Actualiser',
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Statut serveur ──────────────────────────────────────────
            _StatusCard(
              checking: _checking,
              online: _serverOnline,
              url: _baseUrl,
            ),
            const SizedBox(height: 12),

            // ── Statistiques ────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.list_alt,
                    label: 'Enquêtes',
                    value: '$_questCount',
                    color: const Color(0xFF003366),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.sync,
                    label: 'En attente',
                    value: '$_pendingCount',
                    color: _pendingCount > 0
                        ? Colors.orange
                        : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Actions rapides ─────────────────────────────────────────
            Text(
              'Actions rapides',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _ActionButton(
              icon: Icons.cloud_upload,
              label: 'Synchroniser les réponses',
              subtitle: _pendingCount > 0
                  ? '$_pendingCount réponse(s) offline à envoyer'
                  : 'Tout est synchronisé',
              color: _pendingCount > 0
                  ? const Color(0xFFF59E0B)
                  : Colors.grey,
              enabled: _serverOnline && _pendingCount > 0,
              onTap: _sync,
            ),
            const SizedBox(height: 8),

            _ActionButton(
              icon: Icons.cloud_download,
              label: 'Télécharger les enquêtes',
              subtitle: 'Récupère la liste depuis le serveur',
              color: const Color(0xFF003366),
              enabled: _serverOnline,
              onTap: _downloadQuests,
            ),
            const SizedBox(height: 8),

            _ActionButton(
              icon: Icons.edit_note,
              label: 'Nouvelle saisie',
              subtitle: 'Remplir un formulaire',
              color: Colors.teal,
              enabled: _questCount > 0,
              onTap: () {
                // Navigation vers onglet Enquêtes
                // TODO: changer l'onglet via callback si besoin
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets locaux ───────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final bool checking;
  final bool online;
  final String url;

  const _StatusCard({
    required this.checking,
    required this.online,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              checking
                  ? Icons.sync
                  : (online ? Icons.cloud_done : Icons.cloud_off),
              color: checking
                  ? Colors.orange
                  : (online ? Colors.green : Colors.red),
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    checking
                        ? 'Vérification...'
                        : (online ? 'Serveur connecté' : 'Serveur hors ligne'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (url.isNotEmpty)
                    Text(
                      url,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      'Non configuré — allez dans Paramètres',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.orange),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: enabled ? color : Colors.grey.shade300,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: enabled ? Colors.black87 : Colors.grey,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: enabled
            ? const Icon(Icons.chevron_right)
            : const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}

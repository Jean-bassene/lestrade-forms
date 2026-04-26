// ============================================================================
// screens/reponses_screen.dart — Liste des réponses offline + statut sync
// ============================================================================

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/questionnaire.dart';
import '../models/reponse.dart';
import '../services/db_service.dart';
import '../services/sync_service.dart';

class ReponsesScreen extends StatefulWidget {
  const ReponsesScreen({super.key});

  @override
  State<ReponsesScreen> createState() => _ReponsesScreenState();
}

class _ReponsesScreenState extends State<ReponsesScreen> {
  List<Questionnaire> _quests = [];
  Questionnaire? _selected;
  List<Reponse> _reponses = [];
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadQuests();
  }

  Future<void> _loadQuests() async {
    final quests = await DbService.getQuestionnaires();
    if (mounted) {
      setState(() {
        _quests = quests;
        _loading = false;
        if (_selected == null && quests.isNotEmpty) {
          _selected = quests.first;
          _loadReponses();
        }
      });
    }
  }

  Future<void> _loadReponses() async {
    if (_selected == null) return;
    setState(() => _loading = true);
    final reps = await DbService.getReponses(_selected!.id);
    if (mounted) setState(() { _reponses = reps; _loading = false; });
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    final result = await SyncService.syncPending();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
    setState(() => _syncing = false);
    await _loadReponses();
  }

  Future<void> _deleteReponse(Reponse r) async {
    if (r.id == null) return;
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteQuestion),
        content: Text(l10n.deleteResponseConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DbService.deleteReponse(r.id!);
      await _loadReponses();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.responsesTitle),
        actions: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.cloud_upload),
              onPressed: _sync,
              tooltip: l10n.synchronize,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQuests,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_quests.isNotEmpty)
            Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<Questionnaire>(
                value: _selected,
                decoration: InputDecoration(
                  labelText: l10n.questionnaire,
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _quests
                    .map((q) => DropdownMenuItem(value: q, child: Text(q.nom)))
                    .toList(),
                onChanged: (q) {
                  setState(() => _selected = q);
                  _loadReponses();
                },
              ),
            ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _reponses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inbox, size: 64, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(l10n.noResponses,
                                style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadReponses,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _reponses.length,
                          itemBuilder: (ctx, i) {
                            final r = _reponses[i];
                            return Card(
                              child: ListTile(
                                leading: Icon(
                                  r.syncPending ? Icons.schedule : Icons.check_circle,
                                  color: r.syncPending ? Colors.orange : Colors.green,
                                ),
                                title: Text(
                                  r.horodateur.isNotEmpty
                                      ? _formatDate(r.horodateur)
                                      : l10n.responseNumber(i + 1),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  r.syncPending ? l10n.pendingSync : l10n.synced,
                                  style: TextStyle(
                                    color: r.syncPending ? Colors.orange : Colors.green,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _deleteReponse(r),
                                ),
                                onTap: () => _showDetails(r),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsResend(Reponse r) async {
    if (r.id == null) return;
    final l10n = AppLocalizations.of(context)!;
    final d = await DbService.db;
    await d.rawUpdate(
      'UPDATE reponses SET sync_pending = 1 WHERE id = ?',
      [r.id],
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    await _loadReponses();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.markedForResend),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showDetails(Reponse r) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDate(r.horodateur),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (!r.syncPending)
                    TextButton.icon(
                      icon: const Icon(Icons.replay, size: 16),
                      label: Text(l10n.resend),
                      style: TextButton.styleFrom(foregroundColor: Colors.orange),
                      onPressed: () => _markAsResend(r),
                    ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    r.syncPending ? Icons.schedule : Icons.check_circle,
                    size: 14,
                    color: r.syncPending ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    r.syncPending ? l10n.pending : l10n.synced,
                    style: TextStyle(
                      fontSize: 12,
                      color: r.syncPending ? Colors.orange : Colors.green,
                    ),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  controller: ctrl,
                  children: r.donnees.entries
                      .map((e) => ListTile(
                            dense: true,
                            title: Text(e.key,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                            subtitle: Text(
                              e.value?.toString() ?? '—',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

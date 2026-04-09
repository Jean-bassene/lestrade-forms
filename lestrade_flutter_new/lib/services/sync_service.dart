// ============================================================================
// services/sync_service.dart
// ============================================================================

import 'api_service.dart';
import 'db_service.dart';

class SyncResult {
  final int sent;
  final int failed;
  final String? error;

  const SyncResult({this.sent = 0, this.failed = 0, this.error});

  bool get success => error == null;
  String get message {
    if (error != null) return 'Erreur : $error';
    if (sent == 0 && failed == 0) return 'Rien à synchroniser';
    if (sent == 0 && failed > 0) return '$failed réponse(s) en échec — réessayez';
    if (failed > 0) return '$sent envoyée(s), $failed en échec';
    return '$sent réponse(s) synchronisée(s)';
  }
}

class SyncService {
  static Future<SyncResult> syncPending() async {
    final alive = await ApiService.checkHealth();
    if (!alive) return const SyncResult(error: 'Serveur inaccessible');

    final pending = await DbService.getPendingReponses();
    if (pending.isEmpty) return const SyncResult();

    // Grouper par questionnaire
    final byQuest = <int, List<dynamic>>{};
    for (final r in pending) {
      byQuest.putIfAbsent(r.questionnaireId, () => []).add(r);
    }

    int sent = 0;
    int failed = 0;

    for (final entry in byQuest.entries) {
      final questId = entry.key;
      final reps = entry.value;
      try {
        // Envoyer uuid + horodateur + donnees_json
        final payload = reps.map((r) => {
          'uuid': r.uuid,
          'horodateur': r.horodateur,
          'donnees_json': r.donneesJson,
        }).toList();
        await ApiService.postReponsesWithHorodateur(questId, payload);
        // Marquer comme synchronisées par UUID (pas par id local)
        await DbService.markSynced(reps.map<String>((r) => r.uuid as String).toList());
        sent += reps.length;
      } catch (_) {
        failed += reps.length;
      }
    }

    return SyncResult(sent: sent, failed: failed);
  }

  static Future<int> downloadQuestionnaires() async {
    final alive = await ApiService.checkHealth();
    if (!alive) throw Exception('Serveur inaccessible');

    final list = await ApiService.fetchQuestionnaires();
    int count = 0;
    for (final q in list) {
      try {
        final full = await ApiService.fetchQuestionnaireFull(q.id);
        await DbService.saveQuestionnaire(full);
        count++;
      } catch (_) {}
    }
    return count;
  }
}

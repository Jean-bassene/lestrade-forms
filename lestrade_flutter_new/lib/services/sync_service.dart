// ============================================================================
// services/sync_service.dart
// Synchronisation WiFi local (plumber) + Panier Apps Script (tout réseau)
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'db_service.dart';

class SyncResult {
  final int sent;
  final int failed;
  final String? error;
  final String mode; // 'wifi' | 'panier' | 'both' | 'none'

  const SyncResult({this.sent = 0, this.failed = 0, this.error, this.mode = 'none'});

  bool get success => error == null;
  String get message {
    if (error != null) return 'Erreur : $error';
    if (sent == 0 && failed == 0) return 'Rien à synchroniser';
    if (sent == 0 && failed > 0) return '$failed réponse(s) en échec — réessayez';
    if (failed > 0) return '$sent envoyée(s) ($mode), $failed en échec';
    return '$sent réponse(s) synchronisée(s) ($mode)';
  }
}

class SyncService {
  static const _panierKey = 'panier_url';

  // ── Panier URL (stockée au scan du QR) ──────────────────────────────────

  static Future<String?> getPanierUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_panierKey);
  }

  static Future<void> setPanierUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_panierKey, url.trim());
  }

  // ── Sync principale — essaie WiFi puis Panier ────────────────────────────

  static Future<SyncResult> syncPending() async {
    final pending = await DbService.getPendingReponses();
    if (pending.isEmpty) return const SyncResult();

    // Grouper par questionnaire
    final byQuest = <int, List<dynamic>>{};
    for (final r in pending) {
      byQuest.putIfAbsent(r.questionnaireId, () => []).add(r);
    }

    // 1. Essai WiFi local
    final wifiAlive = await ApiService.checkHealth();
    if (wifiAlive) {
      final result = await _syncViaWifi(byQuest);
      if (result.sent > 0 || result.failed == 0) return result;
    }

    // 2. Fallback panier Apps Script
    final panierUrl = await getPanierUrl();
    if (panierUrl != null && panierUrl.isNotEmpty) {
      return await _syncViaPanier(byQuest, panierUrl);
    }

    return SyncResult(
      failed: pending.length,
      error: wifiAlive ? 'Échec envoi' : 'Serveur WiFi inaccessible et panier non configuré',
    );
  }

  // ── Sync via WiFi (plumber local) ────────────────────────────────────────

  static Future<SyncResult> _syncViaWifi(Map<int, List<dynamic>> byQuest) async {
    int sent = 0, failed = 0;
    for (final entry in byQuest.entries) {
      final questId = entry.key;
      final reps    = entry.value;
      try {
        final payload = reps.map((r) => {
          'uuid':         r.uuid,
          'horodateur':   r.horodateur,
          'donnees_json': r.donneesJson,
        }).toList();
        await ApiService.postReponsesWithHorodateur(questId, payload);
        await DbService.markSynced(reps.map<String>((r) => r.uuid as String).toList());
        sent += reps.length;
      } catch (_) {
        failed += reps.length;
      }
    }
    return SyncResult(sent: sent, failed: failed, mode: 'WiFi local');
  }

  // ── Sync via Panier Apps Script ──────────────────────────────────────────

  static Future<SyncResult> _syncViaPanier(
      Map<int, List<dynamic>> byQuest, String panierUrl) async {
    int sent = 0, failed = 0;
    for (final entry in byQuest.entries) {
      final questId = entry.key;
      final reps    = entry.value;
      try {
        final payload = reps.map((r) => {
          'uuid':         r.uuid,
          'horodateur':   r.horodateur,
          'donnees_json': r.donneesJson,
        }).toList();

        final body = jsonEncode({
          'quest_id':     questId,
          'reponses_full': payload,
        });

        final resp = await http
            .post(
              Uri.parse(panierUrl),
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 20));

        if (resp.statusCode == 200) {
          final result = jsonDecode(resp.body);
          if (result['status'] == 'ok') {
            await DbService.markSynced(
                reps.map<String>((r) => r.uuid as String).toList());
            sent += reps.length;
          } else {
            failed += reps.length;
          }
        } else {
          failed += reps.length;
        }
      } catch (_) {
        failed += reps.length;
      }
    }
    return SyncResult(sent: sent, failed: failed, mode: 'panier');
  }

  // ── Télécharger questionnaires via WiFi ──────────────────────────────────

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

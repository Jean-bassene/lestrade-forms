// ============================================================================
// services/sync_service.dart
// Synchronisation WiFi local (plumber) + Panier Apps Script (tout réseau)
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'db_service.dart';
import '../models/reponse.dart';

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

  static const _coordinatorEmailKey = 'coordinator_email';

  static Future<String?> getCoordinatorEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_coordinatorEmailKey);
  }

  static Future<void> setCoordinatorEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_coordinatorEmailKey, email.trim().toLowerCase());
  }

  // ── Sync principale — essaie WiFi puis Panier ────────────────────────────

  static Future<SyncResult> syncPending() async {
    final pending = await DbService.getPendingReponses();
    if (pending.isEmpty) return const SyncResult();

    // Grouper par questionnaire (typage explicite Reponse)
    final byQuest = <int, List<Reponse>>{};
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

  static Future<SyncResult> _syncViaWifi(Map<int, List<Reponse>> byQuest) async {
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
        await DbService.markSynced(reps.map((r) => r.uuid).toList());
        sent += reps.length;
      } catch (_) {
        failed += reps.length;
      }
    }
    return SyncResult(sent: sent, failed: failed, mode: 'WiFi local');
  }

  // ── Sync via Panier Apps Script ──────────────────────────────────────────

  static Future<SyncResult> _syncViaPanier(
      Map<int, List<Reponse>> byQuest, String panierUrl) async {
    int sent = 0, failed = 0;
    String? lastError;
    final coordinatorEmail = await getCoordinatorEmail() ?? '';
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
          'quest_id':      questId,
          'user_email':    coordinatorEmail,
          'reponses_full': payload,
        });

        // Apps Script : POST traité côté Google, réponse renvoyée via redirect GET
        final client = http.Client();
        String bodyStr;
        try {
          // Étape 1 : POST sans suivre le redirect
          final req = http.Request('POST', Uri.parse(panierUrl))
            ..headers['Content-Type'] = 'application/json'
            ..body = body
            ..followRedirects = false;
          final streamed = await client.send(req)
              .timeout(const Duration(seconds: 15));

          if (streamed.statusCode == 302 || streamed.statusCode == 301) {
            // Étape 2 : GET sur l'URL de redirect pour récupérer la réponse JSON
            final redirectUrl = streamed.headers['location'] ?? panierUrl;
            final resp2 = await client
                .get(Uri.parse(redirectUrl))
                .timeout(const Duration(seconds: 20));
            bodyStr = resp2.body;
          } else {
            // Réponse directe (rare)
            bodyStr = await streamed.stream.bytesToString();
          }
        } finally {
          client.close();
        }

        if (bodyStr.trimLeft().startsWith('{')) {
          final result = jsonDecode(bodyStr) as Map<String, dynamic>;
          if (result['status'] == 'ok') {
            final uuids = reps.map((r) => r.uuid).toList();
            await DbService.markSynced(uuids);
            sent += reps.length;
          } else {
            lastError = result['message']?.toString() ?? 'Erreur Apps Script';
            failed += reps.length;
          }
        } else {
          lastError = 'Réponse invalide du panier';
          failed += reps.length;
        }
      } catch (e) {
        lastError = e.toString();
        failed += reps.length;
      }
    }
    if (failed > 0 && sent == 0) {
      return SyncResult(failed: failed, error: lastError ?? 'Échec panier', mode: 'panier');
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

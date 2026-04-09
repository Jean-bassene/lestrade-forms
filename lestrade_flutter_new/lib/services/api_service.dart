// ============================================================================
// services/api_service.dart
// Appels HTTP vers l'API plumber (réseau local)
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/questionnaire.dart';
import '../models/reponse.dart';

class ApiService {
  static const _prefKey = 'api_base_url';
  static const _defaultPort = 8765;

  // URL de base récupérée depuis les préférences
  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey) ?? '';
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, url.trimRight().replaceAll(RegExp(r'/$'), ''));
  }

  /// Construit l'URL à partir d'une IP (ajoute le port si absent)
  static String buildUrl(String ip) {
    ip = ip.trim();
    if (!ip.startsWith('http')) ip = 'http://$ip';
    if (!ip.contains(':$_defaultPort') && !RegExp(r':\d+$').hasMatch(ip)) {
      ip = '$ip:$_defaultPort';
    }
    return ip;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEALTH CHECK
  // ─────────────────────────────────────────────────────────────────────────

  static Future<bool> checkHealth({String? baseUrl}) async {
    final url = baseUrl ?? await getBaseUrl();
    if (url.isEmpty) return false;
    try {
      final resp = await http
          .get(Uri.parse('$url/health'))
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // QUESTIONNAIRES
  // ─────────────────────────────────────────────────────────────────────────

  static Future<List<Questionnaire>> fetchQuestionnaires() async {
    final url = await getBaseUrl();
    if (url.isEmpty) throw Exception('Serveur non configuré');

    final resp = await http
        .get(Uri.parse('$url/questionnaires'))
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    final body = jsonDecode(resp.body);

    if (body is Map && body.containsKey('error')) {
      throw Exception(body['error']);
    }

    final list = body is List ? body : [];
    return list
        .map((j) => Questionnaire.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  static Future<QuestionnaireFull> fetchQuestionnaireFull(int id) async {
    final url = await getBaseUrl();
    if (url.isEmpty) throw Exception('Serveur non configuré');

    final resp = await http
        .get(Uri.parse('$url/questionnaires/$id'))
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    final body = jsonDecode(resp.body);

    if (body is Map && body.containsKey('error')) {
      throw Exception(body['error']);
    }

    return QuestionnaireFull.fromJson(Map<String, dynamic>.from(body));
  }

  /// Importe un questionnaire directement depuis le JSON embarqué dans le QR code
  static Future<QuestionnaireFull> parseQuestionnaireFromJson(String jsonStr) async {
    final body = Map<String, dynamic>.from(jsonDecode(jsonStr) as Map);
    // Format QR : { lestrade_version, uid, quest:{id,nom,description}, sections, questions }
    final quest = Map<String, dynamic>.from(body['quest'] as Map);
    final payload = <String, dynamic>{
      'questionnaire': quest,
      'sections': body['sections'] ?? [],
      'questions': body['questions'] ?? [],
    };
    return QuestionnaireFull.fromJson(payload);
  }

  /// Télécharge un questionnaire par son UID Drive (scanné en QR)
  static Future<QuestionnaireFull> fetchQuestionnaireByUid(String uid) async {
    final url = await getBaseUrl();
    if (url.isEmpty) throw Exception('Serveur non configuré');

    final resp = await http
        .get(Uri.parse('$url/questionnaires/uid/$uid'))
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    final body = jsonDecode(resp.body);

    if (body is Map && body.containsKey('error')) {
      throw Exception(body['error'].toString());
    }

    // body contient { uid, quest: { questionnaire, sections, questions } }
    final questPart = body['quest'] ?? body;
    return QuestionnaireFull.fromJson(Map<String, dynamic>.from(questPart));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RÉPONSES
  // ─────────────────────────────────────────────────────────────────────────

  static Future<List<Reponse>> fetchReponses(int questId) async {
    final url = await getBaseUrl();
    if (url.isEmpty) throw Exception('Serveur non configuré');

    final resp = await http
        .get(Uri.parse('$url/reponses/$questId'))
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    final body = jsonDecode(resp.body);

    if (body is Map && body.containsKey('error')) {
      throw Exception(body['error']);
    }

    final list = body is List ? body : [];
    return list
        .map((j) => Reponse.fromApiJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  /// Envoie une liste de réponses au serveur (chaque réponse = JSON string)
  static Future<int> postReponses(
      int questId, List<Map<String, dynamic>> donneesList) async {
    final url = await getBaseUrl();
    if (url.isEmpty) throw Exception('Serveur non configuré');

    // On sérialise chaque réponse en string JSON pour éviter les problèmes
    // de conversion data.frame côté R (notamment pour les checkboxes = listes)
    final body = jsonEncode({
      'quest_id': questId,
      'reponses_json': donneesList.map((d) => jsonEncode(d)).toList(),
    });

    final resp = await http
        .post(
          Uri.parse('$url/reponses'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    final result = jsonDecode(resp.body);

    if (result is Map && result.containsKey('error')) {
      throw Exception(result['error']);
    }

    final saved = result['saved'];
    if (saved is int) return saved;
    if (saved is List && saved.isNotEmpty) return saved[0] as int;
    return 0;
  }

  /// Envoie des réponses avec horodateur pour déduplication côté serveur
  /// payload = [ { 'horodateur': '...', 'donnees_json': '{...}' }, ... ]
  static Future<int> postReponsesWithHorodateur(
      int questId, List<Map<String, dynamic>> payload) async {
    final url = await getBaseUrl();
    if (url.isEmpty) throw Exception('Serveur non configuré');

    final body = jsonEncode({
      'quest_id': questId,
      'reponses_full': payload,
    });

    final resp = await http
        .post(
          Uri.parse('$url/reponses'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    final result = jsonDecode(resp.body);

    if (result is Map && result.containsKey('error')) {
      throw Exception(result['error']);
    }

    // plumber renvoie les scalaires comme des vecteurs R : saved:[2] au lieu de saved:2
    final saved = result['saved'];
    if (saved is int) return saved;
    if (saved is List && saved.isNotEmpty) return saved[0] as int;
    return 0;
  }
}

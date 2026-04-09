// ============================================================================
// services/db_service.dart
// ============================================================================

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

import '../models/questionnaire.dart';
import '../models/reponse.dart';

class DbService {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'lestrade_local.db');
    return openDatabase(path, version: 2, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE questionnaires (
        id INTEGER PRIMARY KEY,
        nom TEXT NOT NULL,
        description TEXT,
        date_creation TEXT,
        nb_sections INTEGER DEFAULT 0,
        nb_questions INTEGER DEFAULT 0,
        json_full TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE reponses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        questionnaire_id INTEGER NOT NULL,
        horodateur TEXT NOT NULL,
        donnees_json TEXT NOT NULL,
        sync_pending INTEGER DEFAULT 1
      )
    ''');
  }

  static Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      try {
        await db.execute("ALTER TABLE reponses ADD COLUMN uuid TEXT");
      } catch (_) {}
      // Les anciennes réponses sans UUID sont considérées déjà synchronisées
      // (elles ont été envoyées avec l'ancienne version de l'app)
      await db.execute(
          "UPDATE reponses SET uuid = 'legacy-' || id, sync_pending = 0 WHERE uuid IS NULL");
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // QUESTIONNAIRES
  // ─────────────────────────────────────────────────────────────────────────

  static Future<List<Questionnaire>> getQuestionnaires() async {
    final d = await db;
    final rows = await d.query('questionnaires', orderBy: 'nom');
    return rows.map((r) => Questionnaire.fromJson(Map<String, dynamic>.from(r))).toList();
  }

  static Future<QuestionnaireFull?> getQuestionnaireFull(int id) async {
    final d = await db;
    final rows = await d.query('questionnaires', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final decoded = jsonDecode(rows.first['json_full'] as String);
    return QuestionnaireFull.fromJson(Map<String, dynamic>.from(decoded));
  }

  static Future<void> saveQuestionnaire(QuestionnaireFull full) async {
    final d = await db;
    final q = full.questionnaire;
    await d.insert('questionnaires', {
      'id': q.id,
      'nom': q.nom,
      'description': q.description,
      'date_creation': q.dateCreation,
      'nb_sections': full.sections.length,
      'nb_questions': full.questions.length,
      'json_full': jsonEncode(full.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> deleteQuestionnaire(int id) async {
    final d = await db;
    await d.delete('questionnaires', where: 'id = ?', whereArgs: [id]);
    await d.delete('reponses', where: 'questionnaire_id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RÉPONSES
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> saveReponse(Reponse reponse) async {
    final d = await db;
    await d.insert('reponses', {
      'uuid': reponse.uuid,
      'questionnaire_id': reponse.questionnaireId,
      'horodateur': reponse.horodateur,
      'donnees_json': reponse.donneesJson,
      'sync_pending': 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore); // ignore si uuid déjà présent
  }

  static Future<List<Reponse>> getReponses(int questId) async {
    final d = await db;
    final rows = await d.query('reponses',
        where: 'questionnaire_id = ?', whereArgs: [questId], orderBy: 'horodateur DESC');
    return rows.map((r) => Reponse.fromDbRow(Map<String, dynamic>.from(r))).toList();
  }

  static Future<List<Reponse>> getPendingReponses() async {
    final d = await db;
    final rows = await d.query('reponses', where: 'sync_pending = 1');
    return rows.map((r) => Reponse.fromDbRow(Map<String, dynamic>.from(r))).toList();
  }

  static Future<int> countPending() async {
    final d = await db;
    final result = await d.rawQuery('SELECT COUNT(*) as n FROM reponses WHERE sync_pending = 1');
    return (result.first['n'] as int?) ?? 0;
  }

  static Future<void> markSynced(List<String> uuids) async {
    if (uuids.isEmpty) return;
    final d = await db;
    final placeholders = uuids.map((_) => '?').join(',');
    await d.rawUpdate(
      'UPDATE reponses SET sync_pending = 0 WHERE uuid IN ($placeholders)',
      uuids,
    );
  }

  static Future<void> deleteReponse(int id) async {
    final d = await db;
    await d.delete('reponses', where: 'id = ?', whereArgs: [id]);
  }
}

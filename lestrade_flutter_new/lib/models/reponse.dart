// ============================================================================
// models/reponse.dart
// ============================================================================

import 'dart:convert';

class Reponse {
  final int? id;
  final String uuid;          // identifiant unique côté téléphone
  final int questionnaireId;
  final String horodateur;
  final Map<String, dynamic> donnees;
  final bool syncPending;

  const Reponse({
    this.id,
    required this.uuid,
    required this.questionnaireId,
    required this.horodateur,
    required this.donnees,
    this.syncPending = true,
  });

  String get donneesJson => jsonEncode(donnees);

  factory Reponse.fromDbRow(Map<String, dynamic> row) {
    Map<String, dynamic> data = {};
    try { data = Map<String, dynamic>.from(jsonDecode(row['donnees_json'] ?? '{}')); } catch (_) {}
    return Reponse(
      id: row['id'] as int?,
      uuid: row['uuid'] as String? ?? '',
      questionnaireId: row['questionnaire_id'] as int,
      horodateur: row['horodateur'] as String? ?? DateTime.now().toIso8601String(),
      donnees: data,
      syncPending: (row['sync_pending'] ?? 1) == 1,
    );
  }

  factory Reponse.fromApiJson(Map<String, dynamic> json) {
    Map<String, dynamic> data = {};
    try { data = Map<String, dynamic>.from(jsonDecode(json['donnees_json'] ?? '{}')); } catch (_) {}
    return Reponse(
      uuid: json['uuid'] as String? ?? '',
      questionnaireId: json['questionnaire_id'] is int
          ? json['questionnaire_id']
          : int.parse('${json['questionnaire_id']}'),
      horodateur: json['horodateur'] as String? ?? '',
      donnees: data,
      syncPending: false,
    );
  }
}

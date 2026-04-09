// ============================================================================
// models/questionnaire.dart
// ============================================================================

class Questionnaire {
  final int id;
  final String nom;
  final String? description;
  final String? dateCreation;
  final int nbSections;
  final int nbQuestions;

  const Questionnaire({
    required this.id,
    required this.nom,
    this.description,
    this.dateCreation,
    this.nbSections = 0,
    this.nbQuestions = 0,
  });

  factory Questionnaire.fromJson(Map<String, dynamic> json) {
    return Questionnaire(
      id: _parseInt(json['id']),
      nom: json['nom']?.toString() ?? '',
      description: json['description']?.toString(),
      dateCreation: json['date_creation']?.toString(),
      nbSections: _parseInt(json['nb_sections'], fallback: 0),
      nbQuestions: _parseInt(json['nb_questions'], fallback: 0),
    );
  }

  static int _parseInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is List && v.isNotEmpty) return _parseInt(v[0], fallback: fallback);
    final s = v.toString().trim();
    return int.tryParse(s) ?? fallback;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nom': nom,
        'description': description,
        'date_creation': dateCreation,
        'nb_sections': nbSections,
        'nb_questions': nbQuestions,
      };
}

class Section {
  final int id;
  final int questionnaireId;
  final String nom;
  final int ordre;

  const Section({
    required this.id,
    required this.questionnaireId,
    required this.nom,
    required this.ordre,
  });

  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(
      id: Questionnaire._parseInt(json['id']),
      questionnaireId: Questionnaire._parseInt(json['questionnaire_id']),
      nom: json['nom']?.toString() ?? '',
      ordre: Questionnaire._parseInt(json['ordre'], fallback: 1),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'questionnaire_id': questionnaireId,
        'nom': nom,
        'ordre': ordre,
      };
}

class Question {
  final int id;
  final int sectionId;
  final String type;
  final String texte;
  final String? options; // JSON string ou null
  final String? roleAnalytique;
  final bool obligatoire;
  final int ordre;
  final String? sectionNom;

  const Question({
    required this.id,
    required this.sectionId,
    required this.type,
    required this.texte,
    this.options,
    this.roleAnalytique,
    this.obligatoire = false,
    this.ordre = 1,
    this.sectionNom,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final oblig = json['obligatoire'];
    return Question(
      id: Questionnaire._parseInt(json['id']),
      sectionId: Questionnaire._parseInt(json['section_id']),
      type: json['type']?.toString() ?? 'text',
      texte: json['texte']?.toString() ?? '',
      options: json['options']?.toString(),
      roleAnalytique: json['role_analytique']?.toString(),
      obligatoire: oblig is bool ? oblig : Questionnaire._parseInt(oblig) == 1,
      ordre: Questionnaire._parseInt(json['ordre'], fallback: 1),
      sectionNom: json['section_nom']?.toString(),
    );
  }

  /// Parse la colonne options (JSON string → List<String>)
  List<String> get parsedOptions {
    if (options == null || options!.isEmpty || options == '{}') return [];
    try {
      // L'API renvoie options comme string JSON encodé en string
      // ex: "[\"option1\",\"option2\"]" ou "{}"
      final raw = options!.trim();
      if (raw.startsWith('[')) {
        // Tableau JSON → liste
        final list = (raw
            .replaceAll('[', '')
            .replaceAll(']', '')
            .split(','))
            .map((s) => s.trim().replaceAll('"', ''))
            .where((s) => s.isNotEmpty)
            .toList();
        return list;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'section_id': sectionId,
        'type': type,
        'texte': texte,
        'options': options,
        'role_analytique': roleAnalytique,
        'obligatoire': obligatoire ? 1 : 0,
        'ordre': ordre,
        'section_nom': sectionNom,
      };
}

class QuestionnaireFull {
  final Questionnaire questionnaire;
  final List<Section> sections;
  final List<Question> questions;

  const QuestionnaireFull({
    required this.questionnaire,
    required this.sections,
    required this.questions,
  });

  factory QuestionnaireFull.fromJson(Map<String, dynamic> json) {
    // L'API renvoie questionnaire comme un data.frame (liste d'une ligne)
    final qRaw = json['questionnaire'];
    Questionnaire q;
    if (qRaw is List && qRaw.isNotEmpty) {
      q = Questionnaire.fromJson(Map<String, dynamic>.from(qRaw[0]));
    } else if (qRaw is Map) {
      q = Questionnaire.fromJson(Map<String, dynamic>.from(qRaw));
    } else {
      throw Exception('Format questionnaire invalide');
    }

    List<Section> secs = [];
    final secsRaw = json['sections'];
    if (secsRaw is List) {
      secs = secsRaw
          .map((s) => Section.fromJson(Map<String, dynamic>.from(s)))
          .toList();
    }

    List<Question> qs = [];
    final qsRaw = json['questions'];
    if (qsRaw is List) {
      qs = qsRaw
          .map((q) => Question.fromJson(Map<String, dynamic>.from(q)))
          .toList();
    }

    return QuestionnaireFull(questionnaire: q, sections: secs, questions: qs);
  }

  Map<String, dynamic> toJson() => {
        'questionnaire': questionnaire.toJson(),
        'sections': sections.map((s) => s.toJson()).toList(),
        'questions': questions.map((q) => q.toJson()).toList(),
      };
}

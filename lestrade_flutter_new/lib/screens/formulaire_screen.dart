// ============================================================================
// screens/formulaire_screen.dart — Saisie d'une réponse (offline)
// ============================================================================

import 'package:flutter/material.dart';
import 'dart:math';
import '../l10n/app_localizations.dart';
import '../models/questionnaire.dart';
import '../models/reponse.dart';
import '../services/db_service.dart';
import '../services/gps_service.dart';

String _generateUuid() {
  final rng = Random.secure();
  final bytes = List.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
      '${hex(bytes[4])}${hex(bytes[5])}-${hex(bytes[6])}${hex(bytes[7])}-'
      '${hex(bytes[8])}${hex(bytes[9])}-'
      '${bytes.sublist(10).map(hex).join()}';
}

class FormulaireScreen extends StatefulWidget {
  final int questId;

  const FormulaireScreen({super.key, required this.questId});

  @override
  State<FormulaireScreen> createState() => _FormulaireScreenState();
}

class _FormulaireScreenState extends State<FormulaireScreen> {
  QuestionnaireFull? _full;
  bool _loading = true;
  bool _saving = false;
  GpsResult? _gpsResult;
  bool _gpsLoading = true;

  final Map<String, dynamic> _answers = {};

  @override
  void initState() {
    super.initState();
    _load();
    _acquireGps();
  }

  Future<void> _acquireGps() async {
    final result = await GpsService.getPosition();
    if (mounted) setState(() { _gpsResult = result; _gpsLoading = false; });
  }

  Future<void> _load() async {
    final full = await DbService.getQuestionnaireFull(widget.questId);
    if (mounted) setState(() { _full = full; _loading = false; });
  }

  Future<void> _submit() async {
    if (_full == null) return;
    final l10n = AppLocalizations.of(context)!;

    final missing = <String>[];
    for (final q in _full!.questions) {
      if (q.obligatoire) {
        final val = _answers['${q.id}'];
        if (val == null || val.toString().trim().isEmpty ||
            (val is List && val.isEmpty)) {
          missing.add(q.texte);
        }
      }
    }

    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.requiredFields(missing.take(3).join(', '))),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final donnees = Map<String, dynamic>.from(_answers);
      if (_gpsResult != null && _gpsResult!.hasPosition) {
        donnees['_latitude']     = _gpsResult!.latitude;
        donnees['_longitude']    = _gpsResult!.longitude;
        donnees['_gps_accuracy'] = _gpsResult!.accuracy;
      }

      final reponse = Reponse(
        uuid: _generateUuid(),
        questionnaireId: widget.questId,
        horodateur: DateTime.now().toIso8601String(),
        donnees: donnees,
        syncPending: true,
      );
      await DbService.saveReponse(reponse);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.responseSavedOffline),
            backgroundColor: Colors.green,
          ),
        );
        setState(() { _answers.clear(); _saving = false; });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_full == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.formTitle)),
        body: Center(child: Text(l10n.surveyNotFound)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_full!.questionnaire.nom),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _gpsLoading
                ? Tooltip(
                    message: l10n.acquiringGps,
                    child: const Icon(Icons.gps_not_fixed, color: Colors.orange),
                  )
                : _gpsResult != null && _gpsResult!.hasPosition
                    ? Tooltip(
                        message: l10n.gpsAcquired(
                          _gpsResult!.accuracy?.toStringAsFixed(0) ?? '?',
                        ),
                        child: const Icon(Icons.gps_fixed, color: Colors.green),
                      )
                    : Tooltip(
                        message: l10n.gpsUnavailable,
                        child: const Icon(Icons.gps_off, color: Colors.grey),
                      ),
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saving ? null : _submit,
            tooltip: l10n.save,
          )
        ],
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(l10n),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 8,
        ),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.save),
          label: Text(l10n.saveResponse),
          onPressed: _saving ? null : _submit,
        ),
      ),
    );
  }

  Widget _buildForm(AppLocalizations l10n) {
    final sections = _full!.sections;
    final questions = _full!.questions;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sections.length,
      itemBuilder: (ctx, si) {
        final section = sections[si];
        final sectionQuestions = questions
            .where((q) => q.sectionId == section.id)
            .toList()
          ..sort((a, b) => a.ordre.compareTo(b.ordre));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (si > 0) const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF003366),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                section.nom,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...sectionQuestions.map((q) => _buildQuestion(q, l10n)),
          ],
        );
      },
    );
  }

  Widget _buildQuestion(Question q, AppLocalizations l10n) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    q.texte,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (q.obligatoire)
                  const Text(' *', style: TextStyle(color: Colors.red)),
              ],
            ),
            const SizedBox(height: 10),
            _buildInput(q, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(Question q, AppLocalizations l10n) {
    final key = '${q.id}';

    switch (q.type) {
      case 'text':
      case 'email':
      case 'phone':
        return TextFormField(
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: q.type == 'email'
                ? l10n.emailHint
                : q.type == 'phone'
                    ? l10n.phoneHint
                    : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          keyboardType: q.type == 'email'
              ? TextInputType.emailAddress
              : q.type == 'phone'
                  ? TextInputType.phone
                  : TextInputType.text,
          onChanged: (v) => _answers[key] = v,
        );

      case 'textarea':
        return TextFormField(
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onChanged: (v) => _answers[key] = v,
        );

      case 'date':
        final currentVal = _answers[key] as String?;
        return InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null && mounted) {
              setState(() {
                _answers[key] = picked.toIso8601String().substring(0, 10);
              });
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            child: Text(
              currentVal ?? l10n.selectDate,
              style: TextStyle(
                color: currentVal != null ? Colors.black87 : Colors.grey,
              ),
            ),
          ),
        );

      case 'radio':
      case 'dropdown':
        final opts = q.parsedOptions;
        if (opts.isEmpty) {
          return Text(l10n.noOptionsDefined,
              style: const TextStyle(color: Colors.grey));
        }
        if (q.type == 'dropdown') {
          return DropdownButtonFormField<String>(
            decoration: const InputDecoration(border: OutlineInputBorder()),
            value: _answers[key] as String?,
            items: opts
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
            onChanged: (v) => setState(() => _answers[key] = v),
          );
        }
        final current = _answers[key] as String?;
        return Column(
          children: opts
              .map((o) => RadioListTile<String>(
                    title: Text(o),
                    value: o,
                    groupValue: current,
                    dense: true,
                    activeColor: const Color(0xFF003366),
                    onChanged: (v) => setState(() => _answers[key] = v),
                  ))
              .toList(),
        );

      case 'checkbox':
        final opts = q.parsedOptions;
        if (opts.isEmpty) {
          return Text(l10n.noOptionsDefined,
              style: const TextStyle(color: Colors.grey));
        }
        final selected = ((_answers[key] as List<String>?) ?? <String>[]);
        return Column(
          children: opts
              .map((o) => CheckboxListTile(
                    title: Text(o),
                    value: selected.contains(o),
                    dense: true,
                    activeColor: const Color(0xFF003366),
                    onChanged: (checked) {
                      setState(() {
                        final list = List<String>.from(_answers[key] ?? []);
                        if (checked == true) {
                          list.add(o);
                        } else {
                          list.remove(o);
                        }
                        _answers[key] = list;
                      });
                    },
                  ))
              .toList(),
        );

      case 'likert':
        final current = _answers[key] as int?;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (i) {
            final val = i + 1;
            final sel = current == val;
            return GestureDetector(
              onTap: () => setState(() => _answers[key] = val),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: sel ? const Color(0xFFF59E0B) : Colors.grey.shade200,
                child: Text(
                  '$val',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: sel ? Colors.white : Colors.black54,
                  ),
                ),
              ),
            );
          }),
        );

      default:
        return TextFormField(
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onChanged: (v) => _answers[key] = v,
        );
    }
  }
}

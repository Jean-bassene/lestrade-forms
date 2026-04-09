// ============================================================================
// Lestrade Forms — Panier Google Apps Script v2
// Déployer comme "Application Web" > Accès : Tout le monde (anonyme)
//
// POST /exec                              → envoyer réponses OU sauvegarder questionnaire
// GET  /exec?action=info                  → statut général
// GET  /exec?action=list[&quest_id=X]     → lister réponses du panier
// GET  /exec?action=clear[&quest_id=X]    → vider le panier
// GET  /exec?action=get_quest&uid=LEST-XX → récupérer un questionnaire
// ============================================================================

var SHEET_REPONSES      = "Panier";
var SHEET_QUESTIONNAIRES = "Questionnaires";
var VERSION             = "2.0";

// ── Feuilles ─────────────────────────────────────────────────────────────────

function getSheetReponses() {
  var ss    = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(SHEET_REPONSES);
  if (!sheet) {
    sheet = ss.insertSheet(SHEET_REPONSES);
    sheet.appendRow(["quest_id", "uuid", "horodateur", "donnees_json", "recu_le"]);
    sheet.setFrozenRows(1);
  }
  return sheet;
}

function getSheetQuestionnaires() {
  var ss    = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(SHEET_QUESTIONNAIRES);
  if (!sheet) {
    sheet = ss.insertSheet(SHEET_QUESTIONNAIRES);
    sheet.appendRow(["uid", "nom", "quest_json", "publie_le"]);
    sheet.setFrozenRows(1);
  }
  return sheet;
}

function jsonResponse(data) {
  return ContentService
    .createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}

// ── POST ─────────────────────────────────────────────────────────────────────

function doPost(e) {
  try {
    var body = JSON.parse(e.postData.contents);

    // Sauvegarder un questionnaire complet
    if (body.action === "save_quest") {
      return saveQuestionnaire(body);
    }

    // Envoyer des réponses (comportement par défaut)
    return saveReponses(body);

  } catch(err) {
    return jsonResponse({ status: "error", message: err.message });
  }
}

function saveReponses(body) {
  var sheet    = getSheetReponses();
  var quest_id = body.quest_id     || "";
  var reponses = body.reponses_full || [];
  var recu_le  = new Date().toISOString();

  var data          = sheet.getDataRange().getValues();
  var existingUUIDs = {};
  for (var i = 1; i < data.length; i++) existingUUIDs[data[i][1]] = true;

  var saved = 0;
  for (var r = 0; r < reponses.length; r++) {
    var rep  = reponses[r];
    var uuid = rep.uuid || "";
    if (uuid && existingUUIDs[uuid]) continue;
    sheet.appendRow([quest_id, uuid, rep.horodateur || recu_le, rep.donnees_json || "{}", recu_le]);
    existingUUIDs[uuid] = true;
    saved++;
  }
  return jsonResponse({ status: "ok", saved: saved });
}

function saveQuestionnaire(body) {
  var sheet      = getSheetQuestionnaires();
  var uid        = body.uid        || "";
  var nom        = body.nom        || "";
  var quest_json = body.quest_json || "{}";
  var publie_le  = new Date().toISOString();

  if (!uid) return jsonResponse({ status: "error", message: "uid manquant" });

  // Mettre à jour si l'UID existe déjà, sinon ajouter
  var data = sheet.getDataRange().getValues();
  for (var i = 1; i < data.length; i++) {
    if (data[i][0].toString() === uid) {
      sheet.getRange(i + 1, 3).setValue(quest_json);
      sheet.getRange(i + 1, 4).setValue(publie_le);
      return jsonResponse({ status: "ok", action: "updated", uid: uid });
    }
  }
  sheet.appendRow([uid, nom, quest_json, publie_le]);
  return jsonResponse({ status: "ok", action: "created", uid: uid });
}

// ── GET ──────────────────────────────────────────────────────────────────────

function doGet(e) {
  var action   = (e.parameter.action   || "info").toLowerCase();
  var quest_id = (e.parameter.quest_id || "").toString();
  var uid      = (e.parameter.uid      || "").toString();

  try {

    // ── INFO ──
    if (action === "info") {
      var nr = Math.max(0, getSheetReponses().getLastRow() - 1);
      var nq = Math.max(0, getSheetQuestionnaires().getLastRow() - 1);
      return jsonResponse({ status: "ok", version: VERSION, nb_reponses: nr, nb_questionnaires: nq });
    }

    // ── GET_QUEST ──
    if (action === "get_quest") {
      if (!uid) return jsonResponse({ status: "error", message: "uid manquant" });
      var sheet = getSheetQuestionnaires();
      var data  = sheet.getDataRange().getValues();
      for (var i = 1; i < data.length; i++) {
        if (data[i][0].toString() === uid) {
          var parsed = JSON.parse(data[i][2]);
          return jsonResponse({ status: "ok", uid: uid, nom: data[i][1], quest: parsed });
        }
      }
      return jsonResponse({ status: "error", message: "questionnaire " + uid + " introuvable" });
    }

    // ── LIST ──
    if (action === "list") {
      var sheet = getSheetReponses();
      var data  = sheet.getDataRange().getValues();
      var rows  = [];
      for (var i = 1; i < data.length; i++) {
        if (quest_id && data[i][0].toString() !== quest_id) continue;
        rows.push({
          quest_id: data[i][0], uuid: data[i][1],
          horodateur: data[i][2], donnees_json: data[i][3], recu_le: data[i][4]
        });
      }
      return jsonResponse({ status: "ok", reponses: rows });
    }

    // ── CLEAR ──
    if (action === "clear") {
      var sheet = getSheetReponses();
      if (sheet.getLastRow() <= 1) return jsonResponse({ status: "ok", deleted: 0 });
      if (!quest_id) {
        sheet.deleteRows(2, sheet.getLastRow() - 1);
        return jsonResponse({ status: "ok", deleted: "all" });
      }
      var deleted = 0;
      for (var i = sheet.getLastRow(); i >= 2; i--) {
        if (sheet.getRange(i, 1).getValue().toString() === quest_id) {
          sheet.deleteRow(i);
          deleted++;
        }
      }
      return jsonResponse({ status: "ok", deleted: deleted });
    }

    return jsonResponse({ status: "error", message: "action inconnue: " + action });

  } catch(err) {
    return jsonResponse({ status: "error", message: err.message });
  }
}

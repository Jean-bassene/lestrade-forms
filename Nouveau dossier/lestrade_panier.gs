// ============================================================================
// Lestrade Forms — Panier Google Apps Script
// Déployer comme "Application Web" > Accès : Tout le monde (anonyme)
//
// Endpoints :
//   POST /exec          → reçoit une réponse depuis Flutter
//   GET  /exec?action=list&quest_id=X  → liste les réponses du panier
//   GET  /exec?action=clear&quest_id=X → vide le panier (après import)
//   GET  /exec?action=info             → infos du panier (version, nb lignes)
// ============================================================================

var SHEET_NAME = "Panier";
var VERSION    = "1.0";

// ── Utilitaires ──────────────────────────────────────────────────────────────

function getSheet() {
  var ss    = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(SHEET_NAME);
  if (!sheet) {
    sheet = ss.insertSheet(SHEET_NAME);
    sheet.appendRow(["quest_id", "uuid", "horodateur", "donnees_json", "recu_le"]);
    sheet.setFrozenRows(1);
  }
  return sheet;
}

function jsonResponse(data, status) {
  return ContentService
    .createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}

// ── POST — reçoit une réponse depuis Flutter ─────────────────────────────────

function doPost(e) {
  try {
    var body = JSON.parse(e.postData.contents);
    var sheet = getSheet();

    var quest_id     = body.quest_id     || "";
    var reponses     = body.reponses_full || [];
    var recu_le      = new Date().toISOString();

    // Récupérer les UUID déjà présents pour dédupliquer
    var data         = sheet.getDataRange().getValues();
    var existingUUIDs = {};
    for (var i = 1; i < data.length; i++) {
      existingUUIDs[data[i][1]] = true;
    }

    var saved = 0;
    for (var r = 0; r < reponses.length; r++) {
      var rep  = reponses[r];
      var uuid = rep.uuid || "";
      if (uuid && existingUUIDs[uuid]) continue; // déduplication
      sheet.appendRow([
        quest_id,
        uuid,
        rep.horodateur   || recu_le,
        rep.donnees_json || "{}",
        recu_le
      ]);
      existingUUIDs[uuid] = true;
      saved++;
    }

    return jsonResponse({ status: "ok", saved: saved });

  } catch(err) {
    return jsonResponse({ status: "error", message: err.message });
  }
}

// ── GET — list / clear / info ─────────────────────────────────────────────────

function doGet(e) {
  var action   = (e.parameter.action   || "info").toLowerCase();
  var quest_id = (e.parameter.quest_id || "").toString();

  try {
    var sheet = getSheet();

    // ── INFO ──
    if (action === "info") {
      var nRows = Math.max(0, sheet.getLastRow() - 1);
      return jsonResponse({ status: "ok", version: VERSION, nb_reponses: nRows });
    }

    var data = sheet.getDataRange().getValues();
    var headers = data[0]; // ["quest_id","uuid","horodateur","donnees_json","recu_le"]

    // ── LIST ──
    if (action === "list") {
      var rows = [];
      for (var i = 1; i < data.length; i++) {
        if (quest_id && data[i][0].toString() !== quest_id) continue;
        rows.push({
          quest_id:     data[i][0],
          uuid:         data[i][1],
          horodateur:   data[i][2],
          donnees_json: data[i][3],
          recu_le:      data[i][4]
        });
      }
      return jsonResponse({ status: "ok", reponses: rows });
    }

    // ── CLEAR ──
    if (action === "clear") {
      if (sheet.getLastRow() <= 1) {
        return jsonResponse({ status: "ok", deleted: 0 });
      }
      if (!quest_id) {
        // Vider tout sauf l'en-tête
        sheet.deleteRows(2, sheet.getLastRow() - 1);
        return jsonResponse({ status: "ok", deleted: "all" });
      }
      // Supprimer uniquement les lignes du quest_id donné (de bas en haut)
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

// ============================================================================
// Lestrade Forms — Panier Google Apps Script v3
// Déployer comme "Application Web" > Accès : Tout le monde (anonyme)
//
// POST /exec                                   → envoyer réponses OU sauvegarder questionnaire
// POST /exec  { action:"save_quest" }          → sauvegarder questionnaire
// POST /exec  { action:"register_email" }      → enregistrer email trial
// POST /exec  { action:"activate_key" }        → activer une clé licence
// GET  /exec?action=info                       → statut général
// GET  /exec?action=list[&quest_id=X]          → lister réponses du panier
// GET  /exec?action=clear[&quest_id=X]         → vider le panier
// GET  /exec?action=get_quest&uid=LEST-XX      → récupérer un questionnaire
// GET  /exec?action=check_licence&email=X      → vérifier statut licence
// ============================================================================

var SHEET_REPONSES       = "Panier";
var SHEET_QUESTIONNAIRES = "Questionnaires";
var SHEET_LICENCES       = "Licences";
var VERSION              = "3.0";
var TRIAL_DAYS           = 30;

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

function getSheetLicences() {
  var ss    = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(SHEET_LICENCES);
  if (!sheet) {
    sheet = ss.insertSheet(SHEET_LICENCES);
    sheet.appendRow(["email", "date_inscription", "statut", "cle", "date_activation", "jours_trial"]);
    sheet.setFrozenRows(1);
    // Mise en forme de l'en-tête
    sheet.getRange(1, 1, 1, 6).setBackground("#003366").setFontColor("#FFFFFF").setFontWeight("bold");
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

    if (body.action === "save_quest")      return saveQuestionnaire(body);
    if (body.action === "register_email")  return registerEmail(body);
    if (body.action === "activate_key")    return activateKey(body);
    if (body.action === "assign_key")      return doPostAssignKey(body);

    // Comportement par défaut : envoyer des réponses
    return saveReponses(body);

  } catch(err) {
    return jsonResponse({ status: "error", message: err.message });
  }
}

// ── Réponses ─────────────────────────────────────────────────────────────────

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

// ── Questionnaires ────────────────────────────────────────────────────────────

function saveQuestionnaire(body) {
  var sheet      = getSheetQuestionnaires();
  var uid        = body.uid        || "";
  var nom        = body.nom        || "";
  var quest_json = body.quest_json || "{}";
  var publie_le  = new Date().toISOString();

  if (!uid) return jsonResponse({ status: "error", message: "uid manquant" });

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

// ── LICENCES ─────────────────────────────────────────────────────────────────

// Enregistrer un email (1er lancement trial)
function registerEmail(body) {
  var email = (body.email || "").toString().toLowerCase().trim();
  if (!email) return jsonResponse({ status: "error", message: "email manquant" });

  var sheet = getSheetLicences();
  var data  = sheet.getDataRange().getValues();

  // Vérifier si email déjà enregistré
  for (var i = 1; i < data.length; i++) {
    if (data[i][0].toString().toLowerCase() === email) {
      // Retourner le statut existant
      return jsonResponse(buildLicenceResponse(data[i]));
    }
  }

  // Nouvel email → trial
  var now = new Date().toISOString();
  sheet.appendRow([email, now, "trial", "", "", TRIAL_DAYS]);
  return jsonResponse({
    status:        "ok",
    action:        "registered",
    email:         email,
    statut:        "trial",
    jours_restants: TRIAL_DAYS,
    message:       "Trial de " + TRIAL_DAYS + " jours démarré"
  });
}

// Activer une clé licence
function activateKey(body) {
  var email = (body.email || "").toString().toLowerCase().trim();
  var cle   = (body.cle   || "").toString().trim();
  if (!email || !cle) return jsonResponse({ status: "error", message: "email ou clé manquant" });

  var sheet = getSheetLicences();
  var data  = sheet.getDataRange().getValues();

  for (var i = 1; i < data.length; i++) {
    if (data[i][0].toString().toLowerCase() === email) {
      var stored_cle = data[i][3].toString().trim();
      if (stored_cle === "") {
        return jsonResponse({ status: "error", message: "Aucune clé attribuée à cet email. Contactez le support." });
      }
      if (stored_cle !== cle) {
        return jsonResponse({ status: "error", message: "Clé incorrecte" });
      }
      // Clé valide → activer
      sheet.getRange(i + 1, 3).setValue("premium");
      sheet.getRange(i + 1, 5).setValue(new Date().toISOString());
      return jsonResponse({
        status:  "ok",
        action:  "activated",
        email:   email,
        statut:  "premium",
        message: "Licence premium activée avec succès"
      });
    }
  }
  return jsonResponse({ status: "error", message: "Email non trouvé. Lancez d'abord l'application." });
}

// Construire la réponse licence depuis une ligne Sheet
function buildLicenceResponse(row) {
  var email            = row[0].toString();
  var date_inscription = row[1].toString();
  var statut           = row[2].toString();
  var jours_trial      = row[5] ? parseInt(row[5]) : TRIAL_DAYS;

  if (statut === "premium") {
    return {
      status:         "ok",
      email:          email,
      statut:         "premium",
      jours_restants: 9999,
      message:        "Licence premium active"
    };
  }

  // Calcul jours restants pour trial
  var debut    = new Date(date_inscription);
  var now      = new Date();
  var diff_ms  = now - debut;
  var diff_j   = Math.floor(diff_ms / (1000 * 60 * 60 * 24));
  var restants = jours_trial - diff_j;

  if (restants <= 0) {
    return {
      status:         "ok",
      email:          email,
      statut:         "expire",
      jours_restants: 0,
      message:        "Trial expiré. Activez une licence premium."
    };
  }

  return {
    status:         "ok",
    email:          email,
    statut:         "trial",
    jours_restants: restants,
    message:        "Trial actif — " + restants + " jour(s) restant(s)"
  };
}

// ── GET ──────────────────────────────────────────────────────────────────────

function doGet(e) {
  var action   = (e.parameter.action   || "info").toLowerCase();
  var quest_id = (e.parameter.quest_id || "").toString();
  var uid      = (e.parameter.uid      || "").toString();
  var email    = (e.parameter.email    || "").toString().toLowerCase().trim();

  try {

    // ── INFO ──
    if (action === "info") {
      var nr = Math.max(0, getSheetReponses().getLastRow() - 1);
      var nq = Math.max(0, getSheetQuestionnaires().getLastRow() - 1);
      var nl = Math.max(0, getSheetLicences().getLastRow() - 1);
      return jsonResponse({ status: "ok", version: VERSION, nb_reponses: nr, nb_questionnaires: nq, nb_licences: nl });
    }

    // ── CHECK_LICENCE ──
    if (action === "check_licence") {
      if (!email) return jsonResponse({ status: "error", message: "email manquant" });
      var sheet = getSheetLicences();
      var data  = sheet.getDataRange().getValues();
      for (var i = 1; i < data.length; i++) {
        if (data[i][0].toString().toLowerCase() === email) {
          return jsonResponse(buildLicenceResponse(data[i]));
        }
      }
      return jsonResponse({ status: "ok", statut: "inconnu", message: "Email non enregistré" });
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

    // ── LIST_LICENCES ──
    if (action === "list_licences") {
      var sheet = getSheetLicences();
      var data  = sheet.getDataRange().getValues();
      var rows  = [];
      for (var i = 1; i < data.length; i++) {
        rows.push({
          email:            data[i][0], date_inscription: data[i][1],
          statut:           data[i][2], cle:              data[i][3],
          date_activation:  data[i][4], jours_trial:      data[i][5]
        });
      }
      return jsonResponse({ status: "ok", licences: rows });
    }

    return jsonResponse({ status: "error", message: "action inconnue: " + action });

  } catch(err) {
    return jsonResponse({ status: "error", message: err.message });
  }
}

// ── ADMIN — Attribuer une clé à un email ─────────────────────────────────────
// Appelé depuis l'interface admin Desktop R (POST avec action:"assign_key")
function doPostAssignKey(body) {
  var email = (body.email || "").toString().toLowerCase().trim();
  var cle   = (body.cle   || "").toString().trim();
  if (!email || !cle) return jsonResponse({ status: "error", message: "email ou clé manquant" });

  var sheet = getSheetLicences();
  var data  = sheet.getDataRange().getValues();

  for (var i = 1; i < data.length; i++) {
    if (data[i][0].toString().toLowerCase() === email) {
      sheet.getRange(i + 1, 4).setValue(cle);
      return jsonResponse({ status: "ok", action: "key_assigned", email: email });
    }
  }
  // Email pas encore enregistré → on crée la ligne directement en premium
  var now = new Date().toISOString();
  sheet.appendRow([email, now, "trial", cle, "", TRIAL_DAYS]);
  return jsonResponse({ status: "ok", action: "key_assigned_new", email: email });
}

// Route doPost complète avec assign_key
// (remplace la fonction doPost principale ci-dessus)
// Note: déjà intégré dans doPost via les actions

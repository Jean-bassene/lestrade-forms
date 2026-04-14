// ============================================================================
// Lestrade Forms — Panier Google Apps Script v3
// Déployer comme "Application Web" > Accès : Tout le monde (anonyme)
//
// POST /exec                                   → envoyer réponses OU sauvegarder questionnaire
// POST /exec  { action:"save_quest" }          → sauvegarder questionnaire
// POST /exec  { action:"register_email" }      → enregistrer email trial
// POST /exec  { action:"activate_key" }        → activer une clé licence (email optionnel)
// POST /exec  { action:"change_email" }        → changer l'email d'une licence
// GET  /exec?action=info                       → statut général
// GET  /exec?action=list[&quest_id=X]          → lister réponses du panier
// GET  /exec?action=clear[&quest_id=X]         → vider le panier
// GET  /exec?action=get_quest&uid=LEST-XX      → récupérer un questionnaire
// GET  /exec?action=check_licence&email=X      → vérifier statut licence
// GET  /exec?action=check_key&cle=LEST-XXXX   → vérifier clé seule (retourne email + statut)
// GET  /exec?action=list_pending              → lister demandes en attente de paiement (admin)
// POST /exec  { action:"request_licence" }    → demande licence depuis landing page → email auto
// POST /exec  { action:"admin_activate" }     → activer une clé (admin) → email confirmation client
// ============================================================================

var SHEET_REPONSES       = "Panier";
var SHEET_QUESTIONNAIRES = "Questionnaires";
var SHEET_LICENCES       = "Licences";
var VERSION              = "3.0";
var TRIAL_DAYS           = 90;

var ADMIN_EMAIL          = "bassene.jean@yahoo.com";
var APP_NAME             = "Lestrade Forms";
var TARIFS               = { annuel: "25 000 FCFA (~38 €)", permanent: "75 000 FCFA (~114 €) — 5 clés" };
var WAVE_NUMBER          = "+221 77 500 89 88";

// ── Feuilles ─────────────────────────────────────────────────────────────────

function getSheetReponses() {
  var ss    = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(SHEET_REPONSES);
  if (!sheet) {
    sheet = ss.insertSheet(SHEET_REPONSES);
    sheet.appendRow(["quest_id", "uuid", "horodateur", "donnees_json", "recu_le", "latitude", "longitude"]);
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

    if (body.action === "save_quest")       return saveQuestionnaire(body);
    if (body.action === "register_email")  return registerEmail(body);
    if (body.action === "activate_key")    return activateKey(body);
    if (body.action === "change_email")    return changeEmail(body);
    if (body.action === "assign_key")      return doPostAssignKey(body);
    if (body.action === "request_licence") return requestLicence(body);
    if (body.action === "admin_activate")  return adminActivate(body);

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
    // Extraire lat/lon du JSON pour colonnes séparées
    var lat = "", lon = "";
    try {
      var d = JSON.parse(rep.donnees_json || "{}");
      if (d._latitude  !== undefined) lat = d._latitude;
      if (d._longitude !== undefined) lon = d._longitude;
    } catch(ex) {}
    sheet.appendRow([quest_id, uuid, rep.horodateur || recu_le, rep.donnees_json || "{}", recu_le, lat, lon]);
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
  var now       = new Date();
  var nowIso    = now.toISOString();
  var expiry    = new Date(now.getTime() + TRIAL_DAYS * 24 * 60 * 60 * 1000);
  var expiryStr = Utilities.formatDate(expiry, "Africa/Dakar", "dd/MM/yyyy");

  sheet.appendRow([email, nowIso, "trial", "", "", TRIAL_DAYS]);

  // ── Email 1 : Bienvenue trial ──
  var sujet = "[" + APP_NAME + "] Bienvenue — votre trial de " + TRIAL_DAYS + " jours a démarré";
  var corps =
    "Bonjour,\n\n" +
    "Merci d'utiliser " + APP_NAME + " !\n\n" +
    "Votre période d'essai gratuite est maintenant active.\n\n" +
    "┌─────────────────────────────────────┐\n" +
    "│  TRIAL GRATUIT                      │\n" +
    "│  Email   : " + email + "\n" +
    "│  Durée   : " + TRIAL_DAYS + " jours complets          │\n" +
    "│  Expire  : " + expiryStr + "                  │\n" +
    "└─────────────────────────────────────┘\n\n" +
    "Pendant votre trial, vous avez accès à toutes les fonctionnalités :\n" +
    "  ✓ Création de questionnaires illimités\n" +
    "  ✓ Collecte de réponses sur mobile\n" +
    "  ✓ Tableaux de bord analytiques\n" +
    "  ✓ Export CSV / Excel\n" +
    "  ✓ Synchronisation via panier Google Sheets\n\n" +
    "Pour continuer après le " + expiryStr + ", choisissez une licence :\n\n" +
    "  • Annuelle  : " + TARIFS.annuel + "\n" +
    "  • Permanente: " + TARIFS.permanent + "\n\n" +
    "Demandez votre licence : " + ADMIN_EMAIL + "\n" +
    "Paiement via Wave : " + WAVE_NUMBER + "\n\n" +
    "Bonne collecte de données !\n\n" +
    "L'équipe " + APP_NAME + "\n" +
    ADMIN_EMAIL + " · " + WAVE_NUMBER;

  try { GmailApp.sendEmail(email, sujet, corps, { name: APP_NAME, replyTo: ADMIN_EMAIL }); } catch(e) {}

  return jsonResponse({
    status:        "ok",
    action:        "registered",
    email:         email,
    statut:        "trial",
    jours_restants: TRIAL_DAYS,
    message:       "Trial de " + TRIAL_DAYS + " jours démarré"
  });
}

// Activer une clé licence (email optionnel — mode clé seule si absent)
function activateKey(body) {
  var email = (body.email || "").toString().toLowerCase().trim();
  var cle   = (body.cle   || "").toString().trim();
  if (!cle) return jsonResponse({ status: "error", message: "clé manquante" });

  var sheet = getSheetLicences();
  var data  = sheet.getDataRange().getValues();

  for (var i = 1; i < data.length; i++) {
    var row_email = data[i][0].toString().toLowerCase();
    var row_cle   = data[i][3].toString().trim();

    // Filtrer par email si fourni
    if (email && row_email !== email) continue;

    // Chercher la ligne dont la clé correspond
    if (row_cle === "" || row_cle !== cle) continue;

    // Clé valide → activer premium
    sheet.getRange(i + 1, 3).setValue("premium");
    sheet.getRange(i + 1, 5).setValue(new Date().toISOString());
    return jsonResponse({
      status:  "ok",
      action:  "activated",
      email:   row_email,
      statut:  "premium",
      message: "Licence premium activée avec succès"
    });
  }

  if (email) {
    return jsonResponse({ status: "error", message: "Clé incorrecte pour cet email. Vérifiez ou contactez le support." });
  }
  return jsonResponse({ status: "error", message: "Clé non reconnue. Vérifiez la clé ou contactez le support." });
}

// Changer l'email d'une licence existante
function changeEmail(body) {
  var old_email = (body.old_email || "").toString().toLowerCase().trim();
  var new_email = (body.new_email || "").toString().toLowerCase().trim();
  if (!new_email) return jsonResponse({ status: "error", message: "new_email manquant" });
  if (old_email === new_email) return jsonResponse({ status: "ok", action: "no_change", email: new_email });

  var sheet = getSheetLicences();
  var data  = sheet.getDataRange().getValues();

  // Si new_email existe déjà → restaurer son statut (auto-restore)
  for (var i = 1; i < data.length; i++) {
    if (data[i][0].toString().toLowerCase() === new_email) {
      var resp = buildLicenceResponse(data[i]);
      resp.action = "restored";
      return jsonResponse(resp);
    }
  }

  // Mettre à jour l'email dans la ligne existante
  if (old_email) {
    for (var i = 1; i < data.length; i++) {
      if (data[i][0].toString().toLowerCase() === old_email) {
        sheet.getRange(i + 1, 1).setValue(new_email);
        var updated_row = sheet.getRange(i + 1, 1, 1, 6).getValues()[0];
        var resp2 = buildLicenceResponse(updated_row);
        resp2.action = "updated";
        return jsonResponse(resp2);
      }
    }
  }

  // Aucun old_email trouvé → nouveau trial pour new_email + email bienvenue
  var now     = new Date();
  var nowIso  = now.toISOString();
  var expiry  = new Date(now.getTime() + TRIAL_DAYS * 24 * 60 * 60 * 1000);
  var expiryStr = Utilities.formatDate(expiry, "Africa/Dakar", "dd/MM/yyyy");
  sheet.appendRow([new_email, nowIso, "trial", "", "", TRIAL_DAYS]);

  var sujet = "[" + APP_NAME + "] Bienvenue — votre trial de " + TRIAL_DAYS + " jours a démarré";
  var corps =
    "Bonjour,\n\n" +
    "Merci d'utiliser " + APP_NAME + " !\n\n" +
    "Votre période d'essai gratuite est maintenant active.\n\n" +
    "┌─────────────────────────────────────┐\n" +
    "│  TRIAL GRATUIT                      │\n" +
    "│  Email   : " + new_email + "\n" +
    "│  Durée   : " + TRIAL_DAYS + " jours complets          │\n" +
    "│  Expire  : " + expiryStr + "                  │\n" +
    "└─────────────────────────────────────┘\n\n" +
    "Pendant votre trial, vous avez accès à toutes les fonctionnalités.\n\n" +
    "Pour continuer après le " + expiryStr + " :\n" +
    "  • Annuelle  : " + TARIFS.annuel + "\n" +
    "  • Permanente: " + TARIFS.permanent + "\n\n" +
    "Demandez votre licence : " + ADMIN_EMAIL + "\n" +
    "Paiement via Wave : " + WAVE_NUMBER + "\n\n" +
    "Bonne collecte de données !\n" +
    "L'équipe " + APP_NAME;
  try { GmailApp.sendEmail(new_email, sujet, corps, { name: APP_NAME, replyTo: ADMIN_EMAIL }); } catch(e) {}

  return jsonResponse({
    status:         "ok",
    action:         "registered",
    email:          new_email,
    statut:         "trial",
    jours_restants: TRIAL_DAYS,
    message:        "Nouvel email enregistré — trial de " + TRIAL_DAYS + " jours"
  });
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

    // ── CHECK_KEY (clé seule → email + statut) ──
    if (action === "check_key") {
      var cle = (e.parameter.cle || "").toString().trim();
      if (!cle) return jsonResponse({ status: "error", message: "cle manquante" });
      var sheet = getSheetLicences();
      var data  = sheet.getDataRange().getValues();
      for (var i = 1; i < data.length; i++) {
        if (data[i][3].toString().trim() === cle) {
          var resp = buildLicenceResponse(data[i]);
          resp.key_found = true;
          return jsonResponse(resp);
        }
      }
      return jsonResponse({ status: "error", message: "Clé non reconnue" });
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

    // ── REQUEST_LICENCE (depuis landing page via GET) ──
    if (action === "request_licence") {
      var nom_g     = (e.parameter.nom     || "").toString().trim();
      var email_g   = (e.parameter.email   || "").toString().toLowerCase().trim();
      var formule_g = (e.parameter.formule || "annuel").toString().toLowerCase().trim();
      if (!email_g) return jsonResponse({ status: "error", message: "email manquant" });
      return requestLicence({ nom: nom_g, email: email_g, formule: formule_g });
    }

    // ── LIST_PENDING ──
    if (action === "list_pending") {
      var sheet = getSheetLicences();
      var data  = sheet.getDataRange().getValues();
      var rows  = [];
      for (var i = 1; i < data.length; i++) {
        if (data[i][2].toString() === "pending") {
          rows.push({
            email:            data[i][0].toString(),
            date_demande:     data[i][1].toString(),
            cle:              data[i][3].toString(),
            formule:          data[i][5].toString()
          });
        }
      }
      return jsonResponse({ status: "ok", pending: rows });
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

// ── DEMANDE DE LICENCE (depuis landing page) ──────────────────────────────────
// POST { action:"request_licence", nom, email, formule:"annuel"|"permanent" }
// → génère clé inactive, enregistre dans Licences, envoie email client + notif admin
function requestLicence(body) {
  var nom     = (body.nom     || "").toString().trim();
  var email   = (body.email   || "").toString().toLowerCase().trim();
  var formule = (body.formule || "annuel").toString().toLowerCase().trim();

  if (!email) return jsonResponse({ status: "error", message: "email manquant" });
  if (!nom)   nom = email;

  var montant = formule === "permanent" ? TARIFS.permanent : TARIFS.annuel;
  var libelle = formule === "permanent" ? "Licence Permanente" : "Licence Annuelle";

  // Générer clé unique
  var seed = email + nom + new Date().getTime() + Math.random();
  var hash = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256,
             seed, Utilities.Charset.UTF_8)
             .map(function(b) { return (b < 0 ? b + 256 : b).toString(16).padStart(2, "0"); })
             .join("").toUpperCase().substring(0, 16);
  var cle = "LEST-" + hash.substring(0,4) + "-" + hash.substring(4,8) + "-" +
                       hash.substring(8,12) + "-" + hash.substring(12,16);

  // Enregistrer dans le Sheet (statut "pending" = clé inactive en attente de paiement)
  var sheet = getSheetLicences();
  var data  = sheet.getDataRange().getValues();
  var now   = new Date().toISOString();
  var found = false;

  for (var i = 1; i < data.length; i++) {
    if (data[i][0].toString().toLowerCase() === email) {
      // Email déjà présent → mettre à jour la clé et la formule
      sheet.getRange(i + 1, 3).setValue("pending");
      sheet.getRange(i + 1, 4).setValue(cle);
      sheet.getRange(i + 1, 6).setValue(formule);
      found = true;
      break;
    }
  }
  if (!found) {
    sheet.appendRow([email, now, "pending", cle, "", formule]);
  }

  // ── Email au client ──
  var sujet_client = "[" + APP_NAME + "] Votre clé de licence — en attente de paiement";
  var corps_client =
    "Bonjour " + nom + ",\n\n" +
    "Merci pour votre demande de licence " + APP_NAME + ".\n\n" +
    "Voici votre clé de licence :\n\n" +
    "    " + cle + "\n\n" +
    "⚠️  Cette clé est inactive. Elle sera activée dès réception de votre paiement.\n\n" +
    "──────────────────────────────\n" +
    "Formule choisie : " + libelle + "\n" +
    "Montant à envoyer : " + montant + "\n" +
    "──────────────────────────────\n\n" +
    "Comment payer :\n" +
    "  • Wave : envoyez " + montant + " au " + WAVE_NUMBER + "\n" +
    "  • Virement bancaire : contactez-nous pour les coordonnées\n\n" +
    "Important : mentionnez votre clé (" + cle + ") comme référence du paiement.\n\n" +
    "Une fois le paiement confirmé, votre clé sera activée sous 24h.\n" +
    "Saisissez-la dans l'application : menu Licence → Entrer une clé.\n\n" +
    "Pour toute question : " + ADMIN_EMAIL + " · " + WAVE_NUMBER + "\n\n" +
    "Cordialement,\n" +
    "L'équipe " + APP_NAME;

  GmailApp.sendEmail(email, sujet_client, corps_client, { name: APP_NAME, replyTo: ADMIN_EMAIL });

  // ── Notification admin ──
  var sujet_admin = "[" + APP_NAME + "] Nouvelle demande — " + nom + " (" + libelle + ")";
  var corps_admin =
    "Nouvelle demande de licence reçue.\n\n" +
    "Nom    : " + nom    + "\n" +
    "Email  : " + email  + "\n" +
    "Formule: " + libelle + " — " + montant + "\n" +
    "Clé    : " + cle    + "\n" +
    "Date   : " + now    + "\n\n" +
    "→ Dès réception du paiement Wave, activez la clé depuis l'app (onglet Admin)\n" +
    "  ou directement dans le Sheet Licences : statut → premium.";

  GmailApp.sendEmail(ADMIN_EMAIL, sujet_admin, corps_admin, { name: APP_NAME });

  return jsonResponse({
    status:  "ok",
    action:  "requested",
    email:   email,
    cle:     cle,
    formule: formule,
    montant: montant,
    message: "Clé envoyée par email. En attente de paiement."
  });
}

// ── ACTIVATION ADMIN (depuis app desktop) ────────────────────────────────────
// POST { action:"admin_activate", cle, admin_token }
// → passe le statut à "premium" + envoie email de confirmation au client
function adminActivate(body) {
  var cle         = (body.cle         || "").toString().trim();
  var admin_token = (body.admin_token || "").toString().trim();

  // Token simple : hash de ADMIN_EMAIL — à améliorer si besoin
  var expected = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256,
                 ADMIN_EMAIL, Utilities.Charset.UTF_8)
                 .map(function(b) { return (b < 0 ? b + 256 : b).toString(16).padStart(2, "0"); })
                 .join("").substring(0, 16).toUpperCase();

  if (admin_token !== expected) {
    return jsonResponse({ status: "error", message: "Token admin invalide." });
  }

  if (!cle) return jsonResponse({ status: "error", message: "clé manquante" });

  var sheet = getSheetLicences();
  var data  = sheet.getDataRange().getValues();

  for (var i = 1; i < data.length; i++) {
    if (data[i][3].toString().trim() === cle) {
      var email   = data[i][0].toString();
      var formule = data[i][5].toString();
      var libelle = formule === "permanent" ? "Licence Permanente" : "Licence Annuelle";

      var now        = new Date();
      var dateStr    = Utilities.formatDate(now, "Africa/Dakar", "dd/MM/yyyy");
      var heureStr   = Utilities.formatDate(now, "Africa/Dakar", "HH:mm");
      var montant    = formule === "permanent" ? TARIFS.permanent : TARIFS.annuel;

      // Numéro de reçu : LF-AAAA-XXXX (basé sur le nb de licences premium)
      var nbPremium  = 0;
      for (var j = 1; j < data.length; j++) {
        if (data[j][2].toString() === "premium") nbPremium++;
      }
      var numRecu = "LF-" + now.getFullYear() + "-" + String(nbPremium + 1).padStart(4, "0");

      sheet.getRange(i + 1, 3).setValue("premium");
      sheet.getRange(i + 1, 5).setValue(now.toISOString());

      // ── Pack Permanent : générer 4 clés supplémentaires (total 5) ──
      var toutesLesCles = [cle];
      if (formule === "permanent") {
        for (var k = 0; k < 4; k++) {
          var seed2 = email + now.getTime() + k + Math.random();
          var hash2 = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256,
                      seed2.toString(), Utilities.Charset.UTF_8)
                      .map(function(b) { return (b < 0 ? b + 256 : b).toString(16).padStart(2, "0"); })
                      .join("").toUpperCase().substring(0, 16);
          var cleExtra = "LEST-" + hash2.substring(0,4) + "-" + hash2.substring(4,8) + "-" +
                                   hash2.substring(8,12) + "-" + hash2.substring(12,16);
          toutesLesCles.push(cleExtra);
          sheet.appendRow([email, now.toISOString(), "premium", cleExtra, now.toISOString(), "permanent"]);
        }
      }

      // ── Email 3 : Reçu / Ticket de caisse ──
      var sujet = "[" + APP_NAME + "] ✓ Paiement reçu — Licence activée — " + numRecu;
      var ligne = "─────────────────────────────────────────";
      var clesList = toutesLesCles.length === 1
        ? "  Clé     : " + toutesLesCles[0]
        : toutesLesCles.map(function(c, idx) {
            return "  Clé " + (idx + 1) + "   : " + c;
          }).join("\n");
      var activerInstr = toutesLesCles.length === 1
        ? "  3. Entrez votre clé : " + toutesLesCles[0]
        : "  3. Chaque utilisateur entre sa propre clé dans l'application";
      var corps =
        "Bonjour,\n\n" +
        "Votre paiement a été reçu et votre licence est activée. Merci !\n\n" +
        ligne + "\n" +
        "  REÇU — " + APP_NAME + "\n" +
        "  N° " + numRecu + "\n" +
        ligne + "\n" +
        "  Client  : " + email + "\n" +
        "  Formule : " + libelle + "\n" +
        "  Montant : " + montant + "\n" +
        "  Date    : " + dateStr + " à " + heureStr + "\n" +
        clesList + "\n" +
        ligne + "\n\n" +
        "Comment activer dans l'application :\n" +
        "  1. Ouvrez Lestrade Forms\n" +
        "  2. Cliquez sur le badge de licence en haut à droite\n" +
        activerInstr + "\n" +
        "  4. Cliquez Activer → l'accès premium est immédiat\n\n" +
        "Conservez ce reçu comme preuve de paiement.\n\n" +
        "Merci pour votre confiance !\n" +
        "L'équipe " + APP_NAME + "\n" +
        ADMIN_EMAIL + " · " + WAVE_NUMBER;

      GmailApp.sendEmail(email, sujet, corps, { name: APP_NAME, replyTo: ADMIN_EMAIL });

      return jsonResponse({
        status:  "ok",
        action:  "activated",
        email:   email,
        cle:     cle,
        cles:    toutesLesCles,
        message: "Licence activée — " + toutesLesCles.length + " clé(s) envoyée(s) à " + email
      });
    }
  }

  return jsonResponse({ status: "error", message: "Clé non trouvée : " + cle });
}

// ── LISTE DEMANDES EN ATTENTE (admin) ─────────────────────────────────────────
// GET ?action=list_pending → retourne toutes les licences en statut "pending"
// (ajout dans doGet → déjà couvert par list_licences, mais filtré ici pour commodité)
// Note: déjà intégré dans doPost via les actions

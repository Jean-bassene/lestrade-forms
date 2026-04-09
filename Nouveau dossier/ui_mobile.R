# ============================================================================
# ui_mobile.R  — Lestrade Forms Mobile  v3
# UI pure Shiny + CSS mobile — zéro Framework7
# ============================================================================

library(shiny)
library(shinyjs)

MOB_CSS <- "
/* ── Variables ── */
:root {
  --navy:  #0D1F35;
  --teal:  #0A8075;
  --amber: #E8A020;
  --red:   #C0392B;
  --surf:  #F5F7FA;
  --bord:  #DDE3EC;
  --text2: #4A5870;
  --text3: #8896A7;
}

/* ── Reset ── */
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  background: var(--surf);
  color: var(--navy);
  font-size: 15px;
  line-height: 1.5;
  max-width: 480px;
  margin: 0 auto;
  padding-bottom: 70px;  /* espace barre nav */
}

/* ── Header fixe ── */
.mob-header {
  position: fixed; top: 0; left: 0; right: 0; z-index: 100;
  background: var(--navy);
  padding: 14px 18px;
  display: flex; align-items: center;
  max-width: 480px; margin: 0 auto;
  box-shadow: 0 2px 12px rgba(0,0,0,.2);
}
.mob-brand { color: #fff; font-size: 1.1rem; font-weight: 700; }
.mob-brand span { color: var(--amber); font-weight: 300; }
.mob-status { margin-left: auto; font-size: 12px; display: flex; gap: 6px; }
.st-pill {
  padding: 3px 10px; border-radius: 999px; font-weight: 600; font-size: 11px;
}
.st-ok  { background: #D1F0EC; color: var(--teal); }
.st-off { background: #FDECEA; color: var(--red); }

/* ── Contenu principal ── */
.mob-content { margin-top: 60px; }

/* ── Onglets ── */
.mob-tab { display: none; padding: 16px; }
.mob-tab.active { display: block; }

/* ── Barre de navigation fixe en bas ── */
.mob-nav {
  position: fixed; bottom: 0; left: 0; right: 0; z-index: 100;
  background: #fff;
  border-top: 1px solid var(--bord);
  display: flex;
  max-width: 480px; margin: 0 auto;
  box-shadow: 0 -2px 10px rgba(0,0,0,.06);
}
.mob-nav-btn {
  flex: 1; border: none; background: transparent;
  padding: 8px 4px; cursor: pointer;
  display: flex; flex-direction: column; align-items: center; gap: 2px;
  color: var(--text3); font-size: 10px; font-weight: 500;
  transition: color .15s;
}
.mob-nav-btn .nav-icon { font-size: 22px; line-height: 1; }
.mob-nav-btn.active { color: var(--navy); }
.mob-nav-btn.active .nav-icon { transform: scale(1.1); }

/* ── Cards ── */
.mob-card {
  background: #fff;
  border: 1px solid var(--bord);
  border-radius: 14px;
  padding: 16px;
  margin-bottom: 14px;
  box-shadow: 0 2px 8px rgba(13,31,53,.05);
  overflow: hidden;
  word-break: break-word;
  overflow-wrap: break-word;
}
.mob-card-title {
  font-size: 11px; font-weight: 700; text-transform: uppercase;
  letter-spacing: .06em; color: var(--text3); margin-bottom: 12px;
}
/* Labels Shiny dans les cards — empêcher le débordement */
.mob-card label {
  white-space: normal;
  word-break: break-word;
  overflow-wrap: break-word;
  max-width: 100%;
}
.mob-card .shiny-input-container {
  max-width: 100%;
  overflow: hidden;
}

/* ── KPIs ── */
.mob-kpi-row { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.mob-kpi {
  background: #fff; border: 1px solid var(--bord);
  border-radius: 12px; padding: 14px; text-align: center;
}
.mob-kpi-val { font-size: 2rem; font-weight: 700; color: var(--navy); line-height: 1; }
.mob-kpi-lbl { font-size: 10px; text-transform: uppercase; letter-spacing: .05em; color: var(--text3); margin-top: 4px; }

/* ── Boutons ── */
.btn-mob {
  width: 100%; padding: 13px; border: none; border-radius: 12px;
  font-size: 15px; font-weight: 600; cursor: pointer;
  margin-bottom: 10px; letter-spacing: .01em;
  transition: opacity .15s;
}
.btn-mob:active { opacity: .85; }
.btn-primary-mob { background: var(--navy); color: #fff; }
.btn-teal-mob    { background: var(--teal); color: #fff; }
.btn-outline-mob { background: #fff; color: var(--navy); border: 1.5px solid var(--bord) !important; }
.btn-red-mob     { background: #fff; color: var(--red); border: 1.5px solid var(--red) !important; }
.btn-row { display: flex; gap: 10px; }
.btn-row .btn-mob { margin-bottom: 0; }

/* ── Listes réponses ── */
.rep-item {
  display: flex; align-items: center; gap: 10px;
  padding: 10px 0; border-bottom: 1px solid var(--surf);
}
.rep-dot { width: 9px; height: 9px; border-radius: 50%; flex-shrink: 0; }
.dot-pending { background: var(--amber); }
.dot-synced  { background: var(--teal); }
.rep-meta { font-size: 11px; color: var(--text3); margin-top: 2px; }

/* ── Scanner ── */
#qr-reader { width: 100%; max-width: 280px; margin: 0 auto 14px;
              border-radius: 10px; overflow: hidden; }
.scan-ok  { background: #D1F0EC; border-radius: 10px; padding: 12px 14px; font-size: 13px; color: var(--teal); }
.scan-err { background: #FDECEA; border-radius: 10px; padding: 12px 14px; font-size: 13px; color: var(--red); }

/* ── Inputs Shiny ── */
.form-control { border: 1.5px solid var(--bord) !important; border-radius: 8px !important; font-size: 14px !important; }
.form-control:focus { border-color: var(--navy) !important; box-shadow: 0 0 0 3px rgba(13,31,53,.08) !important; outline: none !important; }
label { font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: .04em; color: var(--text2); margin-bottom: 5px; display: block; }
.shiny-input-container { margin-bottom: 14px; width: 100% !important; }
select.form-control { appearance: auto !important; }
.shiny-date-input { width: 100% !important; }

/* ── Radio & Checkbox — reset complet pour afficher les boutons ── */
.radio, .checkbox { margin: 2px 0 !important; overflow: visible !important; }
.radio label, .checkbox label {
  text-transform: none !important; font-weight: 400 !important;
  letter-spacing: 0 !important; font-size: 14px !important;
  color: var(--navy) !important;
  display: flex !important; align-items: center !important;
  gap: 10px !important; padding: 6px 0 !important;
  cursor: pointer; white-space: normal;
  overflow: visible !important; max-width: 100%;
}
.radio input[type=radio], .checkbox input[type=checkbox] {
  width: 18px !important; height: 18px !important;
  min-width: 18px !important; flex-shrink: 0 !important;
  accent-color: var(--navy);
  opacity: 1 !important; visibility: visible !important;
  position: static !important; margin: 0 !important;
}
/* Annuler overflow:hidden des cards pour les inputs */
.mob-card .radio, .mob-card .checkbox { overflow: visible !important; }
.mob-card label { overflow: visible !important; }
"

MOB_JS <- "
/* ── Navigation ── */
function goTab(tabName) {
  // Masquer tous les onglets
  document.querySelectorAll('.mob-tab').forEach(function(t) {
    t.classList.remove('active');
  });
  // Afficher la cible
  var target = document.getElementById('tab-' + tabName);
  if (target) target.classList.add('active');
  // Mettre à jour la nav
  document.querySelectorAll('.mob-nav-btn').forEach(function(b) {
    b.classList.remove('active');
    if (b.dataset.tab === tabName) b.classList.add('active');
  });
  // Notifier Shiny
  Shiny.setInputValue('active_tab', tabName, {priority:'event'});
}

// Clics nav
$(document).on('click', '.mob-nav-btn', function() {
  goTab($(this).data('tab'));
});

// Clics boutons action — délégation jQuery
$(document).on('click', '#btn_mob_start',          function() { Shiny.setInputValue('btn_mob_start',          Math.random(), {priority:'event'}); goTab('formulaire'); });
$(document).on('click', '#btn_mob_submit',         function() { Shiny.setInputValue('btn_mob_submit',         Math.random(), {priority:'event'}); });
$(document).on('click', '#btn_mob_save_draft',     function() { Shiny.setInputValue('btn_mob_save_draft',     Math.random(), {priority:'event'}); });
$(document).on('click', '#btn_mob_connect_drive',  function() { Shiny.setInputValue('btn_mob_connect_drive',  Math.random(), {priority:'event'}); });
$(document).on('click', '#btn_mob_connect_drive2', function() { Shiny.setInputValue('btn_mob_connect_drive2', Math.random(), {priority:'event'}); });
$(document).on('click', '#btn_mob_sync',           function() { Shiny.setInputValue('btn_mob_sync',           Math.random(), {priority:'event'}); });
$(document).on('click', '#btn_import_manual_uid',  function() { Shiny.setInputValue('btn_import_manual_uid',  Math.random(), {priority:'event'}); });
$(document).on('click', '#btn_mob_logout_drive',        function() { Shiny.setInputValue('btn_mob_logout_drive',        Math.random(), {priority:'event'}); });
$(document).on('click', '#btn_mob_connect_drive_scan', function() { Shiny.setInputValue('btn_mob_connect_drive_scan', Math.random(), {priority:'event'}); });
$(document).on('click', '#btn_mob_add_account',        function() { Shiny.setInputValue('btn_mob_add_account',        Math.random(), {priority:'event'}); });
$(document).on('click', '#btn_list_drive_quests',      function() { Shiny.setInputValue('btn_list_drive_quests',      Math.random(), {priority:'event'}); });
$(document).on('click', '.btn-import-drive-quest',     function() { Shiny.setInputValue('mob_import_drive_quest', $(this).data('uid'), {priority:'event'}); });
$(document).on('click', '#btn_mob_remove_account',     function() { Shiny.setInputValue('btn_mob_remove_account',     Math.random(), {priority:'event'}); });
$(document).on('click', '.mob-account-btn',            function() { Shiny.setInputValue('mob_switch_account', $(this).data('email'), {priority:'event'}); });

// Répondre aux messages Shiny
$(document).on('shiny:connected', function() {
  Shiny.addCustomMessageHandler('goTab', function(tabName) { goTab(tabName); });
});

// Scanner QR
var qrScanner = null, scanRunning = false;

function resetScanUI() {
  scanRunning = false;
  var btnStart = document.getElementById('btn_scan_start');
  var btnStop  = document.getElementById('btn_scan_stop');
  if (btnStart) btnStart.style.display = 'inline-block';
  if (btnStop)  btnStop.style.display  = 'none';
}

function startScan() {
  if (scanRunning) return;

  // Caméra bloquée sur HTTP non-localhost — détecter avant de lancer
  var isSecure = location.protocol === 'https:' || location.hostname === 'localhost' || location.hostname === '127.0.0.1';
  if (!isSecure) {
    Shiny.setInputValue('mob_scan_error',
      'Camera blocked: HTTPS required. Use localhost:' + location.port + ' or enter the ID manually below.',
      {priority:'event'});
    return;
  }

  scanRunning = true;  // marquer AVANT le start async pour éviter la race condition
  document.getElementById('btn_scan_start').style.display = 'none';
  document.getElementById('btn_scan_stop').style.display  = 'inline-block';

  qrScanner = new Html5Qrcode('qr-reader');
  qrScanner.start(
    { facingMode: 'environment' },
    { fps: 10, qrbox: { width: 220, height: 220 } },
    function(decoded) {
      Shiny.setInputValue('mob_qr_scanned', decoded, {priority:'event'});
      stopScan();
    },
    function() {}
  ).catch(function(err) {
    var msg = String(err);
    if (msg.indexOf('NotAllowedError') !== -1 || msg.indexOf('Permission') !== -1) {
      msg = 'Camera permission denied. Allow camera in browser settings or use the manual ID field below.';
    } else {
      msg = 'Camera unavailable: ' + msg;
    }
    Shiny.setInputValue('mob_scan_error', msg, {priority:'event'});
    resetScanUI();
    qrScanner = null;
  });
}

function stopScan() {
  if (qrScanner && scanRunning) {
    qrScanner.stop().catch(function() {});
    qrScanner = null;
  }
  resetScanUI();
}

$(document).on('click', '#btn_scan_start', startScan);
$(document).on('click', '#btn_scan_stop',  stopScan);
"

ui_mobile <- fluidPage(
  useShinyjs(),
  title = "Lestrade Forms",

  tags$head(
    tags$meta(name="viewport", content="width=device-width,initial-scale=1,maximum-scale=1"),
    tags$meta(name="mobile-web-app-capable", content="yes"),
    tags$meta(name="apple-mobile-web-app-capable", content="yes"),
    tags$meta(name="theme-color", content="#0D1F35"),
    tags$script(src="https://unpkg.com/html5-qrcode@2.3.8/html5-qrcode.min.js"),
    tags$style(HTML(MOB_CSS)),
    tags$script(HTML(MOB_JS))
  ),

  # ── Header ────────────────────────────────────────────────────────────────
  div(class="mob-header",
    div(class="mob-brand", "Lestrade", tags$span(" Forms")),
    div(class="mob-status",
      div(id="pill_network", class="st-pill st-off",
          textOutput("mob_network_text", inline=TRUE)),
      div(id="pill_drive",   class="st-pill st-off",
          textOutput("mob_drive_text",   inline=TRUE))
    )
  ),

  # ── Contenu ───────────────────────────────────────────────────────────────
  div(class="mob-content",

    # ══ ACCUEIL ══════════════════════════════════════════════════════════════
    div(id="tab-accueil", class="mob-tab active",

      div(class="mob-card",
        div(class="mob-card-title","Aujourd'hui"),
        div(class="mob-kpi-row",
          div(class="mob-kpi",
            div(class="mob-kpi-val", textOutput("mob_n_local")),
            div(class="mob-kpi-lbl","En attente")),
          div(class="mob-kpi",
            div(class="mob-kpi-val", textOutput("mob_n_synced")),
            div(class="mob-kpi-lbl","Synchronisées"))
        )
      ),

      div(class="mob-card",
        div(class="mob-card-title","Questionnaire actif"),
        selectInput("mob_quest_id", label=NULL, choices=c("Chargement..."=""))
      ),

      tags$button(id="btn_mob_start", class="btn-mob btn-primary-mob",
                  "▶  Démarrer une collecte"),

      uiOutput("mob_pending_alert")
    ),

    # ══ FORMULAIRE ════════════════════════════════════════════════════════════
    div(id="tab-formulaire", class="mob-tab",

      div(class="mob-card",
        uiOutput("mob_form_header")
      ),

      uiOutput("mob_formulaire"),

      div(class="btn-row",
        tags$button(id="btn_mob_save_draft", class="btn-mob btn-outline-mob",
                    style="flex:1;", "Brouillon"),
        tags$button(id="btn_mob_submit",     class="btn-mob btn-teal-mob",
                    style="flex:2;", "✓  Enregistrer")
      )
    ),

    # ══ RÉPONSES ══════════════════════════════════════════════════════════════
    div(id="tab-reponses", class="mob-tab",

      div(class="mob-card",
        div(class="mob-card-title","Google Drive"),
        div(style="margin-bottom:10px;",
            textOutput("mob_drive_status_text", inline=TRUE)),
        tags$button(id="btn_mob_connect_drive2", class="btn-mob btn-outline-mob",
                    "☁  Connecter Google Drive"),
        tags$button(id="btn_mob_sync",           class="btn-mob btn-teal-mob",
                    "↻  Synchroniser maintenant")
      ),

      div(class="mob-card",
        div(class="mob-card-title","Réponses locales"),
        uiOutput("mob_reponses_list")
      )
    ),

    # ══ SCANNER ═══════════════════════════════════════════════════════════════
    div(id="tab-scanner", class="mob-tab",

      div(class="mob-card",
        div(class="mob-card-title","Scanner un QR code"),
        p(style="font-size:13px;color:var(--text2);margin-bottom:14px;",
          "Pointez la caméra vers le QR code affiché sur l'écran Desktop."),
        div(id="qr-reader"),
        div(style="display:flex;gap:10px;justify-content:center;margin-bottom:14px;",
          tags$button(id="btn_scan_start", class="btn-mob btn-teal-mob",
                      style="width:auto;padding:10px 22px;",   "📷 Démarrer"),
          tags$button(id="btn_scan_stop",  class="btn-mob btn-outline-mob",
                      style="width:auto;padding:10px 22px;display:none;","⏹ Arrêter")
        ),
        uiOutput("mob_scan_result")
      ),

      div(class="mob-card",
        div(class="mob-card-title","Questionnaires sur Drive"),
        p(style="font-size:13px;color:var(--text2);margin-bottom:10px;",
          "Listez tous les questionnaires disponibles sur le compte connecté."),
        tags$button(id="btn_list_drive_quests", class="btn-mob btn-outline-mob",
                    "☁  Lister les questionnaires Drive"),
        uiOutput("mob_drive_quests_list_ui")
      ),

      div(class="mob-card",
        div(class="mob-card-title","Identifiant manuel"),
        p(style="font-size:13px;color:var(--text2);margin-bottom:10px;",
          "Format : LEST-0001-A3F2"),
        textInput("mob_manual_uid","", placeholder="LEST-0001-A3F2"),
        tags$button(id="btn_import_manual_uid", class="btn-mob btn-outline-mob",
                    "Importer par identifiant")
      )
    ),

    # ══ PARAMÈTRES ════════════════════════════════════════════════════════════
    div(id="tab-parametres", class="mob-tab",

      div(class="mob-card",
        div(class="mob-card-title","Enquêteur"),
        textInput("mob_param_enqueteur","Votre nom", placeholder="Nom complet")
      ),

      div(class="mob-card",
        div(class="mob-card-title","Options"),
        div(style="display:flex;justify-content:space-between;align-items:center;padding:8px 0;",
          div(div(style="font-weight:500;","Mode hors-ligne"),
              div(style="font-size:12px;color:var(--text3);","Toujours actif")),
          checkboxInput("mob_offline_mode","",value=TRUE)
        ),
        div(style="display:flex;justify-content:space-between;align-items:center;padding:8px 0;",
          div(div(style="font-weight:500;","Sync automatique"),
              div(style="font-size:12px;color:var(--text3);","Dès qu'un réseau est détecté")),
          checkboxInput("mob_auto_sync","",value=FALSE)
        )
      ),

      div(class="mob-card",
        div(class="mob-card-title","Comptes Google Drive"),
        uiOutput("mob_accounts_list_ui"),
        tags$hr(style="border-color:var(--bord);margin:12px 0;"),
        tags$button(id="btn_mob_add_account", class="btn-mob btn-outline-mob",
                    "＋  Ajouter un compte Google"),
        tags$button(id="btn_mob_remove_account", class="btn-mob btn-red-mob",
                    "✕  Retirer le compte sélectionné")
      ),

      div(class="mob-card",
        div(style="text-align:center;padding:8px 0;",
          div(style="font-weight:700;font-size:1rem;","Lestrade Forms Mobile"),
          div(style="font-size:12px;color:var(--text3);margin-top:4px;",
              "Version 1.0 — Collecte terrain")
        )
      )
    )
  ),

  # ── Barre navigation bas ───────────────────────────────────────────────────
  div(class="mob-nav",
    tags$button(class="mob-nav-btn active", `data-tab`="accueil",
      div(class="nav-icon","🏠"), "Accueil"),
    tags$button(class="mob-nav-btn", `data-tab`="formulaire",
      div(class="nav-icon","📝"), "Saisie"),
    tags$button(class="mob-nav-btn", `data-tab`="reponses",
      div(class="nav-icon","📋"), "Réponses"),
    tags$button(class="mob-nav-btn", `data-tab`="scanner",
      div(class="nav-icon","📷"), "Scanner"),
    tags$button(class="mob-nav-btn", `data-tab`="parametres",
      div(class="nav-icon","⚙️"), "Paramètres")
  )
)

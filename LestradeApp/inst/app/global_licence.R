# ============================================================================
# global_licence.R — Gestion licence trial / premium
# Lestrade Forms v3
# ============================================================================

library(jsonlite)
library(httr)

# ── Constantes ────────────────────────────────────────────────────────────────

LICENCE_DIR  <- file.path(Sys.getenv("USERPROFILE", unset = path.expand("~")), ".lestrade")
LICENCE_FILE <- file.path(LICENCE_DIR, "licence.json")
TRIAL_DAYS   <- 30L

# ── Lecture / écriture locale ─────────────────────────────────────────────────

read_licence_local <- function() {
  if (!file.exists(LICENCE_FILE)) return(NULL)
  tryCatch(
    fromJSON(LICENCE_FILE, simplifyVector = TRUE),
    error = function(e) NULL
  )
}

write_licence_local <- function(data) {
  dir.create(LICENCE_DIR, showWarnings = FALSE, recursive = TRUE)
  write(toJSON(data, auto_unbox = TRUE, pretty = TRUE), LICENCE_FILE)
}

# ── Appels Apps Script ────────────────────────────────────────────────────────

# Enregistrer l'email sur le serveur (1er lancement)
licence_register_email <- function(email, panier_url) {
  tryCatch({
    resp <- post_apps_script(panier_url, list(
      action = "register_email",
      email  = tolower(trimws(email))
    ))
    if (!is.null(resp) && !is.null(resp$statut)) return(resp)
    NULL
  }, error = function(e) NULL)
}

# Vérifier le statut depuis le serveur
licence_check_server <- function(email, panier_url) {
  tryCatch({
    url  <- paste0(panier_url, "?action=check_licence&email=", URLencode(email, reserved = TRUE))
    resp <- GET(url, timeout(10))
    if (status_code(resp) != 200) return(NULL)
    parsed <- content(resp, as = "parsed", type = "application/json")
    if (!is.null(parsed$statut)) return(parsed)
    NULL
  }, error = function(e) NULL)
}

# Activer une clé licence sur le serveur
licence_activate_key <- function(email, cle, panier_url) {
  tryCatch({
    resp <- post_apps_script(panier_url, list(
      action = "activate_key",
      email  = tolower(trimws(email)),
      cle    = trimws(cle)
    ))
    if (!is.null(resp) && resp$status == "ok") return(resp)
    resp
  }, error = function(e) list(status = "error", message = conditionMessage(e)))
}

# Assigner une clé (admin)
licence_assign_key <- function(email, cle, panier_url) {
  tryCatch({
    resp <- post_apps_script(panier_url, list(
      action = "assign_key",
      email  = tolower(trimws(email)),
      cle    = trimws(cle)
    ))
    if (!is.null(resp)) return(resp)
    list(status = "error", message = "Pas de réponse du serveur")
  }, error = function(e) list(status = "error", message = conditionMessage(e)))
}

# ── POST Apps Script avec gestion redirect 302 ────────────────────────────────

post_apps_script <- function(url, body_list) {
  body_json <- toJSON(body_list, auto_unbox = TRUE)

  # Étape 1 : POST sans suivre le redirect
  resp1 <- POST(
    url,
    add_headers("Content-Type" = "application/json"),
    body      = body_json,
    encode    = "raw",
    config(followlocation = 0L),
    timeout(15)
  )

  # Étape 2 : suivre le redirect en GET si 302
  final_url <- url
  if (status_code(resp1) %in% c(301L, 302L)) {
    final_url <- headers(resp1)[["location"]]
    if (is.null(final_url) || final_url == "") final_url <- url
  }

  resp2 <- GET(final_url, timeout(20))
  if (status_code(resp2) != 200) return(NULL)

  body_str <- content(resp2, as = "text", encoding = "UTF-8")
  if (!startsWith(trimws(body_str), "{")) return(NULL)

  tryCatch(
    fromJSON(body_str, simplifyVector = TRUE),
    error = function(e) NULL
  )
}

# ── Logique principale : vérifier la licence au démarrage ─────────────────────

# Retourne une liste avec :
#   $statut        : "premium" | "trial" | "expire" | "offline" | "inconnu"
#   $email         : adresse email
#   $jours_restants: nombre de jours restants (trial)
#   $message       : message lisible
verifier_licence <- function(panier_url = NULL) {

  local <- read_licence_local()

  # Pas de licence locale → besoin d'enregistrement
  if (is.null(local) || is.null(local$email) || local$email == "") {
    return(list(statut = "inconnu", email = "", jours_restants = 0,
                message = "Aucune licence — veuillez saisir votre email"))
  }

  email <- local$email

  # Vérification serveur si panier configuré
  if (!is.null(panier_url) && nzchar(panier_url)) {
    server <- licence_check_server(email, panier_url)
    if (!is.null(server) && !is.null(server$statut)) {
      # Mettre à jour le cache local
      local$statut         <- server$statut
      local$jours_restants <- as.integer(server$jours_restants %||% 0)
      local$derniere_verif <- Sys.time() %>% format("%Y-%m-%dT%H:%M:%S")
      write_licence_local(local)
      return(list(
        statut         = server$statut,
        email          = email,
        jours_restants = as.integer(server$jours_restants %||% 0),
        message        = server$message %||% ""
      ))
    }
  }

  # Fallback : calcul local si pas de réseau
  if (!is.null(local$date_inscription)) {
    debut    <- tryCatch(as.POSIXct(local$date_inscription, tz = "UTC"), error = function(e) NULL)
    if (!is.null(debut)) {
      diff_j   <- as.integer(difftime(Sys.time(), debut, units = "days"))
      restants <- TRIAL_DAYS - diff_j
      statut   <- if (!is.null(local$statut) && local$statut == "premium") "premium" else
                  if (restants <= 0) "expire" else "trial"
      return(list(
        statut         = statut,
        email          = email,
        jours_restants = max(0L, restants),
        message        = switch(statut,
          premium = "Licence premium active (mode hors-ligne)",
          expire  = "Trial expiré — activez une licence",
          trial   = paste0("Trial actif — ", restants, " jour(s) restant(s) (hors-ligne)")
        )
      ))
    }
  }

  list(statut = "offline", email = email, jours_restants = 0,
       message = "Impossible de vérifier la licence (hors-ligne)")
}

# ── Enregistrement complet (1er lancement) ────────────────────────────────────

enregistrer_licence <- function(email, panier_url = NULL) {
  email <- tolower(trimws(email))
  if (!grepl("^[^@]+@[^@]+\\.[^@]+$", email)) {
    return(list(ok = FALSE, message = "Email invalide"))
  }

  now <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S")

  # Enregistrer sur le serveur
  server_resp <- NULL
  if (!is.null(panier_url) && nzchar(panier_url)) {
    server_resp <- licence_register_email(email, panier_url)
  }

  statut <- if (!is.null(server_resp) && !is.null(server_resp$statut))
    server_resp$statut else "trial"
  jours  <- if (!is.null(server_resp) && !is.null(server_resp$jours_restants))
    as.integer(server_resp$jours_restants) else TRIAL_DAYS

  # Sauvegarder localement
  write_licence_local(list(
    email            = email,
    date_inscription = now,
    statut           = statut,
    jours_restants   = jours,
    derniere_verif   = now
  ))

  list(ok = TRUE, statut = statut, jours_restants = jours,
       message = paste0("Bienvenue ! Trial de ", jours, " jours démarré."))
}

# ── Activation clé (utilisateur) ─────────────────────────────────────────────

activer_cle_licence <- function(cle, panier_url = NULL) {
  local <- read_licence_local()
  if (is.null(local) || is.null(local$email) || local$email == "") {
    return(list(ok = FALSE, message = "Aucun email enregistré. Relancez l'application."))
  }
  email <- local$email

  if (is.null(panier_url) || !nzchar(panier_url)) {
    return(list(ok = FALSE, message = "Panier non configuré — connexion internet requise."))
  }

  resp <- licence_activate_key(email, cle, panier_url)
  if (!is.null(resp) && !is.null(resp$status) && resp$status == "ok") {
    local$statut         <- "premium"
    local$jours_restants <- 9999L
    local$derniere_verif <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
    write_licence_local(local)
    return(list(ok = TRUE, message = "Licence premium activée !"))
  }

  list(ok = FALSE, message = resp$message %||% "Erreur lors de l'activation")
}

# ── Génération de clé (admin) ─────────────────────────────────────────────────

generer_cle_licence <- function(email) {
  email  <- tolower(trimws(email))
  seed   <- paste0(email, Sys.time(), sample(1000:9999, 1))
  hash   <- toupper(substr(digest::digest(seed, algo = "sha256"), 1, 16))
  # Format : LEST-XXXX-XXXX-XXXX-XXXX
  paste0("LEST-",
    substr(hash, 1,  4), "-",
    substr(hash, 5,  8), "-",
    substr(hash, 9,  12), "-",
    substr(hash, 13, 16))
}

# ============================================================================
# plumber.R — API REST Lestrade Forms
# Sert les questionnaires et réponses à l'app Flutter (réseau local)
# Démarrer avec : source("run_api.R")
# ============================================================================

library(plumber)

# global_api.R = version minimale (sans ggplot2/plotly qui crashent le subprocess)
# LESTRADE_DB_PATH est passé via Sys.setenv() dans app_final.R avant ce source()
source("global_api.R")
init_db()

# ============================================================================
# CORS — indispensable pour Flutter en mode debug (emulator = localhost)
# ============================================================================
#* @filter cors
function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
  res$setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization")
  if (req$REQUEST_METHOD == "OPTIONS") {
    res$status <- 200
    return(list())
  }
  plumber::forward()
}

# ============================================================================
# HEALTH
# ============================================================================

#* Vérifie que l'API est vivante
#* @get /health
#* @serializer json
function() {
  list(
    status  = jsonlite::unbox("ok"),
    version = jsonlite::unbox("1.0"),
    db      = jsonlite::unbox(file.exists(DB_PATH)),
    ts      = jsonlite::unbox(format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  )
}

# ============================================================================
# QUESTIONNAIRES
# ============================================================================

#* Liste tous les questionnaires
#* @get /questionnaires
#* @serializer json
function() {
  tryCatch({
    df <- get_all_questionnaires()
    if (!is.data.frame(df) || nrow(df) == 0) return(list())
    # Ajouter compteurs sections/questions
    df$nb_sections  <- vapply(df$id, count_sections_by_questionnaire,  integer(1))
    df$nb_questions <- vapply(df$id, count_questions_by_questionnaire, integer(1))
    # Convertir en liste de lignes (scalaires JSON, pas vecteurs R)
    lapply(seq_len(nrow(df)), function(i) row_to_list(df, i))
  }, error = function(e) {
    list(error = conditionMessage(e))
  })
}

# Convertit un data.frame en liste de lignes JSON (scalaires, pas vecteurs R)
# Sans unbox, plumber sérialise chaque champ comme [valeur] au lieu de valeur
row_to_list <- function(df, i) {
  row <- as.list(df[i, , drop = FALSE])
  lapply(row, function(v) {
    if (is.null(v) || (length(v) == 1 && is.na(v))) return(NULL)
    if (length(v) == 1) jsonlite::unbox(v) else v
  })
}

df_to_rows <- function(df) {
  if (!is.data.frame(df) || nrow(df) == 0) return(list())
  lapply(seq_len(nrow(df)), function(i) row_to_list(df, i))
}

#* Récupère un questionnaire complet (infos + sections + questions)
#* @param id ID du questionnaire
#* @get /questionnaires/<id>
#* @serializer json
function(id) {
  tryCatch({
    qid <- as.integer(id)
    if (is.na(qid)) stop("id invalide")
    full <- get_questionnaire_full(qid)
    if (is.null(full)) {
      list(error = "questionnaire non trouvé")
    } else {
      # Sérialiser chaque data.frame en liste de lignes
      list(
        questionnaire = if (is.data.frame(full$questionnaire)) row_to_list(full$questionnaire, 1) else full$questionnaire,
        sections      = df_to_rows(full$sections),
        questions     = df_to_rows(full$questions)
      )
    }
  }, error = function(e) {
    list(error = conditionMessage(e))
  })
}

#* Récupère questionnaire par UID (ex: LEST-XXXX-XXXX) — cherche dans la DB locale
#* @param uid UID du questionnaire
#* @get /questionnaires/uid/<uid>
#* @serializer json
function(uid) {
  tryCatch({
    quests <- get_all_questionnaires()
    if (!is.data.frame(quests) || nrow(quests) == 0) {
      return(list(error = paste("UID", uid, "introuvable")))
    }
    # Générer l'UID de chaque questionnaire local et chercher la correspondance
    # generate_quest_uid est défini dans global_final.R (sourcé ci-dessus)
    found_id <- NULL
    for (i in seq_len(nrow(quests))) {
      q_uid <- generate_quest_uid(quests$id[i], quests$nom[i])
      if (q_uid == uid) { found_id <- quests$id[i]; break }
    }
    if (is.null(found_id)) return(list(error = paste("UID", uid, "introuvable")))

    full <- get_questionnaire_full(found_id)
    if (is.null(full)) return(list(error = "questionnaire non trouvé"))

    list(
      questionnaire = if (is.data.frame(full$questionnaire)) as.list(full$questionnaire[1, , drop = FALSE]) else full$questionnaire,
      sections      = df_to_rows(full$sections),
      questions     = df_to_rows(full$questions)
    )
  }, error = function(e) {
    list(error = conditionMessage(e))
  })
}

# ============================================================================
# RÉPONSES
# ============================================================================

#* Liste les réponses d'un questionnaire
#* @param quest_id ID du questionnaire
#* @get /reponses/<quest_id>
#* @serializer json
function(quest_id) {
  tryCatch({
    qid <- as.integer(quest_id)
    if (is.na(qid)) stop("quest_id invalide")
    get_reponses_by_questionnaire(qid)
  }, error = function(e) {
    list(error = conditionMessage(e))
  })
}

#* Soumet une ou plusieurs réponses (JSON body)
#* Body attendu : { "quest_id": 1, "reponses_full": [ { "uuid":"...", "horodateur":"...", "donnees_json":"{...}" } ] }
#* @post /reponses
#* @serializer json
function(req) {
  tryCatch({
    # Parser le corps brut avec simplifyVector=FALSE → toujours des listes, jamais des data.frames
    raw_body <- rawToChar(req$bodyRaw %||% charToRaw(req$postBody %||% "{}"))
    body <- fromJSON(raw_body, simplifyVector = FALSE)

    qid <- as.integer(body$quest_id)
    if (is.na(qid)) stop("quest_id manquant ou invalide")

    norm_horo <- function(h) trimws(gsub("T", " ", as.character(h %||% "")))

    reps_full <- body$reponses_full
    if (!is.null(reps_full) && length(reps_full) > 0) {
      con <- dbConnect(SQLite(), DB_PATH)

      # Migration uuid si absente
      cols <- dbGetQuery(con, "PRAGMA table_info(reponses)")$name
      if (!"uuid" %in% cols)
        dbExecute(con, "ALTER TABLE reponses ADD COLUMN uuid TEXT")

      existing_uuids <- dbGetQuery(con,
        "SELECT uuid FROM reponses WHERE questionnaire_id=? AND uuid IS NOT NULL",
        list(qid))$uuid

      n_saved <- 0L
      for (rep in reps_full) {
        uuid     <- trimws(as.character(rep$uuid %||% ""))
        h        <- norm_horo(rep$horodateur)
        json_str <- as.character(rep$donnees_json %||% "{}")
        if (uuid != "" && uuid %in% existing_uuids) next
        tryCatch(fromJSON(json_str), error = function(e) stop(paste("JSON invalide:", e$message)))
        dbExecute(con,
          "INSERT INTO reponses (questionnaire_id, horodateur, donnees_json, uuid) VALUES (?,?,?,?)",
          list(qid, h, json_str, if (uuid != "") uuid else NA_character_))
        existing_uuids <- c(existing_uuids, uuid)
        n_saved <- n_saved + 1L
      }
      dbDisconnect(con)
      return(list(status = "ok", saved = n_saved))
    }

    stop("reponses_full requis")
  }, error = function(e) {
    list(error = conditionMessage(e))
  })
}

#* Réponses au format large (colonnes = questions, 1 ligne = 1 réponse)
#* @param quest_id ID du questionnaire
#* @get /reponses/<quest_id>/wide
#* @serializer json
function(quest_id) {
  tryCatch({
    qid <- as.integer(quest_id)
    if (is.na(qid)) stop("quest_id invalide")
    get_reponses_wide(qid)
  }, error = function(e) {
    list(error = conditionMessage(e))
  })
}

# ============================================================================
# SYNC DRIVE — déclenché par Flutter pour pousser un questionnaire sur Drive
# ============================================================================

#* Publie un questionnaire sur Drive
#* @param quest_id ID du questionnaire à publier
#* @post /sync-drive/<quest_id>
#* @serializer json
function(quest_id) {
  tryCatch({
    if (!requireNamespace("googledrive", quietly = TRUE)) {
      return(list(error = "googledrive non disponible sur ce PC"))
    }
    qid  <- as.integer(quest_id)
    full <- get_questionnaire_full(qid)
    if (is.null(full)) stop(paste("questionnaire", qid, "introuvable"))

    # upload_quest_to_drive est définie dans server_final.R — on la redéfinit ici
    # (copie légère, sans dépendance à Shiny)
    uid <- sprintf("LEST-%s-%s",
                   toupper(stringi::stri_rand_strings(1, 4, "[A-Z0-9]")),
                   toupper(stringi::stri_rand_strings(1, 4, "[A-Z0-9]")))
    nom <- full$questionnaire$nom[1]
    payload <- list(uid = uid, quest = full)
    tmp <- tempfile(fileext = ".json")
    writeLines(toJSON(payload, auto_unbox = TRUE, pretty = FALSE), tmp)
    fname <- paste0("lestrade_quest_", uid, ".json")
    googledrive::drive_upload(tmp, name = fname, overwrite = TRUE)
    unlink(tmp)

    list(status = "ok", uid = uid, nom = nom)
  }, error = function(e) {
    list(error = conditionMessage(e))
  })
}

#* Liste les questionnaires disponibles sur Drive
#* @get /drive/questionnaires
#* @serializer json
function() {
  tryCatch({
    if (!requireNamespace("googledrive", quietly = TRUE)) {
      return(list(error = "googledrive non disponible"))
    }
    library(googledrive)
    files <- drive_find(pattern = "lestrade_quest_", n_max = 100)
    if (nrow(files) == 0) return(list())

    results <- lapply(seq_len(nrow(files)), function(i) {
      f   <- files[i, ]
      uid <- sub("lestrade_quest_", "", sub("\\.json$", "", f$name))
      list(uid = uid, drive_name = f$name, drive_id = f$id)
    })
    results
  }, error = function(e) {
    list(error = conditionMessage(e))
  })
}

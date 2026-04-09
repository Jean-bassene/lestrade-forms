# ============================================================================
# global_api.R — Version MINIMALE pour l'API plumber
# Charge uniquement les packages et fonctions nécessaires à l'API REST
# Pas de ggplot2, plotly, shiny — évite les crashs dans le sous-processus
# ============================================================================

library(RSQLite)
library(DBI)
library(dplyr)
library(jsonlite)
library(digest)

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

DB_PATH <- Sys.getenv("LESTRADE_DB_PATH", unset = "questionnaires.db")

# ── DB INIT ─────────────────────────────────────────────────────────────────
init_db <- function() {
  con <- dbConnect(SQLite(), DB_PATH)
  dbExecute(con, "PRAGMA foreign_keys = ON")
  dbExecute(con, "CREATE TABLE IF NOT EXISTS questionnaires (
    id INTEGER PRIMARY KEY AUTOINCREMENT, nom TEXT NOT NULL,
    description TEXT, date_creation DATETIME DEFAULT CURRENT_TIMESTAMP)")
  dbExecute(con, "CREATE TABLE IF NOT EXISTS sections (
    id INTEGER PRIMARY KEY AUTOINCREMENT, questionnaire_id INTEGER NOT NULL,
    nom TEXT NOT NULL, ordre INTEGER DEFAULT 1,
    FOREIGN KEY (questionnaire_id) REFERENCES questionnaires(id) ON DELETE CASCADE)")
  dbExecute(con, "CREATE TABLE IF NOT EXISTS questions (
    id INTEGER PRIMARY KEY AUTOINCREMENT, section_id INTEGER NOT NULL,
    type TEXT NOT NULL, texte TEXT NOT NULL, options TEXT,
    role_analytique TEXT, obligatoire INTEGER DEFAULT 0, ordre INTEGER DEFAULT 1,
    FOREIGN KEY (section_id) REFERENCES sections(id) ON DELETE CASCADE)")
  cols <- dbGetQuery(con, "PRAGMA table_info(questions)")
  if (!"role_analytique" %in% cols$name)
    dbExecute(con, "ALTER TABLE questions ADD COLUMN role_analytique TEXT")
  dbExecute(con, "CREATE TABLE IF NOT EXISTS reponses (
    id INTEGER PRIMARY KEY AUTOINCREMENT, questionnaire_id INTEGER NOT NULL,
    horodateur DATETIME DEFAULT CURRENT_TIMESTAMP, donnees_json TEXT NOT NULL,
    FOREIGN KEY (questionnaire_id) REFERENCES questionnaires(id) ON DELETE CASCADE)")
  cols2 <- dbGetQuery(con, "PRAGMA table_info(reponses)")$name
  if (!"uuid" %in% cols2)
    dbExecute(con, "ALTER TABLE reponses ADD COLUMN uuid TEXT")
  dbDisconnect(con)
}

# ── QUESTIONNAIRES ───────────────────────────────────────────────────────────
get_all_questionnaires <- function() {
  con <- dbConnect(SQLite(), DB_PATH)
  res <- dbGetQuery(con, "SELECT id,nom,description,date_creation FROM questionnaires ORDER BY date_creation DESC")
  dbDisconnect(con); res
}
get_questionnaire_by_id <- function(qid) {
  con <- dbConnect(SQLite(), DB_PATH)
  res <- dbGetQuery(con, "SELECT id,nom,description,date_creation FROM questionnaires WHERE id=?", list(qid))
  dbDisconnect(con)
  if (nrow(res) > 0) res[1, , drop = FALSE] else NULL
}
get_sections_by_questionnaire <- function(qid) {
  con <- dbConnect(SQLite(), DB_PATH)
  res <- dbGetQuery(con, "SELECT id,questionnaire_id,nom,ordre FROM sections WHERE questionnaire_id=? ORDER BY ordre", list(qid))
  dbDisconnect(con); res
}
get_all_questions_by_questionnaire <- function(qid) {
  con <- dbConnect(SQLite(), DB_PATH)
  res <- dbGetQuery(con, "
    SELECT q.id, q.section_id, q.type, q.texte, q.options,
           q.role_analytique, q.obligatoire, q.ordre,
           s.questionnaire_id, s.nom as section_nom
    FROM questions q JOIN sections s ON q.section_id = s.id
    WHERE s.questionnaire_id = ? ORDER BY s.ordre, q.ordre", list(qid))
  dbDisconnect(con); res
}
get_questionnaire_full <- function(qid) {
  q <- get_questionnaire_by_id(qid)
  if (is.null(q)) return(NULL)
  list(questionnaire = q,
       sections      = get_sections_by_questionnaire(qid),
       questions     = get_all_questions_by_questionnaire(qid))
}
count_sections_by_questionnaire <- function(qid) {
  con <- dbConnect(SQLite(), DB_PATH)
  r <- dbGetQuery(con, "SELECT COUNT(*) as n FROM sections WHERE questionnaire_id=?", list(qid))$n
  dbDisconnect(con); r
}
count_questions_by_questionnaire <- function(qid) {
  con <- dbConnect(SQLite(), DB_PATH)
  r <- dbGetQuery(con, "SELECT COUNT(q.id) as n FROM questions q JOIN sections s ON q.section_id=s.id WHERE s.questionnaire_id=?", list(qid))$n
  dbDisconnect(con); r
}

# ── RÉPONSES ─────────────────────────────────────────────────────────────────
get_reponses_by_questionnaire <- function(qid) {
  con <- dbConnect(SQLite(), DB_PATH)
  res <- dbGetQuery(con, "SELECT id,questionnaire_id,horodateur,donnees_json,uuid FROM reponses WHERE questionnaire_id=? ORDER BY horodateur DESC", list(qid))
  dbDisconnect(con); res
}
get_reponses_wide <- function(qid) {
  reponses  <- get_reponses_by_questionnaire(qid)
  questions <- get_all_questions_by_questionnaire(qid)
  if (nrow(reponses) == 0 || nrow(questions) == 0) return(data.frame())
  q_ids   <- as.character(questions$id)
  col_ids <- paste0("q_", q_ids)
  rows <- lapply(seq_len(nrow(reponses)), function(i) {
    p   <- tryCatch(fromJSON(reponses$donnees_json[i], simplifyVector = FALSE), error = function(e) list())
    row <- list(reponse_id = reponses$id[i], horodateur = reponses$horodateur[i])
    for (k in seq_along(q_ids)) {
      v <- p[[q_ids[k]]]
      row[[col_ids[k]]] <- if (is.null(v) || length(v) == 0) "" else paste(as.character(unlist(v)), collapse = " | ")
    }
    row
  })
  bind_rows(rows)
}

# ── UID ──────────────────────────────────────────────────────────────────────
generate_quest_uid <- function(quest_id, quest_nom) {
  hash <- toupper(substr(digest::digest(quest_nom, algo = "crc32"), 1, 4))
  sprintf("LEST-%04d-%s", as.integer(quest_id), hash)
}

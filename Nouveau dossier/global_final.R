# ============================================================================
# global_final.R  - v2
# Centralise toutes les fonctions utilitaires + DB + analytics helpers
# ============================================================================

library(RSQLite); library(DBI); library(dplyr); library(jsonlite)
library(lubridate); library(ggplot2); library(plotly); library(tidyr)
library(RColorBrewer); library(stringi); library(readxl); library(readr)

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

DB_PATH <- "questionnaires.db"

QUESTION_TYPES <- c(
  "Texte court" = "text", "Texte long" = "textarea",
  "Choix unique" = "radio", "Choix multiples" = "checkbox",
  "Echelle Likert" = "likert", "Dropdown" = "dropdown",
  "Email" = "email", "Telephone" = "phone", "Date" = "date"
)

COULEURS_PALETTE <- c(
  "#1f77b4","#ff7f0e","#2ca02c","#d62728","#9467bd",
  "#8c564b","#e377c2","#7f7f7f","#bcbd22","#17becf"
)

# ============================================================================
# DB — INIT
# ============================================================================
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
  dbDisconnect(con)
}

# ============================================================================
# DB — QUESTIONNAIRES
# ============================================================================
get_all_questionnaires <- function() {
  con <- dbConnect(SQLite(), DB_PATH)
  res <- dbGetQuery(con, "SELECT id,nom,description,date_creation FROM questionnaires ORDER BY date_creation DESC")
  dbDisconnect(con); res
}
get_questionnaire_by_id <- function(qid) {
  con <- dbConnect(SQLite(), DB_PATH)
  res <- dbGetQuery(con, "SELECT id,nom,description,date_creation FROM questionnaires WHERE id=?", list(qid))
  dbDisconnect(con); if (nrow(res) > 0) res[1,] else NULL
}
get_questionnaire_full <- function(qid) {
  q <- get_questionnaire_by_id(qid)
  if (is.null(q)) return(NULL)
  list(questionnaire = q,
       sections = get_sections_by_questionnaire(qid),
       questions = get_all_questions_by_questionnaire(qid))
}
create_questionnaire <- function(nom, description) {
  con <- dbConnect(SQLite(), DB_PATH)
  dbExecute(con, "INSERT INTO questionnaires (nom,description) VALUES (?,?)", list(nom, description))
  id <- dbGetQuery(con, "SELECT last_insert_rowid() as id")$id[1]
  dbDisconnect(con); as.integer(id)
}
delete_questionnaire <- function(qid) {
  con <- dbConnect(SQLite(), DB_PATH)
  dbExecute(con, "DELETE FROM questionnaires WHERE id=?", list(qid))
  dbDisconnect(con)
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

# ============================================================================
# DB — SECTIONS
# ============================================================================
get_sections_by_questionnaire <- function(qid) {
  con <- dbConnect(SQLite(), DB_PATH)
  res <- dbGetQuery(con, "SELECT id,questionnaire_id,nom,ordre FROM sections WHERE questionnaire_id=? ORDER BY ordre", list(qid))
  dbDisconnect(con); res
}
create_section <- function(qid, nom) {
  con <- dbConnect(SQLite(), DB_PATH)
  ordre <- dbGetQuery(con, "SELECT COALESCE(MAX(ordre),0)+1 as o FROM sections WHERE questionnaire_id=?", list(qid))$o
  dbExecute(con, "INSERT INTO sections (questionnaire_id,nom,ordre) VALUES (?,?,?)", list(as.integer(qid), nom, ordre))
  id <- dbGetQuery(con, "SELECT last_insert_rowid() as id")$id[1]
  dbDisconnect(con); as.integer(id)
}
delete_section <- function(sid) {
  con <- dbConnect(SQLite(), DB_PATH)
  dbExecute(con, "DELETE FROM sections WHERE id=?", list(sid))
  dbDisconnect(con)
}

# ============================================================================
# DB — QUESTIONS
# ============================================================================
get_questions_by_section <- function(sid) {
  con <- dbConnect(SQLite(), DB_PATH)
  res <- dbGetQuery(con, "SELECT id,section_id,type,texte,options,role_analytique,obligatoire,ordre FROM questions WHERE section_id=? ORDER BY ordre", list(sid))
  dbDisconnect(con); res
}
get_all_questions_by_questionnaire <- function(qid) {
  con <- dbConnect(SQLite(), DB_PATH)
  res <- dbGetQuery(con, "
    SELECT q.id,q.section_id,q.type,q.texte,q.options,q.role_analytique,q.obligatoire,q.ordre,
           s.questionnaire_id,s.nom as section_nom
    FROM questions q JOIN sections s ON q.section_id=s.id
    WHERE s.questionnaire_id=? ORDER BY s.ordre,q.ordre", list(qid))
  dbDisconnect(con); res
}
create_question <- function(sid, type, texte, options = NULL, obligatoire = FALSE, role_analytique = NULL) {
  con <- dbConnect(SQLite(), DB_PATH)
  tryCatch({
    ordre <- dbGetQuery(con, "SELECT COALESCE(MAX(ordre),0)+1 as o FROM questions WHERE section_id=?", list(sid))$o
    opts_json <- if (!is.null(options) && length(options) > 0) toJSON(options, auto_unbox = TRUE) else "{}"
    dbExecute(con, "INSERT INTO questions (section_id,type,texte,options,role_analytique,obligatoire,ordre) VALUES (?,?,?,?,?,?,?)",
              list(as.integer(sid), type, texte, as.character(opts_json),
                   as.character(role_analytique %||% NA_character_), as.integer(obligatoire), as.integer(ordre)))
    id <- dbGetQuery(con, "SELECT last_insert_rowid() as id")$id[1]
    as.integer(id)
  }, finally = dbDisconnect(con))
}
delete_question <- function(qid) {
  con <- dbConnect(SQLite(), DB_PATH)
  dbExecute(con, "DELETE FROM questions WHERE id=?", list(qid))
  dbDisconnect(con)
}

# ============================================================================
# DB — REPONSES
# ============================================================================
get_reponses_by_questionnaire <- function(qid) {
  con <- dbConnect(SQLite(), DB_PATH)
  res <- dbGetQuery(con, "SELECT id,questionnaire_id,horodateur,donnees_json FROM reponses WHERE questionnaire_id=? ORDER BY horodateur DESC", list(qid))
  dbDisconnect(con); res
}
save_reponse <- function(qid, donnees_json) {
  con <- dbConnect(SQLite(), DB_PATH)
  dbExecute(con, "INSERT INTO reponses (questionnaire_id,donnees_json) VALUES (?,?)", list(as.integer(qid), donnees_json))
  dbDisconnect(con)
}
update_reponse <- function(rid, donnees_json) {
  con <- dbConnect(SQLite(), DB_PATH)
  dbExecute(con, "UPDATE reponses SET donnees_json=? WHERE id=?", list(donnees_json, as.integer(rid)))
  dbDisconnect(con)
}
delete_reponse <- function(rid) {
  con <- dbConnect(SQLite(), DB_PATH)
  dbExecute(con, "DELETE FROM reponses WHERE id=?", list(rid))
  dbDisconnect(con)
}

# ============================================================================
# HELPERS — valeurs
# ============================================================================
is_empty_response_value <- function(v) {
  if (is.null(v) || length(v) == 0) return(TRUE)
  if (is.list(v)) return(all(vapply(v, is_empty_response_value, logical(1))))
  if (all(is.na(v))) return(TRUE)
  if (is.character(v)) return(all(trimws(v) == ""))
  FALSE
}
format_response_value <- function(v) {
  if (is_empty_response_value(v)) return("")
  if (inherits(v, "Date")) return(as.character(v))
  if (length(v) > 1) return(paste(as.character(v), collapse = " | "))
  as.character(v)
}

# ============================================================================
# PARSING JSON EN UNE SEULE PASSE — PERFORMANCE FIX
# ============================================================================
parse_reponses_to_wide <- function(qid) {
  reponses  <- get_reponses_by_questionnaire(qid)
  questions <- get_all_questions_by_questionnaire(qid)
  if (nrow(reponses) == 0 || nrow(questions) == 0) return(data.frame())

  parsed_list <- lapply(reponses$donnees_json, function(j)
    tryCatch(fromJSON(j, simplifyVector = FALSE), error = function(e) list()))

  q_ids   <- as.character(questions$id)
  col_ids <- paste0("q_", q_ids)

  rows <- lapply(seq_len(nrow(reponses)), function(i) {
    p <- parsed_list[[i]]
    row <- list(reponse_id = reponses$id[i], horodateur = reponses$horodateur[i])
    for (k in seq_along(q_ids)) row[[col_ids[k]]] <- format_response_value(p[[q_ids[k]]])
    row
  })
  bind_rows(rows)
}

get_reponses_wide <- function(qid) {
  reponses  <- get_reponses_by_questionnaire(qid)
  questions <- get_all_questions_by_questionnaire(qid)
  if (nrow(reponses) == 0 || nrow(questions) == 0) return(data.frame())
  wide <- parse_reponses_to_wide(qid)
  # Renommer les colonnes avec les libellés complets
  q_ids <- as.character(questions$id)
  col_ids <- paste0("q_", q_ids)
  labels  <- paste0(questions$section_nom, " / ", questions$texte)
  for (k in seq_along(col_ids)) {
    if (col_ids[k] %in% names(wide)) names(wide)[names(wide) == col_ids[k]] <- labels[k]
  }
  wide
}

# ============================================================================
# ANALYTICS — taux & stats (performance-fixées)
# ============================================================================
taux_reponse_par_question <- function(qid) {
  wide <- parse_reponses_to_wide(qid)
  qs   <- get_all_questions_by_questionnaire(qid)
  if (nrow(wide) == 0 || nrow(qs) == 0)
    return(data.frame(question = character(0), taux = numeric(0)))
  total <- nrow(wide)
  bind_rows(lapply(seq_len(nrow(qs)), function(i) {
    col <- paste0("q_", qs$id[i])
    n <- if (col %in% names(wide)) sum(!is.na(wide[[col]]) & trimws(as.character(wide[[col]])) != "", na.rm = TRUE) else 0L
    data.frame(question = paste0(qs$section_nom[i], " / ", qs$texte[i]),
               taux = round(n / total * 100, 2))
  }))
}

taux_abandon <- function(qid) {
  wide <- parse_reponses_to_wide(qid)
  qs   <- get_all_questions_by_questionnaire(qid)
  if (nrow(wide) == 0 || nrow(qs) == 0) return(NULL)
  total_q <- nrow(qs)
  q_cols  <- intersect(paste0("q_", qs$id), names(wide))
  bind_rows(lapply(seq_len(nrow(wide)), function(i) {
    n_ans <- sum(vapply(q_cols, function(col) {
      v <- wide[[col]][i]; !is.na(v) && nchar(trimws(as.character(v))) > 0
    }, logical(1)))
    data.frame(reponse_id = wide$reponse_id[i], answered = n_ans,
               total = total_q, completion = round(n_ans / total_q * 100, 2))
  }))
}

timeline_reponses <- function(qid) {
  r <- get_reponses_by_questionnaire(qid)
  if (nrow(r) == 0) return(NULL)
  r$date <- as.Date(r$horodateur)
  r %>% group_by(date) %>% summarise(count = n(), .groups = "drop") %>% arrange(date)
}

# ============================================================================
# ANALYTICS — utilities (déplacées depuis server.R)
# ============================================================================
score_value_generic <- function(value) {
  if (is_empty_response_value(value)) return(NA_real_)
  val <- trimws(as.character(value)[1])
  maps <- list(
    c("Oui"=1, "Non"=0),
    c("Pas d'accord"=0,"Plutot pas"=0.25,"Neutre"=0.5,"Plutot d'accord"=0.75,"Tout a fait"=1),
    c("Pas du tout"=0,"Peu"=0.33,"Moyennement"=0.66,"Beaucoup"=1),
    c("Pas satisfait"=0,"Moyennement satisfait"=0.5,"Satisfait"=1),
    c("Non"=0,"Partiellement"=0.5,"Oui"=1)
  )
  for (m in maps) if (val %in% names(m)) return(unname(m[val]))
  NA_real_
}

detect_plot_variable_kind <- function(values, question_type = NULL) {
  vc <- trimws(as.character(values))
  vc <- vc[!is.na(vc) & vc != ""]
  if (length(vc) == 0) return("categorical")
  if (!is.null(question_type) && question_type %in% c("radio","dropdown","likert","checkbox")) return("categorical")
  if (all(!is.na(suppressWarnings(as.numeric(vc))))) return("numeric")
  "categorical"
}

truncate_label <- function(x, max_chars = 36) {
  x <- as.character(x)
  too_long <- nchar(x) > max_chars
  x[too_long] <- paste0(substr(x[too_long], 1, max_chars - 3), "...")
  x
}

get_value_levels <- function(values) {
  v <- trimws(as.character(values))
  unique(v[!is.na(v) & v != ""])
}

make_meta_choices <- function(meta_df) {
  if (is.null(meta_df) || nrow(meta_df) == 0) return(list())
  setNames(as.list(meta_df$col_id), meta_df$label)
}

get_meta_label <- function(meta, col_id) {
  if (is.null(col_id) || length(col_id) == 0 || is.na(col_id) || col_id == "") return("")
  if (identical(col_id, "score_analytique")) return("Score analytique")
  if (is.null(meta) || nrow(meta) == 0) return(col_id)
  hit <- meta[meta$col_id == col_id, , drop = FALSE]
  if (nrow(hit) == 0) col_id else hit$label[1]
}

make_plot_catalog <- function(bundle) {
  df   <- bundle$data
  meta <- bundle$meta
  if (nrow(df) == 0 || is.null(meta) || nrow(meta) == 0)
    return(data.frame(id=character(0), label=character(0), kind=character(0)))
  catalog <- data.frame(
    id    = meta$col_id,
    label = meta$label,
    kind  = vapply(seq_len(nrow(meta)), function(i) {
      col <- meta$col_id[i]
      if (!(col %in% names(df))) return("categorical")
      detect_plot_variable_kind(df[[col]], meta$type[i])
    }, character(1)),
    stringsAsFactors = FALSE
  )
  if ("score_analytique" %in% names(df) && any(!is.na(df$score_analytique)))
    catalog <- rbind(data.frame(id="score_analytique",label="Score analytique",kind="numeric",stringsAsFactors=FALSE), catalog)
  catalog
}

completion_from_bundle <- function(df, meta) {
  if (is.null(df) || nrow(df) == 0 || is.null(meta) || nrow(meta) == 0)
    return(data.frame(section=character(0), taux=numeric(0)))
  sections <- unique(meta$section_nom)
  bind_rows(lapply(sections, function(sec) {
    cols <- intersect(meta$col_id[meta$section_nom == sec], names(df))
    if (length(cols) == 0) return(data.frame(section=sec, taux=0))
    answered <- sum(vapply(df[cols], function(col) {
      v <- trimws(as.character(col))
      sum(!is.na(v) & v != "")
    }, integer(1)))
    data.frame(section=sec, taux=round(answered / (nrow(df) * length(cols)) * 100, 2))
  }))
}

# ============================================================================
# ANALYTICS — préparation bundle
# ============================================================================
sanitize_external_names <- function(x) {
  x <- trimws(as.character(x))
  x[x == ""] <- paste0("col_", seq_along(x))[x == ""]
  make.names(x, unique = TRUE)
}

normalize_external_values <- function(df) {
  na_tokens <- c("","na","n/a","n.a","nan","null","aucun","aucune","ns","nsp","ne sait pas","non applicable")
  for (col in names(df)) {
    if (inherits(df[[col]], c("POSIXct","POSIXt","Date"))) next
    vals <- trimws(as.character(df[[col]]))
    vals[is.na(vals)] <- NA_character_
    vals[stri_trans_general(tolower(vals),"Latin-ASCII") %in% na_tokens] <- NA_character_
    vals <- gsub("\\s+", " ", vals)
    vals <- gsub("^oui[[:space:]]*$", "Oui", vals, ignore.case=TRUE)
    vals <- gsub("^non[[:space:]]*$", "Non", vals, ignore.case=TRUE)
    vals <- gsub("^satisfait[e]?[[:space:]]*$", "Satisfait", vals, ignore.case=TRUE)
    vals <- gsub("^beaucoup[[:space:]]*$", "Beaucoup", vals, ignore.case=TRUE)
    vals <- gsub("^peu[[:space:]]*$", "Peu", vals, ignore.case=TRUE)
    vals <- gsub("^moyennement[[:space:]]*$", "Moyennement", vals, ignore.case=TRUE)
    df[[col]] <- vals
  }
  df
}

maybe_parse_french_numeric <- function(x) {
  vals <- trimws(as.character(x)); vals[vals==""] <- NA_character_
  if (all(is.na(vals))) return(x)
  cand <- gsub("\u00A0| ","",vals); cand <- gsub("%","",cand,fixed=TRUE)
  cand <- gsub("\\.","",cand); cand <- sub(",",".",cand,fixed=TRUE)
  nums <- suppressWarnings(as.numeric(cand))
  if (sum(!is.na(nums)) >= max(3, floor(sum(!is.na(vals))*0.8))) return(nums)
  x
}

prepare_external_dataframe <- function(df_in) {
  if (is.null(df_in) || nrow(df_in) == 0)
    return(list(data=data.frame(), original_names=character(0), clean_names=character(0)))
  df <- as.data.frame(df_in, stringsAsFactors=FALSE)
  original_names <- names(df)
  clean_names    <- sanitize_external_names(original_names)
  names(df) <- clean_names
  for (col in clean_names) {
    if (inherits(df[[col]], c("POSIXct","POSIXt","Date"))) next
    df[[col]] <- trimws(as.character(df[[col]]))
    df[[col]][df[[col]] == ""] <- NA_character_
  }
  df <- normalize_external_values(df)
  for (col in clean_names) {
    if (!inherits(df[[col]], c("POSIXct","POSIXt","Date")))
      df[[col]] <- maybe_parse_french_numeric(df[[col]])
  }
  list(data=df, original_names=original_names, clean_names=clean_names)
}

detect_multi_choice_column <- function(values) {
  vals <- trimws(as.character(values)); vals <- vals[!is.na(vals) & vals != ""]
  if (length(vals) == 0) return(FALSE)
  mean(grepl("\\s*[,;|/]\\s*", vals)) >= 0.15
}

detect_text_free_column <- function(values) {
  vals <- trimws(as.character(values)); vals <- vals[!is.na(vals) & vals != ""]
  if (length(vals) == 0) return(FALSE)
  mean(nchar(vals) > 80) >= 0.2 || (length(unique(vals)) > 20 && mean(nchar(vals)) > 30)
}

finalize_internal_meta <- function(df, meta) {
  if (is.null(df) || nrow(df) == 0 || is.null(meta) || nrow(meta) == 0) return(meta)
  meta$n_unique <- vapply(meta$col_id, function(col) {
    if (!(col %in% names(df))) return(0L); length(get_value_levels(df[[col]]))
  }, integer(1))
  meta$levels_json <- vapply(meta$col_id, function(col) {
    if (!(col %in% names(df))) return("[]")
    as.character(toJSON(get_value_levels(df[[col]]), auto_unbox=TRUE))
  }, character(1))
  scoreable <- vapply(meta$col_id, function(col) {
    if (!(col %in% names(df))) return(FALSE)
    levels <- get_value_levels(df[[col]])
    if (length(levels) == 0) return(FALSE)
    num_vals <- suppressWarnings(as.numeric(levels))
    if (all(!is.na(num_vals))) return(length(unique(num_vals)) > 1)
    any(!is.na(vapply(levels, score_value_generic, numeric(1))))
  }, logical(1))
  is_text_like <- meta$type %in% c("text","textarea","email","phone")
  role_vals <- if ("role_analytique" %in% names(meta)) as.character(meta$role_analytique) else rep(NA_character_, nrow(meta))
  meta$is_groupable <- ifelse(!is.na(role_vals) & role_vals != "", role_vals == "group",
    meta$n_unique > 1 & meta$n_unique <= 20 & !(is_text_like & meta$n_unique > 8))
  meta$is_indicator <- ifelse(!is.na(role_vals) & role_vals != "", role_vals == "indicator",
    meta$n_unique > 1 & scoreable)
  meta
}

prepare_analytics_bundle <- function(df, meta) {
  if (is.null(df) || nrow(df) == 0 || is.null(meta) || nrow(meta) == 0)
    return(list(data=data.frame(), meta=data.frame()))
  score_candidates <- intersect(meta$col_id[meta$is_indicator], names(df))
  if (length(score_candidates) > 0) {
    score_matrix <- sapply(score_candidates, function(col)
      vapply(df[[col]], score_value_generic, numeric(1)))
    if (is.null(dim(score_matrix))) score_matrix <- matrix(score_matrix, ncol=1)
    valid_count <- rowSums(!is.na(score_matrix))
    df$score_analytique <- ifelse(valid_count > 0,
      round(rowMeans(score_matrix, na.rm=TRUE) * 10, 2), NA_real_)
  } else {
    df$score_analytique <- NA_real_
  }
  list(data=df, meta=meta)
}

# ============================================================================
# ANALYTICS — bundle externe (auto-détection, sans config manuelle)
# ============================================================================
detect_csv_delim <- function(path) {
  lines <- tryCatch(readLines(path, n=5, warn=FALSE, encoding="UTF-8"), error=function(e) character(0))
  if (length(lines) == 0) lines <- tryCatch(readLines(path, n=5, warn=FALSE), error=function(e) character(0))
  if (length(lines) == 0) return(",")
  txt <- paste(lines, collapse="\n")
  counts <- c(";"=stri_count_fixed(txt,";"), ","=stri_count_fixed(txt,","), "\t"=stri_count_fixed(txt,"\t"))
  names(which.max(counts))
}

read_external_file <- function(file_path, sheet = NULL, has_header = TRUE) {
  ext <- tolower(tools::file_ext(file_path))
  if (ext %in% c("xlsx","xls")) {
    sh <- sheet %||% readxl::excel_sheets(file_path)[1]
    readxl::read_excel(file_path, sheet=sh, col_names=has_header)
  } else if (ext == "csv") {
    delim <- detect_csv_delim(file_path)
    readr::read_delim(file_path, delim=delim, show_col_types=FALSE,
      col_names=has_header,
      locale=readr::locale(encoding="UTF-8"),
      na=c("","NA","N/A","NULL","NS","NSP","Ne sait pas","Sans réponse"))
  } else {
    stop("Format non supporté : utilisez .xlsx, .xls ou .csv")
  }
}

build_ext_bundle_auto <- function(df_in) {
  if (is.null(df_in) || nrow(df_in) == 0) return(list(data=data.frame(), meta=data.frame()))
  prep <- prepare_external_dataframe(df_in)
  df   <- prep$data
  original_names <- prep$original_names
  clean_names    <- prep$clean_names

  # Détection colonne date
  date_col <- NULL
  for (col in clean_names) {
    if (inherits(df_in[[match(col, clean_names)]], c("POSIXct","POSIXt","Date"))) {
      date_col <- col; break
    }
  }
  if (!is.null(date_col)) {
    df$horodateur <- as.character(df[[date_col]])
    df$date <- suppressWarnings(as.Date(df[[date_col]]))
  }

  # Construction meta
  meta_rows <- lapply(seq_along(clean_names), function(i) {
    col  <- clean_names[i]
    vals <- df[[col]]
    kind <- if (!is.null(date_col) && col == date_col) "date"
            else detect_plot_variable_kind(vals)
    levels  <- get_value_levels(vals)
    n_uniq  <- length(levels)
    is_multi <- detect_multi_choice_column(vals)
    is_text  <- detect_text_free_column(vals)
    scoreable <- any(!is.na(vapply(levels, score_value_generic, numeric(1))))

    type <- if (kind == "date") "date"
            else if (is_text)  "textarea"
            else if (is_multi) "checkbox"
            else if (n_uniq <= 5) "radio"
            else "dropdown"

    data.frame(
      col_id     = col,
      label      = original_names[i],
      texte      = original_names[i],
      section_nom= assign_section_name(original_names[i], create_sections = TRUE, n_questions = length(clean_names)),
      type       = type,
      n_unique   = n_uniq,
      levels_json= as.character(toJSON(levels, auto_unbox=TRUE)),
      is_groupable = !is_text && !is_multi && kind != "numeric" && kind != "date" && n_uniq > 1 && n_uniq <= 20,
      is_indicator = n_uniq > 1 && scoreable && !is_text,
      role_analytique = NA_character_,
      stringsAsFactors = FALSE
    )
  })
  meta <- bind_rows(meta_rows)
  # Exclure colonne date de l'analyse
  if (!is.null(date_col)) meta <- meta[meta$col_id != date_col, , drop=FALSE]
  meta <- meta[meta$type != "date", , drop=FALSE]

  prepare_analytics_bundle(df, meta)
}

# ============================================================================
# ANALYTICS — profils & comparaisons (déplacées depuis server.R)
# ============================================================================
build_profile_bundle <- function(df, meta, group_col, max_groups = 6) {
  if (nrow(df)==0 || is.null(group_col) || group_col=="" || !(group_col %in% names(df)) || is.null(meta) || nrow(meta)==0) return(NULL)
  indicator_meta <- meta[meta$is_indicator, c("col_id","label","section_nom"), drop=FALSE]
  if (nrow(indicator_meta) == 0) return(NULL)
  groups <- names(head(sort(table(df[[group_col]][!is.na(df[[group_col]]) & df[[group_col]]!=""]), decreasing=TRUE), max_groups))
  if (length(groups) == 0) return(NULL)
  df_sub <- df[df[[group_col]] %in% groups & !is.na(df[[group_col]]) & df[[group_col]]!="", , drop=FALSE]

  summary_rows <- lapply(groups, function(g) {
    dg <- df_sub[df_sub[[group_col]]==g, , drop=FALSE]
    score_global <- if ("score_analytique" %in% names(dg) && !all(is.na(dg$score_analytique)))
      round(mean(dg$score_analytique, na.rm=TRUE), 2) else NA_real_
    item_scores <- bind_rows(lapply(seq_len(nrow(indicator_meta)), function(i) {
      vals <- vapply(dg[[indicator_meta$col_id[i]]], score_value_generic, numeric(1))
      vals <- vals[!is.na(vals)]
      if (length(vals)==0) return(NULL)
      data.frame(label=indicator_meta$label[i], section=indicator_meta$section_nom[i],
                 rate=round(mean(vals)*100,1), stringsAsFactors=FALSE)
    }))
    data.frame(Groupe=g, Effectif=nrow(dg), `Score global`=score_global,
      `Meilleur indicateur`=truncate_label(if(nrow(item_scores)>0) item_scores$label[which.max(item_scores$rate)] else NA_character_, 60),
      `Indicateur a renforcer`=truncate_label(if(nrow(item_scores)>0) item_scores$label[which.min(item_scores$rate)] else NA_character_, 60),
      stringsAsFactors=FALSE)
  })

  sections <- unique(indicator_meta$section_nom)
  section_rows <- lapply(groups, function(g) {
    dg <- df_sub[df_sub[[group_col]]==g, , drop=FALSE]
    vals <- lapply(sections, function(sec) {
      cols <- indicator_meta$col_id[indicator_meta$section_nom==sec]
      scores <- unlist(lapply(cols, function(col) {
        v <- vapply(dg[[col]], score_value_generic, numeric(1)); v[!is.na(v)]
      }))
      if (length(scores)==0) return(NA_real_); round(mean(scores)*100,1)
    })
    as.data.frame(c(list(Groupe=g), setNames(vals, sections)), stringsAsFactors=FALSE, check.names=FALSE)
  })

  detailed_df <- data.frame(Indicateur=indicator_meta$label, Section=indicator_meta$section_nom, stringsAsFactors=FALSE)
  for (g in groups) {
    dg <- df_sub[df_sub[[group_col]]==g, , drop=FALSE]
    detailed_df[[paste0(g," (%)")]] <- vapply(indicator_meta$col_id, function(col) {
      vals <- vapply(dg[[col]], score_value_generic, numeric(1)); vals <- vals[!is.na(vals)]
      if (length(vals)==0) return(NA_real_); round(mean(vals)*100,1)
    }, numeric(1))
  }
  list(groups=groups, summary=bind_rows(summary_rows), section=bind_rows(section_rows), detailed=detailed_df)
}

get_profile_plot_matrix <- function(profile, view_mode = "section", max_indicators = 8) {
  if (is.null(profile)) return(NULL)
  if (identical(view_mode,"indicator")) {
    df <- profile$detailed
    if (is.null(df) || nrow(df)==0) return(NULL)
    value_cols <- setdiff(names(df), c("Indicateur","Section"))
    if (length(value_cols)==0) return(NULL)
    mat <- as.matrix(df[,value_cols,drop=FALSE]); storage.mode(mat) <- "numeric"
    spreads <- apply(mat,1,function(x){x<-x[!is.na(x)]; if(length(x)==0) NA_real_ else max(x)-min(x)})
    keep <- head(order(spreads, decreasing=TRUE, na.last=NA), max_indicators)
    if (length(keep)==0) return(NULL)
    mat <- mat[keep,,drop=FALSE]
    rownames(mat) <- truncate_label(df$Indicateur[keep],30)
    colnames(mat) <- sub(" \\(%\\)$","",value_cols)
    return(t(mat))
  }
  df <- profile$section
  if (is.null(df) || nrow(df)==0) return(NULL)
  mat <- as.matrix(df[,setdiff(names(df),"Groupe"),drop=FALSE]); storage.mode(mat) <- "numeric"
  rownames(mat) <- df$Groupe; mat
}

build_section_scores_by_group <- function(df, meta, group_col, selected_sections=NULL, max_groups=6) {
  if (nrow(df)==0 || is.null(group_col) || group_col=="" || !(group_col %in% names(df)) || is.null(meta) || nrow(meta)==0) return(NULL)
  indic <- meta[meta$is_indicator, c("col_id","label","section_nom"),drop=FALSE]
  if (!is.null(selected_sections) && length(selected_sections)>0)
    indic <- indic[indic$section_nom %in% selected_sections,,drop=FALSE]
  if (nrow(indic)==0) return(NULL)
  groups <- names(head(sort(table(df[[group_col]][!is.na(df[[group_col]]) & df[[group_col]]!=""]),decreasing=TRUE), max_groups))
  if (length(groups)==0) return(NULL)
  sections <- unique(indic$section_nom)
  bind_rows(lapply(groups, function(g) {
    dg <- df[df[[group_col]]==g & !is.na(df[[group_col]]) & df[[group_col]]!="", ,drop=FALSE]
    vals <- lapply(sections, function(sec) {
      cols <- indic$col_id[indic$section_nom==sec]
      scores <- unlist(lapply(cols, function(col){
        x<-vapply(dg[[col]], score_value_generic, numeric(1)); x[!is.na(x)]
      }))
      if (length(scores)==0) NA_real_ else round(mean(scores)*100,1)
    })
    composite <- round(mean(unlist(vals), na.rm=TRUE),1)
    as.data.frame(c(list(Groupe=g, Effectif=nrow(dg), `Score composite (%)`=composite), setNames(vals,sections)),
                  stringsAsFactors=FALSE, check.names=FALSE)
  }))
}

build_indicator_score_matrix <- function(df, meta) {
  indic <- meta[meta$is_indicator, c("col_id","label"),drop=FALSE]
  if (nrow(indic)==0) return(NULL)
  cols <- intersect(indic$col_id, names(df))
  if (length(cols)==0) return(NULL)
  mat <- sapply(cols, function(col) vapply(df[[col]], score_value_generic, numeric(1)))
  if (is.null(dim(mat))) { mat <- matrix(mat,ncol=1); colnames(mat)<-cols }
  keep_rows <- complete.cases(mat) & apply(mat, 1, function(x) all(is.finite(x)))
  if (!any(keep_rows)) return(NULL)
  mat <- mat[keep_rows, , drop=FALSE]
  # isTRUE isole les NA : sd(x) sur 1 valeur → NA → NA>0 → NA → crash sans isTRUE
  keep_cols <- apply(mat, 2, function(x) {
    isTRUE(all(is.finite(x))) && isTRUE(stats::sd(x) > 0)
  })
  if (!any(keep_cols)) return(NULL)
  mat <- mat[, keep_cols, drop=FALSE]
  list(matrix=mat, labels=setNames(indic$label[match(colnames(mat),indic$col_id)],colnames(mat)), rows=which(keep_rows))
}

normalize_compare_label <- function(x) {
  x <- stri_trans_general(tolower(as.character(x)),"Latin-ASCII")
  trimws(gsub("\\s+"," ", gsub("[^a-z0-9]+"," ",x)))
}

# ============================================================================
# SAUVEGARDE OPTIONNELLE EN BASE depuis un bundle externe
# ============================================================================
save_external_as_questionnaire <- function(bundle, questionnaire_name, description="") {
  df   <- bundle$data
  meta <- bundle$meta
  if (is.null(df) || nrow(df)==0 || is.null(meta) || nrow(meta)==0) stop("Bundle vide")
  nom <- trimws(as.character(questionnaire_name))
  if (nom=="") stop("Nom obligatoire")

  con <- dbConnect(SQLite(), DB_PATH)
  on.exit(dbDisconnect(con), add=TRUE)

  DBI::dbWithTransaction(con, {
    dbExecute(con,"INSERT INTO questionnaires (nom,description,date_creation) VALUES (?,?,?)",
              list(nom, description, as.character(Sys.time())))
    quest_id <- dbGetQuery(con,"SELECT last_insert_rowid() as id")$id[1]

    section_names <- unique(meta$section_nom)
    section_map   <- setNames(integer(length(section_names)), section_names)
    for (i in seq_along(section_names)) {
      dbExecute(con,"INSERT INTO sections (questionnaire_id,nom,ordre) VALUES (?,?,?)",
                list(as.integer(quest_id), section_names[i], i))
      section_map[[section_names[i]]] <- dbGetQuery(con,"SELECT last_insert_rowid() as id")$id[1]
    }

    question_map <- setNames(integer(nrow(meta)), meta$col_id)
    for (i in seq_len(nrow(meta))) {
      m <- meta[i,]
      q_type  <- if (m$type %in% names(QUESTION_TYPES)) m$type else "text"
      opts_json <- if (q_type %in% c("radio","dropdown","checkbox","likert")) m$levels_json %||% "[]" else "{}"
      role <- if (isTRUE(m$is_indicator)) "indicator" else if (isTRUE(m$is_groupable)) "group" else "other"
      dbExecute(con,"INSERT INTO questions (section_id,type,texte,options,role_analytique,obligatoire,ordre) VALUES (?,?,?,?,?,0,?)",
                list(as.integer(section_map[[m$section_nom]]), q_type, m$label, opts_json, role, i))
      question_map[[m$col_id]] <- dbGetQuery(con,"SELECT last_insert_rowid() as id")$id[1]
    }

    horodateur_col <- if ("horodateur" %in% names(df)) "horodateur" else if ("date" %in% names(df)) "date" else NULL
    for (i in seq_len(nrow(df))) {
      resp <- list()
      for (col in meta$col_id) {
        if (!(col %in% names(df))) next
        v <- df[[col]][i]
        if (is.na(v) || trimws(as.character(v))=="") next
        resp[[as.character(question_map[[col]])]] <- as.character(v)
      }
      horo <- if (!is.null(horodateur_col)) as.character(df[[horodateur_col]][i]) else as.character(Sys.time())
      dbExecute(con,"INSERT INTO reponses (questionnaire_id,horodateur,donnees_json) VALUES (?,?,?)",
                list(as.integer(quest_id), horo, toJSON(resp, auto_unbox=TRUE, null="null")))
    }
    as.integer(quest_id)
  })
}

# ============================================================================
# IMPORT — sauvegarde en base depuis fichier (optionnel)
# ============================================================================
assign_section_name <- function(col_name, create_sections, n_questions) {
  if (!create_sections || n_questions <= 10) return("Questions")
  patterns <- list(
    "Connaissance"        = c("connaiss","savoir"),
    "Formation"           = c("format","apprendr","training"),
    "Agriculture"         = c("agricol","recolt","agroecolog","semence","maraich"),
    "Activites economiques"= c("revenu","marche","vente","activit","econom"),
    "Nutrition"           = c("nutrition","aliment","repas"),
    "Droits humains"      = c("droit","egalite","femme","genre"),
    "Environnement"       = c("environnement","rebois","climat"),
    "Gouvernance"         = c("autorite","decision","particip"),
    "Satisfaction"        = c("satisfait","qualite","appreci")
  )
  col_lower <- stri_trans_general(tolower(col_name),"Latin-ASCII")
  for (sname in names(patterns)) {
    if (any(grepl(paste(patterns[[sname]],collapse="|"), col_lower))) return(sname)
  }
  "Autres"
}

import_file_as_questionnaire <- function(file_path, sheet=NULL, has_header=TRUE,
                                          questionnaire_name, description="",
                                          create_sections=TRUE) {
  df_raw <- read_external_file(file_path, sheet, has_header)
  if (nrow(df_raw)==0) stop("Fichier vide")
  bundle <- build_ext_bundle_auto(df_raw)
  if (nrow(bundle$meta)==0) stop("Aucune variable exploitable détectée")
  save_external_as_questionnaire(bundle, questionnaire_name, description)
}

# ============================================================================
# EXPORT EXCEL
# ============================================================================
export_excel_analyses <- function(quest_id, file_path) {
  tryCatch({
    if (!requireNamespace("openxlsx",quietly=TRUE)) return(NULL)
    wb <- openxlsx::createWorkbook()
    openxlsx::addWorksheet(wb,"Taux_reponse")
    openxlsx::writeData(wb,"Taux_reponse", taux_reponse_par_question(quest_id))
    openxlsx::addWorksheet(wb,"Abandons")
    openxlsx::writeData(wb,"Abandons", taux_abandon(quest_id) %||% data.frame())
    openxlsx::saveWorkbook(wb,file_path,overwrite=TRUE)
    file_path
  }, error=function(e) NULL)
}

# ============================================================================
# QR CODE — Export / Import questionnaire
# ============================================================================

# Génère un UID court et lisible pour un questionnaire
generate_quest_uid <- function(quest_id, quest_nom) {
  hash <- toupper(substr(digest::digest(quest_nom, algo="crc32"), 1, 4))
  sprintf("LEST-%04d-%s", as.integer(quest_id), hash)
}

# Sérialise un questionnaire complet en JSON (pour upload Drive)
quest_to_full_json <- function(quest_id) {
  full <- get_questionnaire_full(quest_id)
  if (is.null(full)) stop("Questionnaire introuvable.")

  uid <- generate_quest_uid(quest_id, full$questionnaire$nom)

  sections_clean <- lapply(seq_len(nrow(full$sections)), function(i) {
    s <- full$sections[i,]
    list(id=s$id, nom=s$nom, ordre=s$ordre)
  })
  questions_clean <- lapply(seq_len(nrow(full$questions)), function(i) {
    q <- full$questions[i,]
    opts <- tryCatch(fromJSON(q$options %||% "{}"), error=function(e) character(0))
    list(id=q$id, sid=q$section_id, type=q$type, texte=q$texte,
         options=if(length(opts)>0) opts else NULL,
         obligatoire=as.integer(q$obligatoire))
  })

  payload <- list(
    lestrade_version = "1.0",
    uid       = uid,
    quest     = list(id=full$questionnaire$id, nom=full$questionnaire$nom,
                     description=full$questionnaire$description %||% ""),
    sections  = sections_clean,
    questions = questions_clean
  )
  list(uid=uid, json=as.character(toJSON(payload, auto_unbox=TRUE, null="null")),
       nom=full$questionnaire$nom,
       n_questions=nrow(full$questions),
       n_sections=nrow(full$sections))
}

# Génère le QR code — encode UID + IP serveur pour connexion automatique
# Le mobile extrait l'IP pour configurer le serveur, puis télécharge le questionnaire via l'UID
export_quest_to_qr <- function(quest_id, server_ip = "127.0.0.1", server_port = 8765) {
  if (!requireNamespace("digest", quietly=TRUE)) stop("Package 'digest' requis.")
  full <- get_questionnaire_full(quest_id)
  if (is.null(full)) stop("Questionnaire introuvable.")

  uid <- generate_quest_uid(quest_id, full$questionnaire$nom)

  # Payload : UID + IP serveur → un seul QR suffit pour connexion + import
  meta <- list(
    v    = "1.0",
    uid  = uid,
    nom  = full$questionnaire$nom,
    nq   = nrow(full$questions),
    ns   = nrow(full$sections),
    ip   = server_ip,
    port = server_port
  )
  json_str <- as.character(toJSON(meta, auto_unbox=TRUE))

  list(
    json        = json_str,
    uid         = uid,
    nom         = full$questionnaire$nom,
    n_questions = nrow(full$questions),
    n_chars     = nchar(json_str)
  )
}

# Upload le questionnaire complet sur le Drive de l'utilisateur
# Retourne le Drive file ID ou NULL si erreur
upload_quest_to_drive <- function(quest_id, drive_folder_id=NULL) {
  if (!requireNamespace("googledrive", quietly=TRUE))
    stop("Package 'googledrive' requis.")

  quest_data <- quest_to_full_json(quest_id)
  tmp <- tempfile(fileext=".json")
  writeLines(quest_data$json, tmp)
  on.exit(if (file.exists(tmp)) file.remove(tmp), add=TRUE)

  filename <- paste0("lestrade_quest_", quest_data$uid, ".json")

  # Supprimer l'ancien fichier s'il existe déjà (évite les doublons)
  tryCatch({
    existing <- googledrive::drive_find(pattern=filename, type="text/plain", n_max=3)
    if (nrow(existing) > 0)
      googledrive::drive_trash(googledrive::as_id(existing$id[1]))
  }, error=function(e) NULL)

  # Upload — signature correcte : media = chemin local, name = nom Drive
  result <- tryCatch(
    googledrive::drive_upload(
      media = tmp,
      name  = filename,
      type  = "text/plain"
    ),
    error=function(e) stop(paste("Erreur Drive:", e$message))
  )

  as.character(result$id)
}

# Télécharge et importe un questionnaire depuis Drive via l'UID
# Cherche le fichier "lestrade_quest_<uid>.json" dans le Drive
download_quest_from_drive <- function(uid) {
  if (!requireNamespace("googledrive", quietly=TRUE))
    stop("Package 'googledrive' requis.")

  filename <- paste0("lestrade_quest_", uid, ".json")
  found <- tryCatch(
    googledrive::drive_find(pattern=filename, type="text/plain", n_max=5),
    error=function(e) stop(paste("Erreur recherche Drive:", e$message))
  )
  if (nrow(found)==0)
    stop(paste0("Fichier '", filename, "' introuvable sur Drive.",
                "\nAssurez-vous que Drive est connecté et que le fichier a été partagé."))

  tmp <- tempfile(fileext=".json")
  googledrive::drive_download(googledrive::as_id(found$id[1]), path=tmp, overwrite=TRUE)
  json_str <- paste(readLines(tmp, warn=FALSE), collapse="")
  file.remove(tmp)
  json_str
}

# Importe un questionnaire depuis un JSON (QR complet ou Drive)
import_quest_from_json <- function(json_str) {
  payload <- tryCatch(
    fromJSON(json_str, simplifyVector=FALSE),
    error=function(e) stop(paste("JSON invalide:", e$message))
  )
  if (is.null(payload$lestrade_version) || is.null(payload$quest))
    stop("Format non reconnu — ce n'est pas un questionnaire Lestrade Forms.")

  con <- dbConnect(SQLite(), DB_PATH)
  on.exit(dbDisconnect(con), add=TRUE)

  DBI::dbWithTransaction(con, {
    uid <- payload$uid %||% ""
    # Anti-doublon par UID
    if (uid != "") {
      ex <- dbGetQuery(con,
        "SELECT id FROM questionnaires WHERE description LIKE ?",
        list(paste0("%[uid:", uid, "]%")))
      if (nrow(ex)>0) return(as.integer(ex$id[1]))
    }

    desc <- paste0(payload$quest$description %||% "",
                   if(uid!="") paste0(" [uid:",uid,"]") else "")
    dbExecute(con,
      "INSERT INTO questionnaires (nom,description,date_creation) VALUES (?,?,?)",
      list(payload$quest$nom, desc, as.character(Sys.time())))
    new_id <- dbGetQuery(con,"SELECT last_insert_rowid() as id")$id[1]

    section_map <- list()
    for (s in payload$sections) {
      dbExecute(con,
        "INSERT INTO sections (questionnaire_id,nom,ordre) VALUES (?,?,?)",
        list(as.integer(new_id), s$nom, as.integer(s$ordre)))
      section_map[[as.character(s$id)]] <-
        dbGetQuery(con,"SELECT last_insert_rowid() as id")$id[1]
    }

    for (i in seq_along(payload$questions)) {
      q   <- payload$questions[[i]]
      sid <- section_map[[as.character(q$sid)]]
      if (is.null(sid)) next
      opts_json <- if(!is.null(q$options)&&length(q$options)>0)
        as.character(toJSON(q$options, auto_unbox=TRUE)) else "{}"
      dbExecute(con,
        "INSERT INTO questions (section_id,type,texte,options,obligatoire,ordre) VALUES (?,?,?,?,?,?)",
        list(as.integer(sid), q$type, q$texte, opts_json,
             as.integer(q$obligatoire%||%0L), as.integer(i)))
    }
    as.integer(new_id)
  })
}

# ============================================================================
init_db()

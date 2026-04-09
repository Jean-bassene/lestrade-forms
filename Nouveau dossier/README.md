# ============================================================================
# LESTRADE FORMS — Architecture complète
# ============================================================================

## Structure des fichiers

```
lestrade_forms/
│
├── app_final.R          ← App Desktop  (lancer celui-ci sur le PC)
├── global_final.R       ← Partagé Desktop + Mobile (DB, helpers)
├── ui_final.R           ← Interface Desktop
├── server_final.R       ← Logique Desktop
│
├── app_mobile.R         ← App Mobile   (lancer celui-ci pour terrain)
├── ui_mobile.R          ← Interface shinyMobile (Framework7)
├── server_mobile.R      ← Logique collecte + sync Drive
│
├── questionnaires.db    ← Base SQLite principale (Desktop)
├── mobile_offline.db    ← Base SQLite locale Mobile (offline)
└── .secrets_mobile/     ← Token Google Drive (créé automatiquement)
```

---

## Flux de données

```
┌─────────────────────────────────────────────────────────┐
│                   LESTRADE FORMS Desktop                 │
│  Gestion questionnaires · Analytics · Export            │
│  questionnaires.db (SQLite local)                        │
└───────────────────────────┬─────────────────────────────┘
                            │ lit les mêmes questionnaires
                            │ (global_final.R partagé)
┌───────────────────────────▼─────────────────────────────┐
│                   LESTRADE FORMS Mobile                  │
│  Collecte terrain · Mode hors-ligne · Sync Drive        │
│  mobile_offline.db (SQLite local)                        │
└───────────────────────────┬─────────────────────────────┘
                            │ sync quand réseau disponible
                            ▼
                   ☁ Google Drive de l'utilisateur
                   (Google Sheet "Lestrade_Forms_Reponses")
                            │
                            │ import CSV/Excel
                            ▼
              ← Onglet Import de l'app Desktop →
```

---

## Installation

### Packages requis

```r
# App Desktop
install.packages(c(
  "shiny", "shinyjs", "RSQLite", "DBI",
  "dplyr", "jsonlite", "lubridate",
  "ggplot2", "plotly", "readxl", "readr",
  "stringi", "RColorBrewer", "openxlsx",
  "tidyr", "broom"
))

# App Mobile (en plus)
install.packages(c(
  "shinyMobile",
  "googlesheets4",
  "gargle"
))
```

### Lancer l'app Desktop

```r
shiny::runApp("app_final.R")
```

### Lancer l'app Mobile

```r
# Sur le PC — accessible depuis mobile via l'IP locale
shiny::runApp("app_mobile.R", port=3939, host="0.0.0.0")
# Puis sur le téléphone : http://192.168.x.x:3939
```

---

## Workflow terrain recommandé

### Étape 1 — Préparer (Bureau)
1. Ouvrir Lestrade Forms Desktop
2. Créer le questionnaire dans l'onglet **Construction**
3. Tester le formulaire dans l'onglet **Remplir**

### Étape 2 — Terrain (Mobile)
1. Ouvrir Lestrade Forms Mobile sur le téléphone
2. Onglet **Accueil** → sélectionner le questionnaire
3. Onglet **Formulaire** → saisir les réponses
4. Cliquer **Enregistrer** → sauvegarde locale immédiate
5. Répéter pour chaque enquêté (sans internet requis)

### Étape 3 — Synchroniser
**Option A — Sync Drive (recommandé)**
1. Onglet **Réponses** → connecter Google Drive (1 seule fois)
2. Cliquer **Synchroniser maintenant**
3. Les réponses arrivent dans la Google Sheet de l'utilisateur

**Option B — Export direct**
1. Exporter la Google Sheet en CSV/Excel
2. Importer dans Lestrade Forms Desktop via l'onglet **Import**
3. Analyser dans l'onglet **Analytics**

---

## Configuration Google Drive (première fois)

La première connexion ouvre un navigateur pour l'autorisation OAuth.
Le token est ensuite stocké dans `.secrets_mobile/` — l'utilisateur
ne se reconnecte plus jusqu'à déconnexion manuelle.

Aucun compte développeur requis pour commencer — le mode "test"
de Google Cloud suffit pour un usage personnel ou en équipe restreinte.

Pour un déploiement professionnel (>100 utilisateurs) :
→ Créer un projet Google Cloud
→ Activer Google Drive API + Google Sheets API  
→ Configurer l'écran de consentement OAuth
→ Télécharger le fichier client_id.json et le placer dans le projet

---

## Roadmap suggérée

- [ ] **v1.0** — App mobile collecte + sync Drive (actuel)
- [ ] **v1.1** — Géolocalisation automatique (lat/lng ajoutés à chaque réponse)
- [ ] **v1.2** — Photo terrain (capture + upload Drive)
- [ ] **v2.0** — API REST avec `{plumber}` — sync direct Desktop ↔ Mobile
- [ ] **v2.1** — Authentification multi-utilisateurs (Supabase ou Firebase)
- [ ] **v3.0** — App native (Flutter) connectée à l'API plumber

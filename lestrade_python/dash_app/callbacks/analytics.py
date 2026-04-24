"""
Callbacks onglet Analytics — descriptif, tableaux croisés, profils,
corrélations, scores composites, régression logistique, exports.
"""
import json
import math
from collections import Counter, defaultdict
from datetime import datetime
import io

from dash import callback, Output, Input, State, no_update, html
import plotly.graph_objects as go
import pandas as pd
import numpy as np

from ..utils import security, api_client
from ..utils.charts import (
    bar_chart, pie_chart, histogram_chart, heatmap_chart,
    timeline_chart, radar_chart, empty_fig, parse_response_values,
)


# ── Helpers internes ──────────────────────────────────────────────────────────

def _build_numeric_matrix(reps: list, questions: list) -> tuple[pd.DataFrame, dict]:
    """
    Construit un DataFrame numérique à partir des réponses.
    Seules les questions role_analytique='indicator' sont incluses.
    Retourne (df_numeric, labels) où labels = {col_id: texte}.
    """
    LIKERT_MAP = {
        "pas d'accord": 1, "plutôt pas d'accord": 2, "plutôt pas": 2,
        "neutre": 3, "plutôt d'accord": 4, "tout à fait d'accord": 5, "tout à fait": 5,
        "jamais": 1, "rarement": 2, "parfois": 3, "souvent": 4, "toujours": 5,
    }
    ind_qs = [q for q in questions if q.get("role_analytique") == "indicator"]
    if not ind_qs:
        return pd.DataFrame(), {}

    labels = {str(q["id"]): security.sanitize_text(q["texte"], 50) for q in ind_qs}
    records = []
    for rep in reps:
        try:
            d = json.loads(rep.get("donnees_json", "{}"))
        except Exception:
            continue
        row = {}
        for q in ind_qs:
            v = d.get(str(q["id"]))
            if v in (None, "", []):
                row[str(q["id"])] = np.nan
                continue
            v_str = str(v).strip().lower()
            if v_str in LIKERT_MAP:
                row[str(q["id"])] = LIKERT_MAP[v_str]
            else:
                try:
                    row[str(q["id"])] = float(v_str)
                except ValueError:
                    row[str(q["id"])] = np.nan
        records.append(row)

    df = pd.DataFrame(records)
    return df, labels


def _build_section_scores(reps: list, questions: list, sections: list,
                           group_var_id: str, section_ids: list | None) -> pd.DataFrame | None:
    """
    Score moyen (0-100 %) par groupe × section pour les indicateurs.
    """
    ind_qs = [q for q in questions if q.get("role_analytique") == "indicator"]
    if not ind_qs or not group_var_id:
        return None

    sec_map = {s["id"]: security.sanitize_text(s["nom"], 40) for s in sections}

    if section_ids:
        sec_ids_set = set(int(s) for s in section_ids)
        ind_qs = [q for q in ind_qs if q.get("section_id") in sec_ids_set]

    if not ind_qs:
        return None

    group_sec_filled  = defaultdict(lambda: defaultdict(int))
    group_sec_total   = defaultdict(lambda: defaultdict(int))

    for rep in reps:
        try:
            d = json.loads(rep.get("donnees_json", "{}"))
        except Exception:
            continue
        grp = d.get(str(group_var_id))
        if not grp:
            continue
        grp = str(grp).strip()
        for q in ind_qs:
            sec_nom = sec_map.get(q.get("section_id"), "?")
            v = d.get(str(q["id"]))
            group_sec_total[grp][sec_nom] += 1
            if v not in (None, "", []):
                group_sec_filled[grp][sec_nom] += 1

    all_groups = sorted(group_sec_total.keys())
    all_secs   = sorted(set(s for g in group_sec_total.values() for s in g))

    if not all_groups or not all_secs:
        return None

    rows = []
    for grp in all_groups:
        row = {"Groupe": grp}
        scores = []
        for sec in all_secs:
            t = group_sec_total[grp][sec]
            f = group_sec_filled[grp][sec]
            s = round(f / t * 100, 1) if t else 0
            row[sec] = s
            scores.append(s)
        row["Score composite (%)"] = round(sum(scores) / len(scores), 1) if scores else 0
        rows.append(row)

    return pd.DataFrame(rows)


def register(app):

    # ── Métriques + population des dropdowns ──────────────────────────────────

    @callback(
        Output("ana-n",                   "children"),
        Output("ana-score",               "children"),
        Output("ana-compl",               "children"),
        Output("ana-q-count",             "children"),
        Output("ana-plot-var",            "options"),
        Output("ana-cross-row",           "options"),
        Output("ana-cross-col",           "options"),
        Output("ana-cmp-row",             "options"),
        Output("ana-cmp-col",             "options"),
        Output("ana-profile-group",       "options"),
        Output("ana-group-var",           "options"),
        Output("ana-composite-group",     "options"),
        Output("ana-composite-sections",  "options"),
        Output("ana-logit-outcome",       "options"),
        Output("ana-logit-predictors",    "options"),
        Input("ana-quest-select", "value"),
    )
    def load_ana_meta(quest_id):
        empty = ["—", "—", "—", "—"] + [[] for _ in range(11)]
        if not quest_id:
            return empty

        data = api_client.get_questionnaire(int(quest_id))
        if "error" in data:
            return empty

        questions = data.get("questions", [])
        sections  = data.get("sections",  [])
        reps      = api_client.get_reponses(int(quest_id))

        nb_q   = len(questions)
        nb_rep = len(reps)

        # Score moyen Likert
        LIKERT_MAP = {"pas d'accord": 1, "plutôt pas": 2, "neutre": 3, "plutôt d'accord": 4, "tout à fait": 5}
        likert_vals = []
        for q in questions:
            if q.get("type") == "likert":
                for v in parse_response_values(reps, q["id"]):
                    n = LIKERT_MAP.get(str(v).strip().lower())
                    if n:
                        likert_vals.append(n)
        score = f"{sum(likert_vals)/len(likert_vals):.2f}" if likert_vals else "N/A"

        # Complétude
        if nb_q and nb_rep:
            total_filled = 0
            for rep in reps:
                try:
                    d = json.loads(rep.get("donnees_json", "{}"))
                    total_filled += sum(1 for v in d.values() if v not in (None, "", [], {}))
                except Exception:
                    pass
            compl = f"{total_filled / (nb_q * nb_rep) * 100:.1f}%"
        else:
            compl = "N/A"

        # Options dropdowns
        all_opts   = [{"label": security.sanitize_text(q["texte"], 60), "value": str(q["id"])} for q in questions]
        group_opts = [{"label": security.sanitize_text(q["texte"], 60), "value": str(q["id"])}
                      for q in questions if q.get("role_analytique") in ("group", "indicator", None)]
        sec_opts   = [{"label": security.sanitize_text(s["nom"], 60), "value": str(s["id"])} for s in sections]

        return (
            str(nb_rep), score, compl, str(nb_q),
            all_opts, all_opts, all_opts, all_opts, all_opts,
            group_opts, group_opts,
            group_opts, sec_opts,
            all_opts, all_opts,
        )

    # ── Tableau qualité données ───────────────────────────────────────────────

    @callback(
        Output("ana-quality-table",    "columns"),
        Output("ana-quality-table",    "data"),
        Output("ana-completion-table", "columns"),
        Output("ana-completion-table", "data"),
        Input("ana-quest-select", "value"),
    )
    def quality_tables(quest_id):
        no = [], [], [], []
        if not quest_id:
            return no

        data = api_client.get_questionnaire(int(quest_id))
        if "error" in data:
            return no

        questions = data.get("questions", [])
        sections  = data.get("sections",  [])
        reps      = api_client.get_reponses(int(quest_id))
        nb_rep    = len(reps)
        if not questions or not nb_rep:
            return no

        quality_rows = []
        for q in questions:
            vals = parse_response_values(reps, q["id"])
            n_f  = len(vals)
            quality_rows.append({
                "Question":   security.sanitize_text(q["texte"], 60),
                "Type":       q.get("type", "?"),
                "Remplies":   n_f,
                "Manquantes": nb_rep - n_f,
                "Taux":       f"{n_f/nb_rep*100:.1f}%",
                "Modalités":  len(set(vals)),
            })
        q_cols = [{"name": c, "id": c} for c in quality_rows[0].keys()]

        sec_map = {s["id"]: s["nom"] for s in sections}
        sec_cnt = defaultdict(lambda: {"filled": 0, "total": 0})
        for q in questions:
            sid  = q.get("section_id")
            vals = parse_response_values(reps, q["id"])
            sec_cnt[sid]["filled"] += len(vals)
            sec_cnt[sid]["total"]  += nb_rep

        compl_rows = [
            {"Section":   security.sanitize_text(sec_map.get(sid, "?"), 80),
             "Taux (%)":  f"{c['filled']/c['total']*100:.1f}%" if c["total"] else "N/A",
             "Remplies":  c["filled"],
             "Attendues": c["total"]}
            for sid, c in sec_cnt.items()
        ]
        c_cols = [{"name": c, "id": c} for c in compl_rows[0].keys()] if compl_rows else []
        return q_cols, quality_rows, c_cols, compl_rows

    # ── Graphique univarié ────────────────────────────────────────────────────

    @callback(
        Output("ana-single-plot", "figure"),
        Output("ana-plot-msg",    "children"),
        Input("ana-quest-select", "value"),
        Input("ana-plot-var",     "value"),
        Input("ana-plot-type",    "value"),
    )
    def single_plot(quest_id, var_id, plot_type):
        if not quest_id or not var_id:
            return empty_fig("Sélectionnez un questionnaire et une variable."), ""
        reps = api_client.get_reponses(int(quest_id))
        if not reps:
            return empty_fig("Aucune réponse disponible."), ""
        vals = parse_response_values(reps, var_id)
        if not vals:
            return empty_fig("Aucune valeur pour cette variable."), html.Div("Variable sans réponse.", className="hint")
        data  = api_client.get_questionnaire(int(quest_id))
        q_map = {str(q["id"]): q["texte"] for q in data.get("questions", [])}
        title = security.sanitize_text(q_map.get(str(var_id), var_id), 80)
        if plot_type == "bar":
            fig = bar_chart(vals, title)
        elif plot_type == "pie":
            fig = pie_chart(vals, title)
        else:
            nums = [float(v) for v in vals if _is_numeric(v)]
            fig  = histogram_chart(nums, title) if nums else bar_chart(vals, title)
        return fig, ""

    # ── Timeline ──────────────────────────────────────────────────────────────

    @callback(
        Output("ana-timeline-plot", "figure"),
        Input("ana-quest-select",   "value"),
    )
    def timeline_plot(quest_id):
        if not quest_id:
            return empty_fig()
        reps = api_client.get_reponses(int(quest_id))
        if not reps:
            return empty_fig("Aucune réponse.")
        date_counts = Counter()
        for r in reps:
            try:
                d = datetime.fromisoformat(str(r.get("horodateur", ""))[:19]).date().isoformat()
                date_counts[d] += 1
            except Exception:
                pass
        if not date_counts:
            return empty_fig("Horodatages non disponibles.")
        sd = sorted(date_counts)
        return timeline_chart(sd, [date_counts[d] for d in sd], "Réponses par jour")

    # ── Tableau croisé ────────────────────────────────────────────────────────

    @callback(
        Output("ana-crosstab", "columns"),
        Output("ana-crosstab", "data"),
        Input("ana-quest-select", "value"),
        Input("ana-cross-row",   "value"),
        Input("ana-cross-col",   "value"),
        Input("ana-cross-mode",  "value"),
    )
    def crosstab(quest_id, row_id, col_id, mode):
        if not quest_id or not row_id or not col_id:
            return [], []
        reps = api_client.get_reponses(int(quest_id))
        if not reps:
            return [], []
        paired_r, paired_c = [], []
        for rep in reps:
            try:
                d = json.loads(rep.get("donnees_json", "{}"))
            except Exception:
                continue
            rv = d.get(str(row_id))
            cv = d.get(str(col_id))
            if rv not in (None, "", []) and cv not in (None, "", []):
                paired_r.append(str(rv))
                paired_c.append(str(cv))
        if not paired_r:
            return [], []
        df = pd.DataFrame({"row": paired_r, "col": paired_c})
        try:
            ct = pd.crosstab(df["row"], df["col"])
        except Exception:
            return [], []
        total = ct.values.sum()
        if mode == "row_pct":
            ct = ct.div(ct.sum(axis=1), axis=0).mul(100).round(1)
        elif mode == "col_pct":
            ct = ct.div(ct.sum(axis=0), axis=1).mul(100).round(1)
        elif mode == "global_pct" and total > 0:
            ct = ct.div(total).mul(100).round(1)
        ct = ct.reset_index()
        cols = [{"name": security.sanitize_text(str(c), 60), "id": str(c)} for c in ct.columns]
        rows = [{security.sanitize_text(str(k), 60): v for k, v in r.items()} for r in ct.to_dict("records")]
        return cols, rows

    # ── Comparaison bivariée + test chi² ─────────────────────────────────────

    @callback(
        Output("ana-bivariate-plot", "figure"),
        Output("ana-test-result",    "children"),
        Output("ana-test-interp",    "children"),
        Input("ana-quest-select",    "value"),
        Input("ana-cmp-row",         "value"),
        Input("ana-cmp-col",         "value"),
        Input("ana-cmp-plot-type",   "value"),
        Input("ana-alpha",           "value"),
    )
    def bivariate(quest_id, row_id, col_id, plot_type, alpha):
        if not quest_id or not row_id or not col_id:
            return empty_fig(), "", ""
        reps = api_client.get_reponses(int(quest_id))
        paired_r, paired_c = [], []
        for rep in reps:
            try:
                d = json.loads(rep.get("donnees_json", "{}"))
            except Exception:
                continue
            rv = d.get(str(row_id))
            cv = d.get(str(col_id))
            if rv not in (None, "", []) and cv not in (None, "", []):
                paired_r.append(str(rv))
                paired_c.append(str(cv))
        if len(paired_r) < 5:
            return empty_fig("Pas assez de données appariées (min 5)."), "", ""
        df = pd.DataFrame({"row": paired_r, "col": paired_c})
        try:
            ct = pd.crosstab(df["row"], df["col"])
        except Exception:
            return empty_fig("Erreur de croisement."), "", ""
        if plot_type == "stacked":
            ct_pct = ct.div(ct.sum(axis=1), axis=0).mul(100)
            fig = go.Figure()
            for c in ct_pct.columns:
                fig.add_trace(go.Bar(
                    name=security.sanitize_text(str(c), 40),
                    x=[security.sanitize_text(str(r), 40) for r in ct_pct.index],
                    y=ct_pct[c].tolist(),
                ))
            fig.update_layout(barmode="stack", paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)")
        else:
            fig = empty_fig("Type de graphe non supporté.")
        test_text = test_interp = ""
        try:
            from scipy.stats import chi2_contingency
            chi2, p, dof, _ = chi2_contingency(ct.values)
            n = ct.values.sum()
            v = math.sqrt(chi2 / (n * (min(ct.shape) - 1))) if n and min(ct.shape) > 1 else 0
            test_text = (f"Test χ² d'indépendance\nχ² = {chi2:.4f}  |  ddl = {dof}  |  p = {p:.4f}\n"
                         f"V de Cramér = {v:.3f}  |  n = {n}")
            af = float(alpha)
            test_interp = (f"✓ Association significative (p < {af})." if p < af
                           else f"✗ Pas d'association significative (p ≥ {af}).")
        except ImportError:
            test_text = "scipy non installé."
        except Exception as e:
            test_text = f"Erreur : {type(e).__name__}"
        return fig, test_text, test_interp

    # ── Profils (heatmap + radar) ─────────────────────────────────────────────

    @callback(
        Output("ana-profile-summary", "columns"),
        Output("ana-profile-summary", "data"),
        Output("ana-profile-heatmap", "figure"),
        Output("ana-profile-radar",   "figure"),
        Input("ana-quest-select",     "value"),
        Input("ana-profile-group",    "value"),
    )
    def profiles(quest_id, group_var_id):
        no = [], [], empty_fig(), empty_fig()
        if not quest_id or not group_var_id:
            return no
        data = api_client.get_questionnaire(int(quest_id))
        if "error" in data:
            return no
        reps      = api_client.get_reponses(int(quest_id))
        questions = data.get("questions", [])
        sections  = data.get("sections",  [])
        if not reps:
            return no
        sec_map = {s["id"]: security.sanitize_text(s["nom"], 40) for s in sections}
        ind_qs  = [q for q in questions if q.get("role_analytique") == "indicator"]
        if not ind_qs:
            return [], [], empty_fig("Aucune variable indicateur."), empty_fig()
        scores: dict[str, dict[str, list]] = defaultdict(lambda: defaultdict(list))
        for rep in reps:
            try:
                d = json.loads(rep.get("donnees_json", "{}"))
            except Exception:
                continue
            grp = str(d.get(str(group_var_id), "")).strip()
            if not grp:
                continue
            for q in ind_qs:
                v = d.get(str(q["id"]))
                sec_nom = sec_map.get(q.get("section_id"), "?")
                scores[grp][sec_nom].append(1 if v not in (None, "", []) else 0)
        groups   = sorted(scores)[:10]
        sec_noms = sorted(set(s for g in scores.values() for s in g))
        z_matrix = []
        y_labels = []
        for grp in groups:
            row_z = [sum(scores[grp].get(s, [0])) / len(scores[grp].get(s, [1])) * 100 for s in sec_noms]
            z_matrix.append(row_z)
            y_labels.append(security.sanitize_text(grp, 40))
        heat = heatmap_chart(z_matrix, [security.sanitize_text(s, 40) for s in sec_noms], y_labels,
                             "Complétude par groupe × section (%)")
        radar_data = {security.sanitize_text(g, 40): [
            sum(scores[g].get(s, [0])) / len(scores[g].get(s, [1])) * 100 for s in sec_noms]
            for g in groups}
        rad = radar_chart([security.sanitize_text(s, 40) for s in sec_noms], radar_data, "Profil des groupes")
        summary_rows = [{"Groupe": security.sanitize_text(g, 60),
                         "Complétude globale": f"{sum(v for vals in scores[g].values() for v in vals) / max(1, sum(len(vals) for vals in scores[g].values())) * 100:.1f}%"}
                        for g in groups]
        s_cols = [{"name": c, "id": c} for c in summary_rows[0].keys()] if summary_rows else []
        return s_cols, summary_rows, heat, rad

    # ── Corrélations ─────────────────────────────────────────────────────────

    @callback(
        Output("ana-corr-heatmap", "figure"),
        Output("ana-corr-table",   "columns"),
        Output("ana-corr-table",   "data"),
        Input("ana-quest-select",  "value"),
    )
    def correlations(quest_id):
        no = empty_fig("Sélectionnez un questionnaire."), [], []
        if not quest_id:
            return no
        data      = api_client.get_questionnaire(int(quest_id))
        if "error" in data:
            return no
        reps      = api_client.get_reponses(int(quest_id))
        questions = data.get("questions", [])
        if not reps:
            return empty_fig("Aucune réponse."), [], []

        df_num, labels = _build_numeric_matrix(reps, questions)
        if df_num.empty or df_num.shape[1] < 2:
            return empty_fig("Pas assez d'indicateurs numériques (min 2)."), [], []

        # Supprimer colonnes entièrement NaN
        df_num = df_num.dropna(axis=1, how="all")
        if df_num.shape[1] < 2:
            return empty_fig("Pas assez de valeurs numériques exploitables."), [], []

        corr = df_num.corr(numeric_only=True)
        lbls = [labels.get(c, c)[:28] for c in corr.columns]

        # Heatmap
        fig = go.Figure(go.Heatmap(
            z=corr.values.tolist(),
            x=lbls, y=lbls,
            zmin=-1, zmax=1,
            colorscale=[[0, "#b2182b"], [0.5, "#f7f7f7"], [1, "#2166ac"]],
            colorbar={"title": "r"},
        ))
        fig.update_layout(margin={"l": 120, "r": 20, "t": 20, "b": 120},
                          paper_bgcolor="rgba(0,0,0,0)",
                          xaxis={"tickangle": -35}, yaxis={"autorange": "reversed"})

        # Tableau top corrélations
        pairs = []
        cols_list = list(corr.columns)
        for i, c1 in enumerate(cols_list):
            for j, c2 in enumerate(cols_list):
                if j <= i:
                    continue
                r = corr.loc[c1, c2]
                if pd.isna(r):
                    continue
                force = (
                    "Très forte" if abs(r) >= 0.8 else
                    "Forte"      if abs(r) >= 0.6 else
                    "Modérée"    if abs(r) >= 0.4 else
                    "Faible"     if abs(r) >= 0.2 else
                    "Très faible"
                )
                pairs.append({
                    "Indicateur 1": labels.get(c1, c1),
                    "Indicateur 2": labels.get(c2, c2),
                    "Corrélation":  round(r, 3),
                    "Force":        force,
                })

        pairs.sort(key=lambda x: abs(x["Corrélation"]), reverse=True)
        top30 = pairs[:30]
        t_cols = [{"name": c, "id": c} for c in ["Indicateur 1", "Indicateur 2", "Corrélation", "Force"]]
        return fig, t_cols, top30

    # ── Scores composites ─────────────────────────────────────────────────────

    @callback(
        Output("ana-composite-table", "columns"),
        Output("ana-composite-table", "data"),
        Output("ana-composite-plot",  "figure"),
        Input("ana-quest-select",       "value"),
        Input("ana-composite-group",    "value"),
        Input("ana-composite-sections", "value"),
    )
    def composite_scores(quest_id, group_var_id, section_ids):
        no = [], [], empty_fig("Sélectionnez un questionnaire et un groupe.")
        if not quest_id or not group_var_id:
            return no
        data      = api_client.get_questionnaire(int(quest_id))
        if "error" in data:
            return no
        reps      = api_client.get_reponses(int(quest_id))
        questions = data.get("questions", [])
        sections  = data.get("sections",  [])
        if not reps:
            return [], [], empty_fig("Aucune réponse.")

        df = _build_section_scores(reps, questions, sections, group_var_id, section_ids)
        if df is None or df.empty:
            return [], [], empty_fig("Sélectionne un groupe et des sections avec des indicateurs.")

        cols  = [{"name": c, "id": c} for c in df.columns]
        rows  = df.round(1).to_dict("records")

        # Graphique barres — score composite par groupe
        fig = go.Figure(go.Bar(
            x=df["Groupe"].tolist(),
            y=df["Score composite (%)"].tolist(),
            marker_color="#245c7c",
            text=[f"{v:.1f}%" for v in df["Score composite (%)"]],
            textposition="outside",
        ))
        fig.update_layout(
            yaxis={"range": [0, 110], "title": "Score composite (%)"},
            xaxis={"title": "Groupe"},
            paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)",
            margin={"t": 30},
        )
        return cols, rows, fig

    # ── Régression logistique ─────────────────────────────────────────────────

    @callback(
        Output("ana-logit-table",       "columns"),
        Output("ana-logit-table",       "data"),
        Output("ana-logit-info",        "children"),
        Input("ana-quest-select",       "value"),
        Input("ana-logit-outcome",      "value"),
        Input("ana-logit-predictors",   "value"),
    )
    def logistic_regression(quest_id, outcome_id, predictor_ids):
        no = [], [], ""
        if not quest_id or not outcome_id or not predictor_ids:
            return no

        data      = api_client.get_questionnaire(int(quest_id))
        if "error" in data:
            return no
        reps      = api_client.get_reponses(int(quest_id))
        questions = data.get("questions", [])
        if not reps:
            return [], [], "Aucune réponse disponible."

        q_map = {str(q["id"]): security.sanitize_text(q["texte"], 60) for q in questions}
        pred_ids = [p for p in predictor_ids if p != outcome_id]
        if not pred_ids:
            return [], [], "Ajoutez au moins un prédicteur différent de la cible."

        # Construire le DataFrame
        records = []
        for rep in reps:
            try:
                d = json.loads(rep.get("donnees_json", "{}"))
            except Exception:
                continue
            row = {}
            for col_id in [outcome_id] + pred_ids:
                v = d.get(str(col_id))
                row[col_id] = str(v).strip() if v not in (None, "", []) else None
            records.append(row)

        df = pd.DataFrame(records).dropna()
        n_obs = len(df)
        groups = df[outcome_id].unique().tolist()
        info = f"Observations exploitables : {n_obs}\nGroupes cible : {' / '.join(str(g) for g in groups)}"

        if n_obs < 20:
            return [], [], info + "\n⚠ Effectif insuffisant (min 20)."
        if len(groups) != 2:
            return [], [], info + f"\n⚠ La variable cible doit avoir exactement 2 modalités (trouvé : {len(groups)})."

        try:
            import statsmodels.api as sm
            y = (df[outcome_id] == groups[1]).astype(int)
            X_parts = []
            col_names = []
            for pid in pred_ids:
                dummies = pd.get_dummies(df[pid], prefix=q_map.get(pid, pid)[:20], drop_first=True)
                X_parts.append(dummies)
                col_names += list(dummies.columns)
            if not X_parts:
                return [], [], info + "\nAucun prédicteur valide."
            X = pd.concat(X_parts, axis=1).astype(float)
            X = sm.add_constant(X)
            model = sm.Logit(y, X).fit(disp=False)
            params = model.params
            conf   = model.conf_int()
            pvals  = model.pvalues
            table_rows = []
            for term in params.index:
                if term == "const":
                    continue
                or_  = round(math.exp(params[term]), 3)
                ci_l = round(math.exp(conf.loc[term, 0]), 3)
                ci_h = round(math.exp(conf.loc[term, 1]), 3)
                p    = round(pvals[term], 4)
                table_rows.append({
                    "Terme":    security.sanitize_text(str(term), 60),
                    "OR":       or_,
                    "IC 2.5%":  ci_l,
                    "IC 97.5%": ci_h,
                    "p-value":  p,
                    "Sig.":     "***" if p < 0.001 else ("**" if p < 0.01 else ("*" if p < 0.05 else "")),
                })
            cols = [{"name": c, "id": c} for c in ["Terme", "OR", "IC 2.5%", "IC 97.5%", "p-value", "Sig."]]
            return cols, table_rows, info

        except ImportError:
            # Fallback : calcul manuel odds ratio 2×2 par variable
            table_rows = []
            y_binary = (df[outcome_id] == groups[1]).astype(int)
            for pid in pred_ids:
                try:
                    cats = df[pid].unique()
                    ref  = cats[0]
                    for cat in cats[1:]:
                        mask_cat = df[pid] == cat
                        mask_ref = df[pid] == ref
                        a = (mask_cat & (y_binary == 1)).sum()
                        b = (mask_cat & (y_binary == 0)).sum()
                        c = (mask_ref & (y_binary == 1)).sum()
                        d = (mask_ref & (y_binary == 0)).sum()
                        if b * c == 0:
                            continue
                        or_  = (a * d) / (b * c)
                        # IC approximé par Woolf
                        try:
                            se   = math.sqrt(1/a + 1/b + 1/c + 1/d)
                            ci_l = round(math.exp(math.log(or_) - 1.96 * se), 3)
                            ci_h = round(math.exp(math.log(or_) + 1.96 * se), 3)
                        except Exception:
                            ci_l = ci_h = "—"
                        table_rows.append({
                            "Terme":    f"{q_map.get(pid, pid)[:30]} = {cat}",
                            "OR":       round(or_, 3),
                            "IC 2.5%":  ci_l,
                            "IC 97.5%": ci_h,
                            "p-value":  "—",
                            "Sig.":     "",
                        })
                except Exception:
                    continue
            cols = [{"name": c, "id": c} for c in ["Terme", "OR", "IC 2.5%", "IC 97.5%", "p-value", "Sig."]]
            note = info + "\n(statsmodels non installé — OR bruts 2×2, pas de régression multivariée)"
            return cols, table_rows, note

        except Exception as e:
            return [], [], info + f"\nErreur : {type(e).__name__}: {e}"

    # ── Export dataset CSV ────────────────────────────────────────────────────

    @callback(
        Output("download-dataset-csv", "data"),
        Output("ana-export-msg",       "children"),
        Input("btn-export-dataset-csv","n_clicks"),
        State("ana-quest-select",      "value"),
        prevent_initial_call=True,
    )
    def export_dataset_csv(n_clicks, quest_id):
        if not n_clicks or not quest_id:
            return no_update, no_update
        rows = api_client.get_reponses_wide(int(quest_id))
        if not rows:
            return no_update, html.Div("Aucune donnée.", className="alert-warn")
        df = pd.DataFrame(rows)
        def _safe(v):
            s = str(v or "")
            return ("'" + s) if s.startswith(("=", "+", "-", "@")) else s
        for col in df.columns:
            df[col] = df[col].apply(_safe)
        fname = f"dataset_{quest_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
        return dict(content=df.to_csv(index=False), filename=fname, type="text/csv"), html.Div("Export terminé.", className="alert-success")

    # ── Export scores composites CSV ──────────────────────────────────────────

    @callback(
        Output("download-scores-csv",   "data"),
        Output("ana-export-msg",        "children", allow_duplicate=True),
        Input("btn-export-scores-csv",  "n_clicks"),
        State("ana-quest-select",       "value"),
        State("ana-composite-group",    "value"),
        State("ana-composite-sections", "value"),
        prevent_initial_call=True,
    )
    def export_scores_csv(n_clicks, quest_id, group_var_id, section_ids):
        if not n_clicks or not quest_id:
            return no_update, no_update
        data      = api_client.get_questionnaire(int(quest_id))
        reps      = api_client.get_reponses(int(quest_id))
        questions = data.get("questions", [])
        sections  = data.get("sections",  [])
        df = _build_section_scores(reps, questions, sections, group_var_id or "", section_ids)
        if df is None or df.empty:
            return no_update, html.Div("Scores vides — configurez d'abord l'onglet Scores composites.", className="alert-warn")
        fname = f"scores_{quest_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
        return (dict(content=df.to_csv(index=False), filename=fname, type="text/csv"),
                html.Div("Export scores terminé.", className="alert-success"))


# ── Utilitaire ────────────────────────────────────────────────────────────────

def _is_numeric(v) -> bool:
    try:
        float(str(v))
        return True
    except (ValueError, TypeError):
        return False

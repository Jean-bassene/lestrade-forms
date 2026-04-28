"""
Callbacks onglet Analytics — descriptif, tableaux croisés, profils,
corrélations, scores composites, régression logistique, exports, carte GPS.

Améliorations v2 :
① Filtre global branché  (ana-group-var + ana-group-filter-val)
② Stats descriptives complètes + boxplot
③ Timeline cumulative + objectif de collecte configurable
④ Profils et scores sur valeurs réelles (Likert/num.), plus complétude
⑤ Carte GPS analytique avec colorisation par variable
"""
import json
import math
from collections import Counter, defaultdict
from datetime import datetime

from dash import callback, Output, Input, State, no_update, html
import plotly.graph_objects as go
import pandas as pd
import numpy as np

from ..utils import security, api_client
from ..utils.charts import (
    bar_chart, pie_chart, histogram_chart, heatmap_chart,
    timeline_chart, radar_chart, empty_fig, parse_response_values,
    boxplot_chart,
)

PALETTE = [
    "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd",
    "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf",
]

# ── Constantes Likert ─────────────────────────────────────────────────────────

LIKERT_SCALE = {
    "tout à fait d'accord": 5, "tout à fait": 5,
    "plutôt d'accord": 4,
    "neutre": 3,
    "plutôt pas d'accord": 2, "plutôt pas": 2,
    "pas d'accord": 1,
    "toujours": 5, "souvent": 4, "parfois": 3, "rarement": 2, "jamais": 1,
}


# ── Helpers ───────────────────────────────────────────────────────────────────

def _extract_json(text: str) -> dict:
    """Extrait le premier objet JSON valide même si Claude ajoute du markdown ou du texte."""
    start = text.find('{')
    end   = text.rfind('}')
    if start == -1 or end == -1 or end <= start:
        raise ValueError(f"Aucun objet JSON trouvé dans : {text[:200]!r}")
    return json.loads(text[start:end + 1])


def _val_to_numeric(v) -> float | None:
    """Convertit une valeur Likert ou numérique en float ; None si impossible.
    Gère aussi les labels du type '1 - Tres degrade' ou '5 - Tres fertile'."""
    if v in (None, "", []):
        return None
    v_str = str(v).strip().lower()
    if v_str in LIKERT_SCALE:
        return float(LIKERT_SCALE[v_str])
    try:
        return float(v_str)
    except ValueError:
        pass
    # Labels "N - texte" générés par le constructeur de questionnaire (ex. options Likert)
    import re
    m = re.match(r'^(\d+(?:\.\d+)?)\s*[-–]', v_str)
    if m:
        return float(m.group(1))
    return None


def _filter_reps(reps: list, group_var: str | None, filter_val: str | None) -> list:
    """Filtre les réponses sur la valeur d'une variable de groupe."""
    if not group_var or not filter_val:
        return reps
    out = []
    for rep in reps:
        try:
            d = json.loads(rep.get("donnees_json", "{}"))
            if str(d.get(str(group_var), "")).strip() == str(filter_val).strip():
                out.append(rep)
        except Exception:
            pass
    return out


def _build_numeric_matrix(reps: list, questions: list) -> tuple[pd.DataFrame, dict]:
    """DataFrame numérique (indicateurs uniquement)."""
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
        row = {str(q["id"]): (_val_to_numeric(d.get(str(q["id"]))) or np.nan) for q in ind_qs}
        records.append(row)
    return pd.DataFrame(records), labels


def _build_response_means(reps: list, questions: list, sections: list,
                           group_var_id: str, section_ids: list | None) -> pd.DataFrame | None:
    """
    Moyenne réelle (Likert ou numérique) par groupe × section.
    Remplace _build_section_scores qui mesurait la complétude (incorrect).
    """
    ind_qs = [q for q in questions if q.get("role_analytique") == "indicator"]
    if not ind_qs or not group_var_id:
        return None
    sec_map = {s["id"]: security.sanitize_text(s["nom"], 40) for s in sections}
    if section_ids:
        sec_ids_set = {int(s) for s in section_ids}
        ind_qs = [q for q in ind_qs if q.get("section_id") in sec_ids_set]
    if not ind_qs:
        return None

    group_sec_vals: dict[str, dict[str, list[float]]] = defaultdict(lambda: defaultdict(list))
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
            num = _val_to_numeric(d.get(str(q["id"])))
            if num is not None:
                sec_nom = sec_map.get(q.get("section_id"), "?")
                group_sec_vals[grp][sec_nom].append(num)

    all_groups = sorted(group_sec_vals.keys())
    all_secs   = sorted({s for g in group_sec_vals.values() for s in g})
    if not all_groups or not all_secs:
        return None

    rows = []
    for grp in all_groups:
        row = {"Groupe": grp}
        sec_means = []
        for sec in all_secs:
            vals = group_sec_vals[grp].get(sec, [])
            m = round(sum(vals) / len(vals), 2) if vals else None
            row[sec] = m if m is not None else "—"
            if m is not None:
                sec_means.append(m)
        row["Moyenne composite"] = round(sum(sec_means) / len(sec_means), 2) if sec_means else "—"
        rows.append(row)
    return pd.DataFrame(rows)


def _haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Distance en km entre deux points GPS (Haversine)."""
    R = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi    = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return 2 * R * math.asin(math.sqrt(a))


def register(app):

    # ── Métriques + population des dropdowns ──────────────────────────────────

    @callback(
        Output("ana-n",                   "children"),
        Output("ana-periode",             "children"),
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

        # Période de collecte
        dates = []
        for r in reps:
            try:
                dates.append(
                    datetime.fromisoformat(str(r.get("horodateur", ""))[:19]).date()
                )
            except Exception:
                pass
        if dates:
            periode = f"{min(dates).strftime('%d/%m')}–{max(dates).strftime('%d/%m/%Y')}"
        else:
            periode = "N/A"

        # Complétude globale
        if nb_q and nb_rep:
            total_filled = 0
            for rep in reps:
                try:
                    d = json.loads(rep.get("donnees_json", "{}"))
                    # Compter uniquement les clés numériques (IDs de questions)
                    total_filled += sum(
                        1 for k, v in d.items()
                        if k.lstrip("-").isdigit() and v not in (None, "", [], {})
                    )
                except Exception:
                    pass
            compl = f"{total_filled / (nb_q * nb_rep) * 100:.1f}%"
        else:
            compl = "N/A"

        all_opts   = [{"label": security.sanitize_text(q["texte"], 60), "value": str(q["id"])} for q in questions]
        group_opts = [{"label": security.sanitize_text(q["texte"], 60), "value": str(q["id"])}
                      for q in questions if q.get("role_analytique") in ("group", "indicator", None)]
        sec_opts   = [{"label": security.sanitize_text(s["nom"], 60), "value": str(s["id"])} for s in sections]

        return (
            str(nb_rep), periode, compl, str(nb_q),
            all_opts, all_opts, all_opts, all_opts, all_opts,
            group_opts, group_opts,
            group_opts, sec_opts,
            all_opts, all_opts,
        )

    # ── Filtre global : valeurs disponibles ───────────────────────────────────

    @callback(
        Output("ana-group-filter-val", "options"),
        Output("ana-group-filter-val", "value"),
        Input("ana-quest-select", "value"),
        Input("ana-group-var",    "value"),
    )
    def populate_filter_vals(quest_id, group_var_id):
        if not quest_id or not group_var_id:
            return [], None
        reps = api_client.get_reponses(int(quest_id))
        vals = set()
        for rep in reps:
            try:
                d = json.loads(rep.get("donnees_json", "{}"))
                v = d.get(str(group_var_id))
                if v not in (None, "", []):
                    vals.add(str(v).strip())
            except Exception:
                pass
        opts = [{"label": v, "value": v} for v in sorted(vals)]
        return opts, None

    # ── Tableaux qualité des données ──────────────────────────────────────────

    @callback(
        Output("ana-quality-table",    "columns"),
        Output("ana-quality-table",    "data"),
        Output("ana-completion-table", "columns"),
        Output("ana-completion-table", "data"),
        Input("ana-quest-select",      "value"),
        State("ana-group-var",         "value"),
        State("ana-group-filter-val",  "value"),
    )
    def quality_tables(quest_id, group_var, filter_val):
        no = [], [], [], []
        if not quest_id:
            return no
        data = api_client.get_questionnaire(int(quest_id))
        if "error" in data:
            return no
        questions = data.get("questions", [])
        sections  = data.get("sections",  [])
        reps      = api_client.get_reponses(int(quest_id))
        reps      = _filter_reps(reps, group_var, filter_val)
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
            vals = parse_response_values(reps, q["id"])
            sec_cnt[q.get("section_id")]["filled"] += len(vals)
            sec_cnt[q.get("section_id")]["total"]  += nb_rep

        compl_rows = [
            {"Section":   security.sanitize_text(sec_map.get(sid, "?"), 80),
             "Taux (%)":  f"{c['filled']/c['total']*100:.1f}%" if c["total"] else "N/A",
             "Remplies":  c["filled"],
             "Attendues": c["total"]}
            for sid, c in sec_cnt.items()
        ]
        c_cols = [{"name": c, "id": c} for c in compl_rows[0].keys()] if compl_rows else []
        return q_cols, quality_rows, c_cols, compl_rows

    # ── Graphique univarié + stats descriptives ───────────────────────────────

    @callback(
        Output("ana-single-plot",      "figure"),
        Output("ana-plot-msg",         "children"),
        Output("ana-stats-table",      "columns"),
        Output("ana-stats-table",      "data"),
        Output("ana-stats-card",       "children"),
        Input("ana-quest-select",      "value"),
        Input("ana-plot-var",          "value"),
        Input("ana-plot-type",         "value"),
        State("ana-group-var",         "value"),
        State("ana-group-filter-val",  "value"),
    )
    def single_plot(quest_id, var_id, plot_type, group_var, filter_val):
        if not quest_id or not var_id:
            return (empty_fig("Sélectionnez un questionnaire et une variable."),
                    "", [], [], "")
        reps = api_client.get_reponses(int(quest_id))
        reps = _filter_reps(reps, group_var, filter_val)
        if not reps:
            return empty_fig("Aucune réponse disponible."), "", [], [], ""
        vals = parse_response_values(reps, var_id)
        if not vals:
            return (empty_fig("Aucune valeur pour cette variable."),
                    html.Div("Variable sans réponse.", className="hint"),
                    [], [], "")

        data  = api_client.get_questionnaire(int(quest_id))
        q_map = {str(q["id"]): q["texte"] for q in data.get("questions", [])}
        title = security.sanitize_text(q_map.get(str(var_id), var_id), 80)

        nums = [n for v in vals if (n := _val_to_numeric(v)) is not None]

        # Stats descriptives
        if nums:
            arr = sorted(nums)
            n_n  = len(arr)
            mean = sum(arr) / n_n
            stats_row = {
                "N":          n_n,
                "Min":        round(min(arr), 2),
                "Q1":         round(float(np.percentile(arr, 25)), 2),
                "Médiane":    round(float(np.percentile(arr, 50)), 2),
                "Moyenne":    round(mean, 2),
                "Q3":         round(float(np.percentile(arr, 75)), 2),
                "Max":        round(max(arr), 2),
                "Écart-type": round(float(np.std(arr)), 2),
            }
            stats_cols = [{"name": c, "id": c} for c in stats_row.keys()]
            stats_rows = [stats_row]
            stats_card = html.Div("Statistiques descriptives", className="badge-step mt-2")
        else:
            stats_cols, stats_rows, stats_card = [], [], ""

        if plot_type == "bar":
            fig = bar_chart(vals, title)
        elif plot_type == "pie":
            fig = pie_chart(vals, title)
        elif plot_type == "boxplot":
            fig = (boxplot_chart({"Tous": nums}, title)
                   if nums else empty_fig("Pas de valeurs numériques pour un boxplot."))
        else:  # histogram
            fig = histogram_chart(nums, title) if nums else bar_chart(vals, title)

        return fig, "", stats_cols, stats_rows, stats_card

    # ── Timeline cumulative + objectif de collecte ────────────────────────────

    @callback(
        Output("ana-timeline-plot",    "figure"),
        Input("ana-quest-select",      "value"),
        Input("ana-objectif-input",    "value"),
        State("ana-group-var",         "value"),
        State("ana-group-filter-val",  "value"),
    )
    def timeline_plot(quest_id, objectif, group_var, filter_val):
        if not quest_id:
            return empty_fig()
        reps = api_client.get_reponses(int(quest_id))
        reps = _filter_reps(reps, group_var, filter_val)
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
        counts = [date_counts[d] for d in sd]
        cumul, s = [], 0
        for c in counts:
            s += c
            cumul.append(s)

        fig = go.Figure()
        fig.add_trace(go.Bar(
            x=sd, y=counts,
            name="Réponses / jour",
            marker_color=PALETTE[0],
            opacity=0.7,
            hovertemplate="%{x}: %{y} réponse(s)<extra></extra>",
        ))
        fig.add_trace(go.Scatter(
            x=sd, y=cumul,
            name="Cumul",
            mode="lines+markers",
            line=dict(color=PALETTE[1], width=2),
            marker=dict(size=6),
            yaxis="y2",
            hovertemplate="%{x}: %{y} au total<extra></extra>",
        ))
        if objectif:
            try:
                obj = int(objectif)
                fig.add_shape(
                    type="line",
                    x0=sd[0], x1=sd[-1], y0=obj, y1=obj,
                    line=dict(color="red", width=2, dash="dash"),
                    yref="y2",
                )
                fig.add_annotation(
                    x=sd[-1], y=obj, yref="y2",
                    text=f"Objectif : {obj}",
                    showarrow=False,
                    font=dict(color="red", size=11),
                    xanchor="right",
                )
            except (ValueError, TypeError):
                pass

        fig.update_layout(
            paper_bgcolor="rgba(0,0,0,0)",
            plot_bgcolor="rgba(0,0,0,0)",
            font=dict(family="Segoe UI, Arial, sans-serif", size=12),
            margin=dict(l=40, r=60, t=30, b=60),
            title=dict(text="Évolution temporelle", x=0.02, font=dict(size=14)),
            xaxis=dict(title="Date"),
            yaxis=dict(title="Réponses / jour", showgrid=True),
            yaxis2=dict(title="Cumul", overlaying="y", side="right", showgrid=False),
            legend=dict(orientation="h", y=1.05, x=0),
            barmode="overlay",
        )
        return fig

    # ── Tableau croisé ────────────────────────────────────────────────────────

    @callback(
        Output("ana-crosstab",   "columns"),
        Output("ana-crosstab",   "data"),
        Input("ana-quest-select","value"),
        Input("ana-cross-row",   "value"),
        Input("ana-cross-col",   "value"),
        Input("ana-cross-mode",  "value"),
        State("ana-group-var",        "value"),
        State("ana-group-filter-val", "value"),
    )
    def crosstab(quest_id, row_id, col_id, mode, group_var, filter_val):
        if not quest_id or not row_id or not col_id:
            return [], []
        reps = api_client.get_reponses(int(quest_id))
        reps = _filter_reps(reps, group_var, filter_val)
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
        State("ana-group-var",        "value"),
        State("ana-group-filter-val", "value"),
    )
    def bivariate(quest_id, row_id, col_id, plot_type, alpha, group_var, filter_val):
        if not quest_id or not row_id or not col_id:
            return empty_fig(), "", ""
        reps = api_client.get_reponses(int(quest_id))
        reps = _filter_reps(reps, group_var, filter_val)
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
            fig.update_layout(barmode="stack",
                               paper_bgcolor="rgba(0,0,0,0)",
                               plot_bgcolor="rgba(0,0,0,0)")
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

    # ── Profils (valeurs réelles — Likert/num., plus complétude) ─────────────

    @callback(
        Output("ana-profile-summary", "columns"),
        Output("ana-profile-summary", "data"),
        Output("ana-profile-heatmap", "figure"),
        Output("ana-profile-radar",   "figure"),
        Input("ana-quest-select",     "value"),
        Input("ana-profile-group",    "value"),
        State("ana-group-var",        "value"),
        State("ana-group-filter-val", "value"),
    )
    def profiles(quest_id, group_var_id, gfilter_var, gfilter_val):
        no = [], [], empty_fig(), empty_fig()
        if not quest_id or not group_var_id:
            return no
        data = api_client.get_questionnaire(int(quest_id))
        if "error" in data:
            return no
        reps      = api_client.get_reponses(int(quest_id))
        reps      = _filter_reps(reps, gfilter_var, gfilter_val)
        questions = data.get("questions", [])
        sections  = data.get("sections",  [])
        if not reps:
            return no
        sec_map = {s["id"]: security.sanitize_text(s["nom"], 40) for s in sections}
        ind_qs  = [q for q in questions if q.get("role_analytique") == "indicator"]
        if not ind_qs:
            return [], [], empty_fig("Aucune variable indicateur."), empty_fig()

        scores: dict[str, dict[str, list[float]]] = defaultdict(lambda: defaultdict(list))
        for rep in reps:
            try:
                d = json.loads(rep.get("donnees_json", "{}"))
            except Exception:
                continue
            grp = str(d.get(str(group_var_id), "")).strip()
            if not grp:
                continue
            for q in ind_qs:
                num = _val_to_numeric(d.get(str(q["id"])))
                if num is not None:
                    sec_nom = sec_map.get(q.get("section_id"), "?")
                    scores[grp][sec_nom].append(num)

        groups   = sorted(scores)[:10]
        sec_noms = sorted({s for g in scores.values() for s in g})
        if not groups or not sec_noms:
            return [], [], empty_fig("Aucune valeur Likert/numérique trouvée."), empty_fig()

        z_matrix, y_labels = [], []
        for grp in groups:
            row_z = []
            for s in sec_noms:
                vals = scores[grp].get(s, [])
                row_z.append(round(sum(vals) / len(vals), 2) if vals else 0)
            z_matrix.append(row_z)
            y_labels.append(security.sanitize_text(grp, 40))

        heat = heatmap_chart(z_matrix, [security.sanitize_text(s, 40) for s in sec_noms],
                             y_labels, "Moyenne par groupe × section")

        radar_data = {}
        for g in groups:
            vals_list = [sum(scores[g].get(s, [])) / len(scores[g].get(s, [1])) for s in sec_noms]
            radar_data[security.sanitize_text(g, 40)] = vals_list
        rad = radar_chart([security.sanitize_text(s, 40) for s in sec_noms],
                          radar_data, "Profil des groupes")

        summary_rows = []
        for g in groups:
            all_vals = [v for vals in scores[g].values() for v in vals]
            summary_rows.append({
                "Groupe":          security.sanitize_text(g, 60),
                "Moyenne globale": round(sum(all_vals) / len(all_vals), 2) if all_vals else "—",
            })
        s_cols = [{"name": c, "id": c} for c in summary_rows[0].keys()] if summary_rows else []
        return s_cols, summary_rows, heat, rad

    # ── Corrélations ─────────────────────────────────────────────────────────

    @callback(
        Output("ana-corr-heatmap", "figure"),
        Output("ana-corr-table",   "columns"),
        Output("ana-corr-table",   "data"),
        Input("ana-quest-select",  "value"),
        State("ana-group-var",        "value"),
        State("ana-group-filter-val", "value"),
    )
    def correlations(quest_id, group_var, filter_val):
        no = empty_fig("Sélectionnez un questionnaire."), [], []
        if not quest_id:
            return no
        data = api_client.get_questionnaire(int(quest_id))
        if "error" in data:
            return no
        reps      = api_client.get_reponses(int(quest_id))
        reps      = _filter_reps(reps, group_var, filter_val)
        questions = data.get("questions", [])
        if not reps:
            return empty_fig("Aucune réponse."), [], []

        df_num, labels = _build_numeric_matrix(reps, questions)
        if df_num.empty or df_num.shape[1] < 2:
            return empty_fig("Pas assez d'indicateurs numériques (min 2)."), [], []
        df_num = df_num.dropna(axis=1, how="all")
        if df_num.shape[1] < 2:
            return empty_fig("Pas assez de valeurs numériques exploitables."), [], []

        corr = df_num.corr(numeric_only=True)
        lbls = [labels.get(c, c)[:28] for c in corr.columns]

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
        top30  = pairs[:30]
        t_cols = [{"name": c, "id": c} for c in ["Indicateur 1", "Indicateur 2", "Corrélation", "Force"]]
        return fig, t_cols, top30

    # ── Scores composites (valeurs réelles) ───────────────────────────────────

    @callback(
        Output("ana-composite-table", "columns"),
        Output("ana-composite-table", "data"),
        Output("ana-composite-plot",  "figure"),
        Input("ana-quest-select",       "value"),
        Input("ana-composite-group",    "value"),
        Input("ana-composite-sections", "value"),
        State("ana-group-var",          "value"),
        State("ana-group-filter-val",   "value"),
    )
    def composite_scores(quest_id, group_var_id, section_ids, gfilter_var, gfilter_val):
        no = [], [], empty_fig("Sélectionnez un questionnaire et un groupe.")
        if not quest_id or not group_var_id:
            return no
        data      = api_client.get_questionnaire(int(quest_id))
        if "error" in data:
            return no
        reps      = api_client.get_reponses(int(quest_id))
        reps      = _filter_reps(reps, gfilter_var, gfilter_val)
        questions = data.get("questions", [])
        sections  = data.get("sections",  [])
        if not reps:
            return [], [], empty_fig("Aucune réponse.")

        df = _build_response_means(reps, questions, sections, group_var_id, section_ids)
        if df is None or df.empty:
            return [], [], empty_fig("Aucune valeur Likert/numérique — vérifiez les indicateurs.")

        cols = [{"name": c, "id": c} for c in df.columns]
        rows = df.to_dict("records")

        composite_vals = df["Moyenne composite"].tolist()
        y_vals = [v if isinstance(v, (int, float)) else 0 for v in composite_vals]
        texts  = [f"{v:.2f}" if isinstance(v, float) else "—" for v in composite_vals]

        fig = go.Figure(go.Bar(
            x=df["Groupe"].tolist(),
            y=y_vals,
            marker_color="#245c7c",
            text=texts,
            textposition="outside",
        ))
        fig.update_layout(
            yaxis={"title": "Moyenne composite"},
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
        State("ana-group-var",          "value"),
        State("ana-group-filter-val",   "value"),
    )
    def logistic_regression(quest_id, outcome_id, predictor_ids, group_var, filter_val):
        no = [], [], ""
        if not quest_id or not outcome_id or not predictor_ids:
            return no
        data = api_client.get_questionnaire(int(quest_id))
        if "error" in data:
            return no
        reps      = api_client.get_reponses(int(quest_id))
        reps      = _filter_reps(reps, group_var, filter_val)
        questions = data.get("questions", [])
        if not reps:
            return [], [], "Aucune réponse disponible."

        q_map    = {str(q["id"]): security.sanitize_text(q["texte"], 60) for q in questions}
        pred_ids = [p for p in predictor_ids if p != outcome_id]
        if not pred_ids:
            return [], [], "Ajoutez au moins un prédicteur différent de la cible."

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
        n_obs  = len(df)
        groups = df[outcome_id].unique().tolist()
        info   = f"Observations exploitables : {n_obs}\nGroupes cible : {' / '.join(str(g) for g in groups)}"

        if n_obs < 20:
            return [], [], info + "\n⚠ Effectif insuffisant (min 20)."
        if len(groups) != 2:
            return [], [], info + f"\n⚠ La variable cible doit avoir 2 modalités (trouvé : {len(groups)})."

        try:
            import statsmodels.api as sm
            y = (df[outcome_id] == groups[1]).astype(int)
            X_parts = []
            for pid in pred_ids:
                dummies = pd.get_dummies(df[pid], prefix=q_map.get(pid, pid)[:20], drop_first=True)
                X_parts.append(dummies)
            if not X_parts:
                return [], [], info + "\nAucun prédicteur valide."
            X = sm.add_constant(pd.concat(X_parts, axis=1).astype(float))
            model  = sm.Logit(y, X).fit(disp=False)
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
                        or_ = (a * d) / (b * c)
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
            return cols, table_rows, info + "\n(statsmodels non installé — OR bruts 2×2)"

        except Exception as e:
            return [], [], info + f"\nErreur : {type(e).__name__}: {e}"

    # ── Carte GPS analytique ──────────────────────────────────────────────────

    @callback(
        Output("ana-analytics-map", "figure"),
        Output("ana-map-card",      "children"),
        Input("ana-quest-select",   "value"),
        Input("ana-map-color-var",  "value"),
        State("ana-group-var",        "value"),
        State("ana-group-filter-val", "value"),
        State("store-licence-key",    "data"),
    )
    def analytics_map(quest_id, color_var_id, group_var, filter_val, licence):
        if not security.is_premium(licence):
            return empty_fig("🔒 Carte GPS — fonctionnalité Pro"), html.Div(
                "La carte GPS est disponible avec la licence annuelle. "
                "Rendez-vous dans l'onglet Plan.",
                className="hint",
            )
        if not quest_id:
            return empty_fig("Sélectionnez un questionnaire."), ""
        reps = api_client.get_reponses(int(quest_id))
        reps = _filter_reps(reps, group_var, filter_val)
        if not reps:
            return empty_fig("Aucune réponse."), ""

        _lat_keys = ("_latitude", "_gps_lat", "gps_lat", "latitude", "lat")
        _lon_keys = ("_longitude", "_gps_lon", "gps_lon", "longitude", "lon")
        lats, lons, colors, texts = [], [], [], []
        for rep in reps:
            try:
                d = json.loads(rep.get("donnees_json", "{}"))
            except Exception:
                continue
            lat = next((d[k] for k in _lat_keys if k in d), None)
            lon = next((d[k] for k in _lon_keys if k in d), None)
            if lat is None or lon is None:
                continue
            try:
                lat, lon = float(lat), float(lon)
            except (ValueError, TypeError):
                continue
            if not (-90 <= lat <= 90) or not (-180 <= lon <= 180):
                continue
            lats.append(lat)
            lons.append(lon)
            cv = str(d.get(str(color_var_id), "")) if color_var_id else "•"
            colors.append(cv if cv else "•")
            ts = rep.get("horodateur", "")
            texts.append(f"Date : {ts[:10] if ts else '?'}")

        if not lats:
            hint = html.Div(
                "💡 Aucune coordonnée GPS trouvée. Activez la capture GPS dans le formulaire.",
                className="hint",
            )
            return empty_fig("Aucun point GPS disponible."), hint

        color_cats = sorted(set(colors))
        fig = go.Figure()
        for i, cat in enumerate(color_cats):
            idxs = [j for j, c in enumerate(colors) if c == cat]
            fig.add_trace(go.Scattermapbox(
                lat=[lats[j] for j in idxs],
                lon=[lons[j] for j in idxs],
                mode="markers",
                marker=dict(size=10, color=PALETTE[i % len(PALETTE)]),
                name=security.sanitize_text(cat, 40),
                text=[texts[j] for j in idxs],
                hovertemplate="%{text}<extra>%{fullData.name}</extra>",
            ))
        center_lat = sum(lats) / len(lats)
        center_lon = sum(lons) / len(lons)
        fig.update_layout(
            mapbox=dict(
                style="open-street-map",
                center=dict(lat=center_lat, lon=center_lon),
                zoom=8,
            ),
            margin=dict(l=0, r=0, t=0, b=0),
            paper_bgcolor="rgba(0,0,0,0)",
            showlegend=True,
            legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1),
        )
        card = html.Div(
            f"📍 {len(lats)} point(s) GPS — {len(color_cats)} modalité(s)",
            className="hint",
        )
        return fig, card

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
        return (dict(content=df.to_csv(index=False), filename=fname, type="text/csv"),
                html.Div("Export terminé.", className="alert-success"))

    # ── Export dataset Excel ──────────────────────────────────────────────────

    @callback(
        Output("download-analytics-xlsx", "data"),
        Output("ana-export-msg",          "children", allow_duplicate=True),
        Input("btn-export-analytics-xlsx","n_clicks"),
        State("ana-quest-select",         "value"),
        prevent_initial_call=True,
    )
    def export_dataset_xlsx(n_clicks, quest_id):
        import io, base64
        if not n_clicks or not quest_id:
            return no_update, no_update
        rows = api_client.get_reponses_wide(int(quest_id))
        if not rows:
            return no_update, html.Div("Aucune donnée.", className="alert-warn")
        df = pd.DataFrame(rows)
        buf = io.BytesIO()
        with pd.ExcelWriter(buf, engine="openpyxl") as writer:
            df.to_excel(writer, index=False, sheet_name="Dataset")
        buf.seek(0)
        b64 = base64.b64encode(buf.read()).decode()
        fname = f"dataset_{quest_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx"
        return (dict(content=b64, filename=fname, base64=True,
                     type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"),
                html.Div("Export Excel terminé.", className="alert-success"))

    # ── Export scores composites CSV ──────────────────────────────────────────

    @callback(
        Output("download-scores-csv",   "data"),
        Output("ana-export-msg",        "children", allow_duplicate=True),
        Input("btn-export-scores-csv",  "n_clicks"),
        State("ana-quest-select",       "value"),
        State("ana-composite-group",    "value"),
        State("ana-composite-sections", "value"),
        State("ana-group-var",          "value"),
        State("ana-group-filter-val",   "value"),
        prevent_initial_call=True,
    )
    def export_scores_csv(n_clicks, quest_id, group_var_id, section_ids, gfilter_var, gfilter_val):
        if not n_clicks or not quest_id:
            return no_update, no_update
        data      = api_client.get_questionnaire(int(quest_id))
        reps      = api_client.get_reponses(int(quest_id))
        reps      = _filter_reps(reps, gfilter_var, gfilter_val)
        questions = data.get("questions", [])
        sections  = data.get("sections",  [])
        df = _build_response_means(reps, questions, sections, group_var_id or "", section_ids)
        if df is None or df.empty:
            return no_update, html.Div(
                "Scores vides — configurez d'abord l'onglet Scores composites.",
                className="alert-warn",
            )
        fname = f"scores_{quest_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
        return (dict(content=df.to_csv(index=False), filename=fname, type="text/csv"),
                html.Div("Export scores terminé.", className="alert-success"))

    # ── Qualité terrain : dropdown enquêteur ──────────────────────────────────

    @callback(
        Output("ana-qual-enqueteur-var", "options"),
        Input("ana-quest-select", "value"),
    )
    def populate_qual_enqueteur(quest_id):
        if not quest_id:
            return []
        data = api_client.get_questionnaire(int(quest_id))
        if "error" in data:
            return []
        return [{"label": security.sanitize_text(q["texte"], 60), "value": str(q["id"])}
                for q in data.get("questions", [])]

    # ── Qualité terrain : analyse des enquêteurs ──────────────────────────────

    @callback(
        Output("qual-n-suspects",       "children"),
        Output("qual-n-sl",             "children"),
        Output("qual-n-fast",           "children"),
        Output("qual-n-geo",            "children"),
        Output("ana-qual-table",        "columns"),
        Output("ana-qual-table",        "data"),
        Output("ana-qual-plot",         "figure"),
        Input("btn-qual-analyse",       "n_clicks"),
        State("ana-quest-select",       "value"),
        State("ana-qual-enqueteur-var", "value"),
        State("ana-qual-min-duration",  "value"),
        State("ana-group-var",          "value"),
        State("ana-group-filter-val",   "value"),
        prevent_initial_call=True,
    )
    def enumerator_quality(n_clicks, quest_id, enq_var_id, min_duration, group_var, filter_val):
        no = "—", "—", "—", "—", [], [], empty_fig()
        if not quest_id:
            return no
        data = api_client.get_questionnaire(int(quest_id))
        if "error" in data:
            return no
        reps      = api_client.get_reponses(int(quest_id))
        reps      = _filter_reps(reps, group_var, filter_val)
        questions = data.get("questions", [])
        if not reps:
            return no

        likert_ids = {str(q["id"]) for q in questions if q.get("type") == "likert"}
        _lat_keys  = ("_latitude", "_gps_lat", "gps_lat", "latitude", "lat")
        _lon_keys  = ("_longitude", "_gps_lon", "gps_lon", "longitude", "lon")

        # ── Parse chaque réponse ──────────────────────────────────────────────
        parsed = []
        for rep in reps:
            try:
                d = json.loads(rep.get("donnees_json", "{}"))
            except Exception:
                d = {}
            enq = str(d.get(str(enq_var_id), "INCONNU")).strip() if enq_var_id else "INCONNU"

            # Straight-lining : ≥ 3 Likert toutes identiques
            lk_vals = [str(d.get(k, "")).strip().lower()
                       for k in likert_ids if d.get(k) not in (None, "", [])]
            sl = len(lk_vals) >= 3 and len(set(lk_vals)) == 1

            lat = next((d[k] for k in _lat_keys if k in d), None)
            lon = next((d[k] for k in _lon_keys if k in d), None)
            try:
                lat, lon = float(lat), float(lon)
                if not (-90 <= lat <= 90) or not (-180 <= lon <= 180):
                    lat = lon = None
            except (TypeError, ValueError):
                lat = lon = None

            ts_str = rep.get("horodateur", "")
            try:
                ts = datetime.fromisoformat(str(ts_str)[:19])
            except Exception:
                ts = None

            parsed.append({
                "id":              rep.get("id"),
                "enqueteur":       enq,
                "horodateur":      ts,
                "horodateur_str":  ts_str[:16] if ts_str else "?",
                "straight_lining": sl,
                "lat":             lat,
                "lon":             lon,
            })

        # ── Trop rapide : intervalle inter-soumissions par enquêteur ─────────
        min_dur_sec = (int(min_duration) * 60) if min_duration else 300
        by_enq = defaultdict(list)
        for p in parsed:
            if p["horodateur"] is not None:
                by_enq[p["enqueteur"]].append(p)
        fast_ids: set = set()
        for _, grp in by_enq.items():
            sg = sorted(grp, key=lambda x: x["horodateur"])
            for i in range(1, len(sg)):
                dt = (sg[i]["horodateur"] - sg[i - 1]["horodateur"]).total_seconds()
                if 0 < dt < min_dur_sec:
                    fast_ids.add(sg[i]["id"])
                    fast_ids.add(sg[i - 1]["id"])

        # ── GPS aberrant : distance > centroïde + 2σ ──────────────────────────
        gps_pts = [(p["id"], p["lat"], p["lon"]) for p in parsed if p["lat"] is not None]
        geo_ids: set = set()
        if len(gps_pts) >= 5:
            c_lat = sum(x[1] for x in gps_pts) / len(gps_pts)
            c_lon = sum(x[2] for x in gps_pts) / len(gps_pts)
            dists = [_haversine(lat, lon, c_lat, c_lon) for _, lat, lon in gps_pts]
            mean_d = sum(dists) / len(dists)
            std_d  = (sum((d - mean_d) ** 2 for d in dists) / len(dists)) ** 0.5
            for (rid, _, _), dist in zip(gps_pts, dists):
                if dist > mean_d + 2 * std_d:
                    geo_ids.add(rid)

        # ── Tableau ───────────────────────────────────────────────────────────
        rows = []
        for p in parsed:
            flags = []
            if p["straight_lining"]:     flags.append("Straight-lining")
            if p["id"] in fast_ids:      flags.append("Trop rapide")
            if p["id"] in geo_ids:       flags.append("GPS aberrant")
            rows.append({
                "ID":          p["id"],
                "Enquêteur":   security.sanitize_text(p["enqueteur"], 40),
                "Horodateur":  p["horodateur_str"],
                "Signaux":     len(flags),
                "Détails":     ", ".join(flags) if flags else "OK",
            })
        rows.sort(key=lambda x: x["Signaux"], reverse=True)
        cols = [{"name": c, "id": c} for c in ["ID", "Enquêteur", "Horodateur", "Signaux", "Détails"]]

        n_sl   = sum(1 for p in parsed if p["straight_lining"])
        n_fast = len(fast_ids)
        n_geo  = len(geo_ids)
        n_susp = sum(1 for r in rows if r["Signaux"] > 0)

        # ── Graphique : signaux par enquêteur ─────────────────────────────────
        enq_signals = defaultdict(int)
        for r in rows:
            enq_signals[r["Enquêteur"]] += r["Signaux"]
        enqs = sorted(enq_signals, key=lambda e: enq_signals[e], reverse=True)[:15]
        bar_colors = ["#ef4444" if enq_signals[e] > 2 else
                      ("#f59e0b" if enq_signals[e] > 0 else "#2ca02c") for e in enqs]
        fig = go.Figure(go.Bar(
            x=enqs,
            y=[enq_signals[e] for e in enqs],
            marker_color=bar_colors,
            hovertemplate="%{x}: %{y} signaux<extra></extra>",
        ))
        fig.update_layout(
            paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)",
            title=dict(text="Signaux par enquêteur", x=0.02, font=dict(size=13)),
            xaxis=dict(title="", tickangle=-30),
            yaxis=dict(title="Signaux"),
            margin=dict(l=40, r=20, t=40, b=80),
        )
        return str(n_susp), str(n_sl), str(n_fast), str(n_geo), cols, rows, fig

    # ── IA textes : population dropdown questions texte ───────────────────────

    @callback(
        Output("ia-text-var", "options"),
        Input("ana-quest-select", "value"),
    )
    def populate_ia_text_vars(quest_id):
        if not quest_id:
            return []
        data = api_client.get_questionnaire(int(quest_id))
        if "error" in data:
            return []
        return [{"label": security.sanitize_text(q["texte"], 60), "value": str(q["id"])}
                for q in data.get("questions", [])
                if q.get("type") in ("text", "textarea")]

    # ── IA : résumé + recommandations ─────────────────────────────────────────

    @callback(
        Output("ia-summary-card",     "children"),
        Output("ia-api-key-warn",     "children"),
        Input("btn-ia-analyse",       "n_clicks"),
        State("ana-quest-select",     "value"),
        State("ana-group-var",        "value"),
        State("ana-group-filter-val", "value"),
        State("store-licence-key",    "data"),
        prevent_initial_call=True,
    )
    def ia_analyse(n_clicks, quest_id, group_var, filter_val, licence):
        if not quest_id:
            return "", html.Div("Sélectionnez d'abord un questionnaire.", className="hint")
        if not security.is_premium(licence):
            return "", html.Div(
                "🔒 Analyse IA — fonctionnalité Pro. Rendez-vous dans l'onglet Plan.",
                className="alert-warn",
            )
        import os
        api_key = os.environ.get("ANTHROPIC_API_KEY", "") or (api_client.get_config("anthropic_api_key") or "")
        if not api_key:
            return "", html.Div(
                "⚠ Clé Anthropic non configurée — renseignez-la dans l'onglet Admin.",
                className="alert-warn",
            )
        try:
            import anthropic as _ant
        except ImportError:
            return "", html.Div(
                "⚠ Package 'anthropic' non installé — lancez : pip install anthropic",
                className="alert-warn",
            )

        data = api_client.get_questionnaire(int(quest_id))
        if "error" in data:
            return "", html.Div("Erreur de chargement du questionnaire.", className="alert-warn")

        reps      = api_client.get_reponses(int(quest_id))
        reps      = _filter_reps(reps, group_var, filter_val)
        questions = data.get("questions", [])
        sections  = data.get("sections",  [])
        nb_rep  = len(reps)
        nb_q    = len(questions)
        nb_ind  = sum(1 for q in questions if q.get("role_analytique") == "indicator")
        nb_text = sum(1 for q in questions if q.get("type") in ("text", "textarea"))

        if not nb_rep:
            return "", html.Div("Aucune réponse à analyser.", className="hint")

        filled = 0
        for r in reps:
            try:
                d = json.loads(r.get("donnees_json", "{}"))
                filled += sum(
                    1 for k, v in d.items()
                    if k.lstrip("-").isdigit() and v not in (None, "", [], {})
                )
            except Exception:
                pass
        compl_pct = filled / (nb_q * nb_rep) * 100 if nb_q and nb_rep else 0
        compl = f"{compl_pct:.1f}%"

        sec_map   = {s["id"]: security.sanitize_text(s["nom"], 40) for s in sections}
        quest_nom = security.sanitize_text(data.get("nom", "Sans titre"), 80)

        # ── Stats par question — limitées à 40 questions et 4 valeurs top ──
        distrib_lines = []
        for q in questions[:40]:
            vals = parse_response_values(reps, q["id"])
            if not vals:
                continue
            n       = len(vals)
            sec_nom = sec_map.get(q.get("section_id"), "")
            label   = security.sanitize_text(q["texte"], 55)
            qtype   = q.get("type", "?")
            nums    = [x for v in vals if (x := _val_to_numeric(v)) is not None]
            top     = Counter(vals).most_common(4)
            top_str = ", ".join(f'"{v}":{c}({c/n*100:.0f}%)' for v, c in top)
            line    = f"[{qtype}]{f' [{sec_nom}]' if sec_nom else ''} {label} (N={n}/{nb_rep})\n  top: {top_str}"
            if nums:
                mean_n = sum(nums) / len(nums)
                std_n  = (sum((x - mean_n) ** 2 for x in nums) / len(nums)) ** 0.5
                line  += f"\n  stats: min={min(nums):.2f}, moy={mean_n:.2f}, max={max(nums):.2f}, σ={std_n:.2f}"
            distrib_lines.append(line)
        skipped = max(0, len(questions) - 40)
        suffix  = f"\n\n[{skipped} questions supplémentaires non affichées — enquête volumineuse]" if skipped else ""
        distrib_text = "\n\n".join(distrib_lines) + suffix or "Aucune distribution calculable."

        # ── Répartition des groupes ───────────────────────────────────────
        group_section = ""
        if group_var:
            gcounts = Counter()
            for rep in reps:
                try:
                    d = json.loads(rep.get("donnees_json", "{}"))
                    v = d.get(str(group_var))
                    if v not in (None, "", []):
                        gcounts[str(v).strip()] += 1
                except Exception:
                    pass
            if gcounts:
                gvar_label = next((security.sanitize_text(q["texte"], 60)
                                   for q in questions if str(q["id"]) == str(group_var)), str(group_var))
                group_section = (
                    f"\nVariable de groupe : {gvar_label}\n"
                    + "\n".join(f"  - {g}: {c} ({c/nb_rep*100:.0f}%)" for g, c in gcounts.most_common())
                )

        # ── Tendance temporelle ───────────────────────────────────────────
        date_counts = Counter()
        for r in reps:
            try:
                d_str = str(r.get("horodateur", ""))[:10]
                datetime.fromisoformat(d_str)
                date_counts[d_str] += 1
            except Exception:
                pass
        timeline_section = ""
        if date_counts:
            sorted_dates = sorted(date_counts)
            peak_date    = max(date_counts, key=date_counts.get)
            cum, trend50 = 0, sorted_dates[-1]
            for d in sorted_dates:
                cum += date_counts[d]
                if cum >= nb_rep / 2:
                    trend50 = d
                    break
            timeline_section = (
                f"\nTemporalité : {sorted_dates[0]} → {sorted_dates[-1]} "
                f"({len(sorted_dates)} jours de collecte)\n"
                f"Pic : {peak_date} ({date_counts[peak_date]} réponses) | 50% atteint le {trend50}"
            )

        prompt = f"""Tu es un statisticien expert en analyse d'enquêtes terrain pour organisations humanitaires et ONG.

## Questionnaire analysé
Titre : {quest_nom}
Répondants : {nb_rep} | Complétude : {compl} ({compl_pct:.0f}%)
Structure : {nb_q} questions ({nb_ind} indicateurs, {nb_text} textes libres, {len(sections)} sections){group_section}{timeline_section}

## Données détaillées par question
{distrib_text}

## Tâche
Présente l'état factuel des résultats. Pas de recommandations — ce rôle appartient au coordinateur.
Réponds UNIQUEMENT en JSON valide (sans markdown) :

{{
  "vue_ensemble": "4-5 phrases factuelles : population couverte, taux de participation, tendances dominantes observées dans les données",
  "points_saillants": [
    {{"constat": "fait précis tiré des données", "valeur": "chiffre ou % cité"}}
  ],
  "signaux_surveillance": [
    {{"constat": "donnée manquante, valeur atypique ou faible participation constatée", "contexte": "question ou section concernée"}}
  ],
  "patterns_statistiques": [
    {{"variable": "nom court de la question", "observation": "distribution, corrélation ou écart notable", "lecture": "ce que les données montrent"}}
  ],
  "qualite_donnees": {{
    "note": "A|B|C|D",
    "points": ["point méthodologique positif"],
    "limites": ["limite ou biais potentiel identifié dans les données"]
  }}
}}

Règles : max 4 points_saillants, 4 signaux_surveillance, 5 patterns_statistiques. Cite des chiffres précis. Reste factuel, sans jugement de valeur ni conseil d'action. Français, ton neutre et professionnel."""

        try:
            msg = _ant.Anthropic(api_key=api_key).messages.create(
                model="claude-sonnet-4-6",
                max_tokens=4096,
                system="Tu es un statisticien expert en enquêtes terrain pour ONG. Réponds UNIQUEMENT avec un objet JSON valide, sans texte ni balises markdown autour.",
                messages=[{"role": "user", "content": prompt}],
            )
            if msg.stop_reason == "max_tokens":
                return html.Div(
                    "Enquête trop volumineuse — réponse tronquée. Réduisez le nombre de questions ou de répondants.",
                    className="alert-warn"
                ), ""
            result = _extract_json(msg.content[0].text)
        except (json.JSONDecodeError, ValueError) as e:
            return html.Div(f"Erreur de parsing JSON dans la réponse IA : {e}", className="alert-warn"), ""
        except Exception as e:
            return "", html.Div(f"Erreur API : {type(e).__name__}: {e}", className="alert-warn")

        # ── Rendu UI ──────────────────────────────────────────────────────
        qc         = result.get("qualite_donnees", {})
        note       = qc.get("note", "B")
        note_color = {"A": "#057a55", "B": "#2563eb", "C": "#d97706", "D": "#dc2626"}.get(note, "#6b7785")

        saillants_items = [
            html.Div(className="d-flex align-items-start gap-2 mb-2", children=[
                html.Span("◆", style={"fontSize": "14px", "color": "#245c7c", "flexShrink": "0"}),
                html.Div([
                    html.Span(p.get("constat", ""), style={"fontSize": "14px"}),
                    html.Span(f" — {p.get('valeur', '')}",
                              style={"color": "#245c7c", "fontWeight": "600", "fontSize": "13px"}),
                ]),
            ])
            for p in result.get("points_saillants", [])
        ]
        signaux_items = [
            html.Div(className="d-flex align-items-start gap-2 mb-2", children=[
                html.Span("◈", style={"fontSize": "14px", "color": "#d97706", "flexShrink": "0"}),
                html.Div([
                    html.Span(p.get("constat", ""), style={"fontSize": "14px"}),
                    html.P(p.get("contexte", ""),
                           style={"fontSize": "12px", "color": "#6b7785", "margin": "2px 0 0"}),
                ]),
            ])
            for p in result.get("signaux_surveillance", [])
        ]
        pattern_items = [
            html.Div(className="mb-3",
                     style={"borderLeft": "3px solid #e6a700", "paddingLeft": "12px"}, children=[
                html.Strong(i.get("variable", ""), style={"fontSize": "13px", "color": "#16324f"}),
                html.P(i.get("observation", ""), style={"margin": "2px 0", "fontSize": "14px"}),
                html.Small(i.get("lecture", ""), style={"color": "#6b7785"}),
            ])
            for i in result.get("patterns_statistiques", [])
        ]

        summary_ui = [
            html.Div(className="card", children=[
                html.Div(className="d-flex align-items-center gap-3 mb-2", children=[
                    html.Span("Vue d'ensemble", className="badge-step"),
                    html.Span([
                        html.Span("Qualité données : ", style={"fontSize": "12px", "color": "#6b7785"}),
                        html.Span(f"Note {note}",
                                  style={"fontSize": "14px", "fontWeight": "800", "color": note_color}),
                    ]),
                ]),
                html.P(result.get("vue_ensemble", ""),
                       style={"lineHeight": "1.75", "color": "#1f2933", "fontSize": "14px"}),
            ]),
            html.Div(className="row g-3", children=[
                html.Div(className="col-md-6", children=[
                    html.Div(className="card h-100", children=[
                        html.Span("Points saillants", className="badge-step"),
                        html.Div(saillants_items, className="mt-2"),
                    ]),
                ]),
                html.Div(className="col-md-6", children=[
                    html.Div(className="card h-100", children=[
                        html.Span("Signaux à surveiller", className="badge-step"),
                        html.Div(signaux_items, className="mt-2"),
                    ]),
                ]),
            ]),
            html.Div(className="card", children=[
                html.Span("Patterns statistiques", className="badge-step"),
                html.Div(pattern_items, className="mt-3"),
            ]) if pattern_items else html.Div(),
            html.Div(className="card", children=[
                html.Span("Qualité des données", className="badge-step"),
                html.Div(className="row mt-2", children=[
                    html.Div(className="col-md-6", children=[
                        html.Strong("Points méthodologiques", style={"fontSize": "13px"}),
                        html.Ul([html.Li(p, style={"fontSize": "13px"}) for p in qc.get("points", [])],
                                className="mt-1"),
                    ]),
                    html.Div(className="col-md-6", children=[
                        html.Strong("Limites & biais potentiels", style={"fontSize": "13px"}),
                        html.Ul([html.Li(r, style={"fontSize": "13px"}) for r in qc.get("limites", [])],
                                className="mt-1"),
                    ]),
                ]),
            ]),
            html.Small(
                f"État des résultats généré avec claude-sonnet-4-6 · {nb_rep} réponses · {nb_q} questions",
                style={"color": "#9aa5b1", "display": "block", "textAlign": "right", "marginTop": "4px"},
            ),
        ]
        return summary_ui, ""

    # ── IA : analyse texte libre par question ─────────────────────────────────

    @callback(
        Output("ia-text-result",      "children"),
        Input("btn-ia-text-analyse",  "n_clicks"),
        State("ana-quest-select",     "value"),
        State("ia-text-var",          "value"),
        State("ana-group-var",        "value"),
        State("ana-group-filter-val", "value"),
        State("store-licence-key",    "data"),
        prevent_initial_call=True,
    )
    def ia_text_analyse(n_clicks, quest_id, var_id, group_var, filter_val, licence):
        if not quest_id or not var_id:
            return html.Div("Sélectionnez une question texte.", className="hint")
        if not security.is_premium(licence):
            return html.Div(
                "🔒 Analyse IA — fonctionnalité Pro. Rendez-vous dans l'onglet Plan.",
                className="alert-warn",
            )

        import os
        api_key = os.environ.get("ANTHROPIC_API_KEY", "") or (api_client.get_config("anthropic_api_key") or "")
        if not api_key:
            return html.Div(
                "⚠ Clé Anthropic non configurée — renseignez-la dans l'onglet Admin.",
                className="alert-warn",
            )
        try:
            import anthropic as _ant
        except ImportError:
            return html.Div("⚠ pip install anthropic", className="alert-warn")

        reps      = api_client.get_reponses(int(quest_id))
        reps      = _filter_reps(reps, group_var, filter_val)
        text_vals = [v for v in parse_response_values(reps, var_id) if len(v.strip()) > 3]
        if not text_vals:
            return html.Div("Aucune réponse texte non vide pour cette variable.", className="hint")

        data    = api_client.get_questionnaire(int(quest_id))
        q_map   = {str(q["id"]): q["texte"] for q in data.get("questions", [])}
        q_texte = security.sanitize_text(q_map.get(str(var_id), var_id), 100)
        sample  = text_vals[:150]
        resp_block = "\n".join(f"- {security.sanitize_text(v, 200)}" for v in sample)

        prompt = (
            f'Analyse les {len(text_vals)} réponses ouvertes à : "{q_texte}"\n'
            f"(échantillon : {len(sample)} réponses)\n\n"
            f"Réponses :\n{resp_block}\n\n"
            f"Réponds UNIQUEMENT en JSON valide (sans markdown) :\n"
            f'{{\n'
            f'  "themes": ["thème 1", ...],\n'
            f'  "sentiment": "positif|négatif|mitigé|neutre",\n'
            f'  "resume": "2-3 phrases synthèse",\n'
            f'  "mots_cles": ["mot1", ...],\n'
            f'  "points_attention": ["point 1", ...]\n'
            f'}}\n'
            f"En français. Thèmes contextualisés terrain/humanitaire si pertinent."
        )

        try:
            msg = _ant.Anthropic(api_key=api_key).messages.create(
                model="claude-sonnet-4-6",
                max_tokens=1500,
                system="Tu es un analyste spécialisé en enquêtes terrain pour ONG. Réponds UNIQUEMENT avec un objet JSON valide, sans texte ni balises markdown autour.",
                messages=[{"role": "user", "content": prompt}],
            )
            result = _extract_json(msg.content[0].text)
        except (json.JSONDecodeError, ValueError) as e:
            return html.Div(f"Erreur de parsing JSON dans la réponse IA : {e}", className="alert-warn")
        except Exception as e:
            return html.Div(f"Erreur API : {type(e).__name__}: {e}", className="alert-warn")

        sent = result.get("sentiment", "neutre")
        sent_color = {"positif": "#057a55", "négatif": "#dc2626",
                      "mitigé": "#d97706", "neutre": "#6b7785"}.get(sent, "#6b7785")

        return html.Div([
            html.Div(className="d-flex gap-4 mb-2 flex-wrap", children=[
                html.Span([html.Strong("Sentiment : "),
                           html.Span(sent.capitalize(),
                                     style={"color": sent_color, "fontWeight": "700"})]),
                html.Span([html.Strong("Mots-clés : "),
                           html.Span(", ".join(result.get("mots_cles", [])))]),
            ]),
            html.P(result.get("resume", ""), style={"lineHeight": "1.6"}),
            html.Hr(),
            html.Div(className="row", children=[
                html.Div(className="col-md-6", children=[
                    html.Strong("Thèmes identifiés"),
                    html.Ul([html.Li(t) for t in result.get("themes", [])], className="mt-1"),
                ]),
                html.Div(className="col-md-6", children=[
                    html.Strong("Points d'attention"),
                    html.Ul([html.Li(p) for p in result.get("points_attention", [])],
                            className="mt-1"),
                ]),
            ]),
            html.Small(f"Analysé sur {len(sample)} réponses (total : {len(text_vals)})",
                       style={"color": "#6b7785"}),
        ])


# ── Utilitaire ────────────────────────────────────────────────────────────────

def _is_numeric(v) -> bool:
    try:
        float(str(v))
        return True
    except (ValueError, TypeError):
        return False

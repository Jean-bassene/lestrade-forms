"""
Helpers Plotly — graphiques sécurisés (labels toujours sanitisés).
"""
from __future__ import annotations
import json
import html
import plotly.graph_objects as go
from collections import Counter

PALETTE = [
    "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd",
    "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf",
]

_LAYOUT_BASE = dict(
    paper_bgcolor="rgba(0,0,0,0)",
    plot_bgcolor="rgba(0,0,0,0)",
    font=dict(family="Segoe UI, Arial, sans-serif", size=12, color="#1f2933"),
    margin=dict(l=40, r=20, t=50, b=60),
)


def _s(v: object) -> str:
    """Sanitise une valeur pour l'affichage dans un label Plotly."""
    return html.escape(str(v or ""))


def empty_fig(msg: str = "Aucune donnée disponible") -> go.Figure:
    fig = go.Figure()
    fig.update_layout(
        **_LAYOUT_BASE,
        annotations=[dict(
            text=_s(msg), showarrow=False,
            xref="paper", yref="paper", x=0.5, y=0.5,
            font=dict(size=14, color="#6b7785"),
        )],
    )
    return fig


def bar_chart(values: list[str], title: str = "") -> go.Figure:
    if not values:
        return empty_fig()
    counts = Counter(values)
    labels = [_s(k) for k in counts.keys()]
    counts_list = list(counts.values())
    total = sum(counts_list)
    pcts  = [f"{v/total*100:.1f}%" for v in counts_list]

    fig = go.Figure(go.Bar(
        x=labels, y=counts_list,
        text=[f"{c} ({p})" for c, p in zip(counts_list, pcts)],
        textposition="auto",
        marker_color=PALETTE[:len(labels)],
    ))
    fig.update_layout(
        **_LAYOUT_BASE,
        title=dict(text=_s(title), x=0.02, font=dict(size=14)),
        xaxis=dict(title="", tickfont=dict(size=11)),
        yaxis=dict(title="Effectif"),
        showlegend=False,
    )
    return fig


def pie_chart(values: list[str], title: str = "") -> go.Figure:
    if not values:
        return empty_fig()
    counts = Counter(values)
    labels = [_s(k) for k in counts.keys()]

    fig = go.Figure(go.Pie(
        labels=labels,
        values=list(counts.values()),
        marker_colors=PALETTE[:len(labels)],
        textinfo="label+percent",
        hovertemplate="%{label}: %{value} (%{percent})<extra></extra>",
    ))
    fig.update_layout(
        **_LAYOUT_BASE,
        title=dict(text=_s(title), x=0.02, font=dict(size=14)),
        showlegend=True,
    )
    return fig


def histogram_chart(values: list[float | int], title: str = "") -> go.Figure:
    if not values:
        return empty_fig()
    fig = go.Figure(go.Histogram(
        x=values,
        marker_color=PALETTE[0],
        opacity=0.85,
    ))
    fig.update_layout(
        **_LAYOUT_BASE,
        title=dict(text=_s(title), x=0.02, font=dict(size=14)),
        xaxis=dict(title="Valeur"),
        yaxis=dict(title="Fréquence"),
    )
    return fig


def heatmap_chart(
    z_matrix: list[list[float]],
    x_labels: list[str],
    y_labels: list[str],
    title: str = "",
) -> go.Figure:
    if not z_matrix:
        return empty_fig()
    fig = go.Figure(go.Heatmap(
        z=z_matrix,
        x=[_s(l) for l in x_labels],
        y=[_s(l) for l in y_labels],
        colorscale="Blues",
        hovertemplate="%{y} × %{x}: %{z:.2f}<extra></extra>",
    ))
    fig.update_layout(
        **_LAYOUT_BASE,
        title=dict(text=_s(title), x=0.02, font=dict(size=14)),
    )
    return fig


def timeline_chart(dates: list[str], counts: list[int], title: str = "") -> go.Figure:
    if not dates:
        return empty_fig()
    fig = go.Figure(go.Scatter(
        x=dates, y=counts,
        mode="lines+markers",
        line=dict(color=PALETTE[0], width=2),
        marker=dict(size=6),
        hovertemplate="%{x}: %{y} réponse(s)<extra></extra>",
    ))
    fig.update_layout(
        **_LAYOUT_BASE,
        title=dict(text=_s(title), x=0.02, font=dict(size=14)),
        xaxis=dict(title="Date"),
        yaxis=dict(title="Réponses"),
    )
    return fig


def radar_chart(
    categories: list[str],
    series: dict[str, list[float]],
    title: str = "",
) -> go.Figure:
    if not categories or not series:
        return empty_fig()
    fig = go.Figure()
    for i, (name, vals) in enumerate(series.items()):
        fig.add_trace(go.Scatterpolar(
            r=vals + [vals[0]] if vals else [],
            theta=[_s(c) for c in categories] + [_s(categories[0])],
            name=_s(name),
            line=dict(color=PALETTE[i % len(PALETTE)]),
            fill="toself",
            opacity=0.5,
        ))
    fig.update_layout(
        **_LAYOUT_BASE,
        title=dict(text=_s(title), x=0.02, font=dict(size=14)),
        polar=dict(radialaxis=dict(visible=True)),
        showlegend=True,
    )
    return fig


def parse_response_values(
    reponses: list[dict],
    question_id: str | int,
) -> list[str]:
    """Extrait toutes les valeurs d'une question dans la liste de réponses."""
    qid = str(question_id)
    out = []
    for rep in reponses:
        raw = rep.get("donnees_json", "{}")
        try:
            data = json.loads(raw) if isinstance(raw, str) else raw
        except Exception:
            continue
        val = data.get(qid)
        if val is None or val == "":
            continue
        if isinstance(val, list):
            out.extend([str(v) for v in val if v != ""])
        else:
            out.append(str(val))
    return out

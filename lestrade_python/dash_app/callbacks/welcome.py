"""
Popup bienvenue — email stocké dans localStorage du navigateur.
- Réaffichage au plus une fois toutes les 30 minutes si l'utilisateur clique "Plus tard"
- Tente aussi de sauvegarder vers l'API (silencieusement si indisponible)
"""
import time
from dash import callback, Output, Input, State, no_update
from ..utils import security, api_client

SKIP_COOLDOWN_S = 30 * 60   # 30 minutes avant de réafficher après "Plus tard"


def register(app):

    # ── Ouvrir le popup selon l'état du store local ───────────────────────────

    @callback(
        Output("modal-welcome",       "is_open"),
        Output("input-welcome-email", "value"),
        Input("store-user-email",     "data"),   # déclenché au chargement de la page
        prevent_initial_call=False,
    )
    def maybe_open_welcome(stored):
        """
        Ouvre le popup seulement si :
        - Aucun email configuré
        - Et le délai de 30 min depuis le dernier "Plus tard" est écoulé
        """
        if not stored:
            return True, ""

        # Email réel enregistré → ne jamais rouvrir
        if stored not in ("", "__skip__") and not stored.startswith("__skip__@"):
            return False, stored

        # Skip avec timestamp : "__skip__@1745000000"
        if stored.startswith("__skip__@"):
            try:
                ts = float(stored.split("@")[1])
                elapsed = time.time() - ts
                if elapsed < SKIP_COOLDOWN_S:
                    return False, ""      # cooldown non écoulé → reste fermé
                else:
                    return True, ""       # 30 min écoulées → réaffiche
            except (IndexError, ValueError):
                return True, ""

        # "__skip__" sans timestamp (ancienne valeur) → réaffiche après cooldown
        return False, ""

    # ── Confirmer l'email ─────────────────────────────────────────────────────

    @callback(
        Output("modal-welcome",       "is_open",  allow_duplicate=True),
        Output("store-user-email",    "data"),        # → localStorage navigateur
        Output("welcome-email-error", "children"),
        Output("welcome-email-error", "style"),
        Output("tab-panier",          "label_style"),
        Input("btn-welcome-confirm",  "n_clicks"),
        State("input-welcome-email",  "value"),
        prevent_initial_call=True,
    )
    def confirm_email(n_clicks, email):
        if not n_clicks:
            return no_update, no_update, no_update, no_update, no_update

        if not security.rate_limit("welcome_confirm", max_calls=5, window_s=60):
            return (no_update, no_update,
                    "Trop de tentatives. Attendez une minute.",
                    {"display": "block"}, no_update)

        ok, msg = security.validate_email(email)
        if not ok:
            return no_update, no_update, msg, {"display": "block"}, no_update

        clean_email = str(email).strip().lower()

        # Tente l'API — silencieux si indisponible
        api_client.set_config("user_email", clean_email)

        panier_style = {"color": "#e6a700", "fontWeight": "700"}
        return False, clean_email, "", {"display": "none"}, panier_style

    # ── Passer (Plus tard) — cooldown 30 min ─────────────────────────────────

    @callback(
        Output("modal-welcome",    "is_open",  allow_duplicate=True),
        Output("store-user-email", "data",     allow_duplicate=True),
        Input("btn-welcome-skip",  "n_clicks"),
        prevent_initial_call=True,
    )
    def skip_welcome(n_clicks):
        if n_clicks:
            # Stocke "__skip__@<timestamp>" pour mémoriser le moment du skip
            marker = f"__skip__@{time.time():.0f}"
            return False, marker
        return no_update, no_update

    # ── Style onglet Panier selon email ──────────────────────────────────────

    @callback(
        Output("tab-panier", "label_style", allow_duplicate=True),
        Input("store-user-email", "data"),
        prevent_initial_call="initial_duplicate",
    )
    def update_panier_tab_style(email):
        if email and not email.startswith("__skip__"):
            return {"color": "#e6a700", "fontWeight": "700"}
        return {"color": "#6b7785"}

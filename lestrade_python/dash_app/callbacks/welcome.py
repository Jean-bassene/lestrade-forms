"""
Callbacks bienvenue et freemium.
- Email welcome : email stocké en localStorage, cooldown 30 min si "Plus tard"
- Freemium modal : Free (pub) vs Premium (sans pub, clé de licence)
- Onglet Admin : visible seulement pour bassene.jean@yahoo.com
"""
import os
import re
import time
from dash import callback, Output, Input, State, no_update
from ..utils import security, api_client

_ADMIN_EMAIL = os.environ.get("LESTRADE_ADMIN_EMAIL", "bassene.jean@yahoo.com")

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

        return False, clean_email, "", {"display": "none"}, {"color": "#e6a700", "fontWeight": "700"}

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
        return {}   # hérite de la couleur CSS du header (blanc semi-transparent)

    # ── Email affiché dans la navbar ─────────────────────────────────────────

    @callback(
        Output("tab-user-email-display", "label"),
        Input("store-user-email", "data"),
    )
    def update_email_display(email):
        if email and not email.startswith("__skip__"):
            return f"👤 {email}"
        return "👤 Non connecté"

    # ── Mémoriser l'onglet courant (pour revenir après clic sur 👤) ───────────

    @callback(
        Output("store-prev-tab", "data"),
        Input("main-tabs",       "active_tab"),
    )
    def track_prev_tab(active_tab):
        if active_tab and active_tab != "_user":
            return active_tab
        return no_update

    # ── Clic sur 👤 → ouvre la modale + revient à l'onglet précédent ──────────

    @callback(
        Output("modal-account",          "is_open"),                        # primary — ID unique
        Output("main-tabs",              "active_tab", allow_duplicate=True),
        Output("input-change-email",     "value"),
        Input("main-tabs",               "active_tab"),
        State("store-prev-tab",          "data"),
        State("store-user-email",        "data"),
        prevent_initial_call=True,
    )
    def open_change_email_modal(active_tab, prev_tab, current_email):
        if active_tab != "_user":
            return no_update, no_update, no_update
        email_val = current_email if (current_email and not current_email.startswith("__skip__")) else ""
        return True, prev_tab or "accueil", email_val

    # ── Enregistrer le nouvel email ───────────────────────────────────────────

    @callback(
        Output("modal-account",  "is_open",  allow_duplicate=True),
        Output("store-user-email",    "data",     allow_duplicate=True),
        Output("change-email-error",  "children"),
        Output("change-email-error",  "style"),
        Input("btn-change-email-save","n_clicks"),
        State("input-change-email",   "value"),
        prevent_initial_call=True,
    )
    def save_changed_email(n, email):
        if not n:
            return no_update, no_update, no_update, no_update
        if not security.rate_limit("change_email", max_calls=5, window_s=60):
            return no_update, no_update, "Trop de tentatives.", {"display": "block"}
        ok, msg = security.validate_email(email)
        if not ok:
            return no_update, no_update, msg, {"display": "block"}
        clean = str(email).strip().lower()
        api_client.set_config("user_email", clean)
        return False, clean, "", {"display": "none"}

    # ── Déconnexion ───────────────────────────────────────────────────────────

    @callback(
        Output("modal-account",     "is_open",  allow_duplicate=True),
        Output("store-user-email",       "data",     allow_duplicate=True),
        Output("store-licence-key",      "data",     allow_duplicate=True),
        Output("store-freemium-seen",    "data",     allow_duplicate=True),
        Output("store-admin-auth",       "data",     allow_duplicate=True),
        Input("btn-change-email-logout", "n_clicks"),
        prevent_initial_call=True,
    )
    def logout(n):
        if not n:
            return no_update, no_update, no_update, no_update, no_update
        # Efface email, licence, session admin et freemium
        return False, "", "__free__", "shown", None

    # ── Annuler ───────────────────────────────────────────────────────────────

    @callback(
        Output("modal-account",      "is_open", allow_duplicate=True),
        Input("btn-change-email-cancel",  "n_clicks"),
        prevent_initial_call=True,
    )
    def cancel_change_email(n):
        return False if n else no_update

    # ── Onglet Admin : visible seulement pour l'admin ─────────────────────────

    @callback(
        Output("tab-admin", "label_style"),
        Output("tab-admin", "disabled"),
        Input("store-user-email", "data"),
    )
    def toggle_admin_tab(email):
        if email and email.strip().lower() == _ADMIN_EMAIL:
            return {"color": "#f87171"}, False   # rouge clair lisible sur fond sombre
        return {"display": "none"}, True

    # ── Modale freemium : affichage au démarrage ──────────────────────────────

    @callback(
        Output("modal-freemium", "is_open"),
        Input("store-freemium-seen", "data"),
        Input("store-user-email",    "data"),   # re-déclenché quand welcome se ferme
        State("store-licence-key",   "data"),
        prevent_initial_call=False,
    )
    def maybe_open_freemium(seen, email_data, licence):
        if seen:
            return False
        # Ne pas ouvrir tant que le popup bienvenue n'a pas été traité
        if not email_data:
            return False
        if licence and licence not in ("", "__free__"):
            return False
        return True

    # ── Continuer gratuitement — callback PRIMAIRE pour store-freemium-seen / store-licence-key

    @callback(
        Output("modal-freemium",      "is_open",  allow_duplicate=True),
        Output("store-freemium-seen", "data"),
        Output("store-licence-key",   "data"),
        Output("ad-zone",             "style",    allow_duplicate=True),
        Input("btn-freemium-free",    "n_clicks"),
        prevent_initial_call=True,
    )
    def freemium_choose_free(n):
        if not n:
            return no_update, no_update, no_update, no_update
        return False, "shown", "__free__", _AD_STYLE_VISIBLE

    # ── Activer une clé de licence ────────────────────────────────────────────

    @callback(
        Output("modal-freemium",       "is_open",  allow_duplicate=True),
        Output("store-freemium-seen",  "data",     allow_duplicate=True),
        Output("store-licence-key",    "data",     allow_duplicate=True),
        Output("freemium-key-error",   "children"),
        Output("freemium-key-error",   "style"),
        Output("ad-zone",              "style",    allow_duplicate=True),
        Input("btn-freemium-activate", "n_clicks"),
        State("input-licence-key",     "value"),
        State("store-user-email",      "data"),
        prevent_initial_call=True,
    )
    def freemium_activate(n, key, user_email):
        if not n:
            return no_update, no_update, no_update, "", {"display": "none"}, no_update

        if not security.rate_limit("freemium_activate", max_calls=10, window_s=60):
            return (no_update, no_update, no_update,
                    "Trop de tentatives. Attendez une minute.",
                    {"display": "block"}, no_update)

        key = (key or "").strip()
        if not _validate_licence_key(key):
            return (no_update, no_update, no_update,
                    "Format de clé invalide.",
                    {"display": "block"}, no_update)

        # Vérification en base — avec email si disponible
        clean_email = (user_email or "").strip().lower()
        valid_email  = clean_email if (clean_email and not clean_email.startswith("__skip__")) else None
        check = api_client.verify_licence_key(key, email=valid_email)
        if not check.get("valid"):
            msg = ("Cette clé appartient à un autre compte email."
                   if check.get("wrong_owner")
                   else "Clé inconnue ou non encore validée — attendez la confirmation de paiement.")
            return (no_update, no_update, no_update, msg, {"display": "block"}, no_update)

        return False, "shown", key, "", {"display": "none"}, {"display": "none"}

    # ── Fermeture manuelle (bouton X) ─────────────────────────────────────────

    @callback(
        Output("store-freemium-seen", "data",  allow_duplicate=True),
        Output("store-licence-key",   "data",  allow_duplicate=True),
        Input("modal-freemium",       "is_open"),
        State("store-freemium-seen",  "data"),
        State("store-licence-key",    "data"),
        prevent_initial_call=True,
    )
    def on_freemium_close(is_open, seen, licence):
        if not is_open and not seen:
            return "shown", licence or "__free__"
        return no_update, no_update

    # ── Clic sur le CTA de la bannière → onglet Plan ─────────────────────────

    @callback(
        Output("main-tabs",      "active_tab"),
        Input("btn-ad-upgrade",  "n_clicks"),
        prevent_initial_call=True,
    )
    def go_to_plan(_):
        return "plan"

    # ── Zone pub : visible/cachée selon la clé stockée ────────────────────────

    @callback(
        Output("ad-zone", "style"),
        Input("store-licence-key", "data"),
        prevent_initial_call=False,
    )
    def toggle_ad_zone(licence):
        if licence and licence not in ("", "__free__"):
            return {"display": "none"}
        return _AD_STYLE_VISIBLE


# ── Helpers ───────────────────────────────────────────────────────────────────

_AD_STYLE_VISIBLE = {"display": "block"}

_KEY_RE = re.compile(r'^[A-Za-z0-9\-_]{12,64}$')

def _validate_licence_key(key: str) -> bool:
    return bool(_KEY_RE.match(key))

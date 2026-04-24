"""
Factory Dash — crée et configure l'application UI Desktop.
Séparé de FastAPI (port 8766) pour éviter les conflits WSGI/ASGI.
"""
import dash
import dash_bootstrap_components as dbc

from .layout import build_layout
from .callbacks import register_all


def create_dash_app() -> dash.Dash:
    app = dash.Dash(
        __name__,
        external_stylesheets=[dbc.themes.BOOTSTRAP],
        # assets_folder pointe vers dash_app/assets/ automatiquement
        title="Lestrade Forms",
        update_title=None,
        suppress_callback_exceptions=True,   # nécessaire pour les composants dynamiques
        meta_tags=[
            {"name": "viewport", "content": "width=device-width, initial-scale=1"},
            # Sécurité navigateur
            {"http-equiv": "X-Content-Type-Options", "content": "nosniff"},
        ],
    )

    app.layout = build_layout()

    # Sécurité headers via index_string
    app.index_string = app.index_string.replace(
        "<head>",
        "<head>\n"
        "    <meta http-equiv='Content-Security-Policy' "
        "content=\"default-src 'self' 'unsafe-inline' 'unsafe-eval' "
        "cdn.jsdelivr.net cdn.plot.ly; "
        "img-src 'self' data: https:; "
        "connect-src 'self' https: http://localhost:* http://127.0.0.1:*; "
        "worker-src 'self' blob:;\">\n"
        "    <meta http-equiv='X-Frame-Options' content='SAMEORIGIN'>\n"
        "    <meta http-equiv='Referrer-Policy' content='no-referrer'>\n",
    )

    register_all(app)

    return app

"""
Point d'entrée UI Desktop — port 8766.
Fonctionne que vous soyez dans enquete/ ou enquete/lestrade_python/.
FastAPI doit tourner sur 8765 (Flutter + Dash l'utilisent comme backend).
"""
import sys
import os

# Ajoute le dossier parent (enquete/) au path pour que
# "from lestrade_python..." fonctionne peu importe le CWD
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Charge les variables d'environnement — priorité :
#   1. %APPDATA%\LestradeForms\.env  (installation distribuée)
#   2. dossier projet/.env           (développement local)
from dotenv import load_dotenv
_appdata_env = os.path.join(os.environ.get("APPDATA", ""), "LestradeForms", ".env")
_project_env = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env")
load_dotenv(_appdata_env if os.path.exists(_appdata_env) else _project_env)

from lestrade_python.dash_app import create_dash_app

if __name__ == "__main__":
    app = create_dash_app()
    print("=" * 50)
    print("  Lestrade Forms — UI Desktop")
    print("  http://localhost:8766")
    print("  (FastAPI API : http://localhost:8765)")
    print("=" * 50)
    app.run(host="0.0.0.0", port=8766, debug=False)

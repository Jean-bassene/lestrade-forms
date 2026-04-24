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

from lestrade_python.dash_app import create_dash_app

if __name__ == "__main__":
    app = create_dash_app()
    print("=" * 50)
    print("  Lestrade Forms — UI Desktop")
    print("  http://localhost:8766")
    print("  (FastAPI API : http://localhost:8765)")
    print("=" * 50)
    app.run(host="0.0.0.0", port=8766, debug=False)

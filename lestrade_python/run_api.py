"""
Point d'entrée API FastAPI — port 8765, accessible réseau local (0.0.0.0).
Fonctionne que vous soyez dans enquete/ ou enquete/lestrade_python/.
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv
_appdata_env = os.path.join(os.environ.get("APPDATA", ""), "LestradeForms", ".env")
_project_env = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env")
load_dotenv(_appdata_env if os.path.exists(_appdata_env) else _project_env)

if __name__ == "__main__":
    import uvicorn
    print("=" * 50)
    print("  Lestrade Forms — API FastAPI")
    print("  http://0.0.0.0:8765  (réseau local)")
    print("=" * 50)
    uvicorn.run(
        "lestrade_python.main:app",
        host="0.0.0.0",
        port=8765,
        reload=False,
    )

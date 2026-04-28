# -*- mode: python ; coding: utf-8 -*-
"""
PyInstaller spec — Lestrade Forms v1.3.0
Build : pyinstaller lestrade.spec
"""
from PyInstaller.utils.hooks import collect_all, collect_data_files, collect_submodules

block_cipher = None

# ── Collecter automatiquement les packages volumineux avec assets ─────────────
datas     = []
binaries  = []
hiddenimports = []

for pkg in [
    "dash",
    "dash_bootstrap_components",
    "plotly",
    "flask",
    "werkzeug",
    "pandas",
    "openpyxl",
    "qrcode",
    "webview",
]:
    d, b, h = collect_all(pkg)
    datas    += d
    binaries += b
    hiddenimports += h

# ── Assets locaux de l'application ───────────────────────────────────────────
datas += [
    ("lestrade_python/dash_app/assets", "lestrade_python/dash_app/assets"),
    ("LestradeApp/lf_logo.ico",         "lf_logo.ico"),
]

# ── Hidden imports manuels (non détectés par analyse statique) ────────────────
hiddenimports += [
    # uvicorn
    "uvicorn.logging",
    "uvicorn.loops",
    "uvicorn.loops.asyncio",
    "uvicorn.protocols",
    "uvicorn.protocols.http",
    "uvicorn.protocols.http.h11_impl",
    "uvicorn.protocols.http.httptools_impl",
    "uvicorn.protocols.websockets",
    "uvicorn.protocols.websockets.websockets_impl",
    "uvicorn.lifespan",
    "uvicorn.lifespan.on",
    # SQLAlchemy async
    "sqlalchemy.dialects.sqlite",
    "sqlalchemy.dialects.sqlite.aiosqlite",
    "sqlalchemy.ext.asyncio",
    "aiosqlite",
    # FastAPI / Starlette / Pydantic
    "fastapi",
    "starlette",
    "starlette.routing",
    "starlette.middleware.cors",
    "pydantic",
    "pydantic.v1",
    "pydantic_core",
    # HTTP / async
    "httpx",
    "httpcore",
    "anyio",
    "anyio._backends._asyncio",
    "anyio._backends._trio",
    "h11",
    "httptools",
    # Email
    "email.mime.text",
    "email.mime.multipart",
    "smtplib",
    "ssl",
    # PyWebView
    "webview",
    "webview.platforms.edgechromium",
    "webview.http",
    "bottle",
    "proxy_tools",
    "clr",
    "pythonnet",
    # Autres
    "dotenv",
    "PIL",
    "PIL.Image",
    "qrcode.image.pil",
    "requests",
    "anthropic",    # optionnel — analyse IA
    "statsmodels",
    "statsmodels.api",
    "statsmodels.formula.api",
    "patsy",
]

# ── Sous-modules SQLAlchemy (dialectes, event, pool…) ────────────────────────
hiddenimports += collect_submodules("sqlalchemy")

a = Analysis(
    ["launcher.py"],
    pathex=["."],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        # Packages non utilisés — allège le bundle
        "tkinter",
        "matplotlib",
        "sklearn",
        "notebook",
        "IPython",
        "jupyter",
        "pytest",
        "black",
        "mypy",
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,    # onedir (plus rapide au démarrage qu'onefile)
    name="LestradeApp",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,            # pas de fenêtre console
    icon="LestradeApp/lf_logo.ico",
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name="LestradeApp",
)

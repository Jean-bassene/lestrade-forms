from . import welcome, gestion, construction, remplir, reponses, analytics, import_ext, panier, admin, plan


def register_all(app):
    welcome.register(app)
    gestion.register(app)
    construction.register(app)
    remplir.register(app)
    reponses.register(app)
    analytics.register(app)
    import_ext.register(app)
    panier.register(app)
    admin.register(app)
    plan.register(app)

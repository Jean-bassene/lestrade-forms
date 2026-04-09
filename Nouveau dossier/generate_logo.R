# ============================================================================
# generate_logo.R — Génère le logo LF pour l'app Flutter (toutes tailles Android)
# ============================================================================

library(magick)

# Dossiers mipmap Android
flutter_res <- "C:/Projets/CaritasR/enquete/lestrade_flutter_new/android/app/src/main/res"

sizes <- list(
  "mipmap-mdpi"    = 48,
  "mipmap-hdpi"    = 72,
  "mipmap-xhdpi"   = 96,
  "mipmap-xxhdpi"  = 144,
  "mipmap-xxxhdpi" = 192
)

generate_logo <- function(size) {
  navy  <- "#003366"
  amber <- "#F59E0B"
  white <- "#FFFFFF"

  # Fond carré arrondi Navy
  svg <- sprintf('
<svg width="%1$d" height="%1$d" viewBox="0 0 %1$d %1$d" xmlns="http://www.w3.org/2000/svg">
  <!-- Fond carré arrondi Navy -->
  <rect width="%1$d" height="%1$d" rx="%2$d" ry="%2$d" fill="%3$s"/>

  <!-- Lettre L en blanc -->
  <text
    x="%4$s"
    y="%5$s"
    font-family="Arial Black, Arial, sans-serif"
    font-weight="900"
    font-size="%6$d"
    fill="%7$s"
    text-anchor="middle"
    dominant-baseline="middle">L</text>

  <!-- Lettre F en Amber -->
  <text
    x="%8$s"
    y="%5$s"
    font-family="Arial Black, Arial, sans-serif"
    font-weight="900"
    font-size="%6$d"
    fill="%9$s"
    text-anchor="middle"
    dominant-baseline="middle">F</text>

  <!-- Point Amber décoratif en bas à droite -->
  <circle cx="%10$d" cy="%10$d" r="%11$d" fill="%9$s"/>
</svg>',
    size,                          # %1$d — taille totale
    round(size * 0.22),            # %2$d — radius arrondi
    navy,                          # %3$s — couleur fond
    round(size * 0.30),            # %4$s — x du L
    round(size * 0.50),            # %5$s — y centré
    round(size * 0.48),            # %6$d — taille police
    white,                         # %7$s — couleur L
    round(size * 0.70),            # %8$s — x du F
    amber,                         # %9$s — couleur F
    round(size * 0.84),            # %10$d — centre du point
    round(size * 0.07)             # %11$d — rayon du point
  )

  image_read_svg(svg, width = size, height = size)
}

# Générer pour chaque densité
for (folder in names(sizes)) {
  size <- sizes[[folder]]
  dir  <- file.path(flutter_res, folder)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)

  img <- generate_logo(size)
  path <- file.path(dir, "ic_launcher.png")
  image_write(img, path = path, format = "png")
  cat(sprintf("✓ %s/ic_launcher.png (%dx%d)\n", folder, size, size))
}

# Icône ronde (Android 8+)
for (folder in names(sizes)) {
  size <- sizes[[folder]]
  dir  <- file.path(flutter_res, folder)

  navy  <- "#003366"
  amber <- "#F59E0B"
  white <- "#FFFFFF"

  svg_round <- sprintf('
<svg width="%1$d" height="%1$d" viewBox="0 0 %1$d %1$d" xmlns="http://www.w3.org/2000/svg">
  <circle cx="%2$d" cy="%2$d" r="%2$d" fill="%3$s"/>
  <text x="%4$s" y="%2$d" font-family="Arial Black, Arial, sans-serif"
    font-weight="900" font-size="%5$d" fill="%6$s"
    text-anchor="middle" dominant-baseline="middle">L</text>
  <text x="%7$s" y="%2$d" font-family="Arial Black, Arial, sans-serif"
    font-weight="900" font-size="%5$d" fill="%8$s"
    text-anchor="middle" dominant-baseline="middle">F</text>
  <circle cx="%9$d" cy="%9$d" r="%10$d" fill="%8$s"/>
</svg>',
    size,
    round(size / 2),
    navy,
    round(size * 0.30),
    round(size * 0.48),
    white,
    round(size * 0.70),
    amber,
    round(size * 0.84),
    round(size * 0.07)
  )

  img_round <- image_read_svg(svg_round, width = size, height = size)
  image_write(img_round, path = file.path(dir, "ic_launcher_round.png"), format = "png")
}

cat("\n✅ Logo généré dans toutes les résolutions Android !\n")
cat("Rebuild l'APK pour appliquer le nouveau logo.\n")

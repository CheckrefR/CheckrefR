# =============================================================================
# WORKFLOW DE CRÉATION ET CONFIGURATION D'UN PACKAGE R
# =============================================================================
# Description : Séquence d'initialisation complète d'un package R professionnel
#               couvrant la structure, le versioning, la licence, les tests
#               et la documentation.
# Prérequis   : Packages 'devtools', 'usethis' installés
#               Compte GitHub configuré avec les credentials Git locaux
# Ordre       : Les étapes DOIVENT être exécutées séquentiellement
# =============================================================================


# -----------------------------------------------------------------------------
# ÉTAPE 1 - Initialisation de la structure du package ####
# -----------------------------------------------------------------------------
# Crée l'arborescence standard d'un package R dans un nouveau répertoire :
#   CheckrefR/
#   ├── R/              (scripts R)
#   ├── DESCRIPTION     (métadonnées du package)
#   └── NAMESPACE       (exports/imports)
#
# ⚠️  Remplacer "CheckrefR" par le nom souhaité (snake_case recommandé,
#     sans tirets ni espaces, pas de majuscules en début)
devtools::create("CheckrefR")


# -----------------------------------------------------------------------------
# ÉTAPE 2 - Initialisation du dépôt Git local ####
# -----------------------------------------------------------------------------
# Initialise Git dans le répertoire du package et effectue un premier commit
# automatique avec les fichiers générés à l'étape 1.
# Crée également un .gitignore adapté aux projets R.
usethis::use_git()
# usethis::use_github()


# -----------------------------------------------------------------------------
# ÉTAPE 3 - Ajout de la licence MIT ####
# -----------------------------------------------------------------------------
# Génère le fichier LICENSE et LICENSE.md à la racine du projet.
# Met à jour le champ "License" dans DESCRIPTION.
#
# Alternatives disponibles : use_gpl3_license(), use_apache_license(),
#                            use_proprietary_license(), usethis::use_mit_license() etc.
usethis::use_gpl3_license()


# -----------------------------------------------------------------------------
# ÉTAPE 4 - Création du fichier README en R Markdown ####
# -----------------------------------------------------------------------------
# Génère README.Rmd (source) qui produira README.md (rendu GitHub).
# Le template inclut les badges standards et la structure de base :
#   - Description du package
#   - Instructions d'installation
#   - Exemples d'utilisation
#
# ⚠️  Penser à knitter README.Rmd après modification pour mettre à jour README.md
#     via : devtools::build_readme()
usethis::use_readme_rmd()
devtools::build_readme()

# -----------------------------------------------------------------------------
# ÉTAPE 5 - Déclaration des dépendances du package  ####
# -----------------------------------------------------------------------------
# Enregistre les packages tiers utilisés dans le code source du package.
# Met à jour automatiquement le fichier DESCRIPTION et le NAMESPACE.
#
# Trois niveaux de dépendances selon l'usage :
#
#   📦 Imports  → packages INDISPENSABLES à l'exécution des fonctions
#                 Chargés automatiquement avec le package, non attachés
#                 (bonne pratique : appel via pkg::fonction() dans le code)
#
usethis::use_package("future")       # Imports (défaut)
usethis::use_package("future.apply")       # Imports (défaut)
usethis::use_package("tibble")       # Imports (défaut)
usethis::use_package("httr2")       # Imports (défaut)
usethis::use_package("xml2")       # Imports (défaut)
usethis::use_package("stringdist")
usethis::use_package("readr")
usethis::use_package("processx")
#
#   🔧 Suggests → packages OPTIONNELS (tests, vignettes, exemples)
#                 Non installés automatiquement avec le package
#                 Doit être géré avec : if (requireNamespace("pkg", quietly = TRUE))
#
# usethis::use_package("ggplot2", type = "Suggests")  # Optionnel (visualisation)
# usethis::use_package("knitr",   type = "Suggests")  # Optionnel (vignettes)
#
#   ⚙️  Depends  → packages attachés AVEC le package au chargement (library())
#                 Usage déconseillé sauf cas particuliers (ex: R lui-même)
#                 Réservé aux packages qui étendent une classe (ex: ggplot2 extend)
#
usethis::use_package("R", type = "Depends", min_version = "4.1.0")
#
# 💡 Résultat dans DESCRIPTION :
#   Depends:
#     R (>= 4.1.0)
#   Imports:
#     dplyr,
#     lubridate,
#     stringr
#   Suggests:
#     ggplot2,
#     knitr
#
# ⚠️  Pour forcer une version minimale d'un package :
#     usethis::use_package("dplyr", min_version = "1.1.0")
#
# ⚠️  Pour utiliser le pipe natif |> ou des fonctions internes d'un package :
#     usethis::use_import_from("dplyr", c("filter", "mutate"))
#     → Ajoute @importFrom dplyr filter mutate dans un fichier R/imports.R


# -----------------------------------------------------------------------------
# ÉTAPE 6 - Configuration du framework de tests unitaires ####
# -----------------------------------------------------------------------------
# Initialise {testthat} comme framework de tests :
#   CheckrefR/
#   └── tests/
#       ├── testthat.R          (runner principal)
#       └── testthat/           (dossier des fichiers de tests)
#
# Ajoute 'testthat' aux dépendances dans DESCRIPTION (champ Suggests).
# Les tests sont ensuite créés via : usethis::use_test("nom_fonction")
usethis::use_testthat()


# -----------------------------------------------------------------------------
# ÉTAPE 7 - Configuration de pkgdown (site de documentation web) ####
# -----------------------------------------------------------------------------
# Génère la configuration pour créer un site web statique à partir de la
# documentation Roxygen et des vignettes du package.
# Crée le fichier _pkgdown.yml à la racine du projet.
#
# Pour générer le site localement : pkgdown::build_site()
# Le site peut être hébergé sur GitHub Pages (configuré à l'étape 10)
usethis::use_pkgdown()


# -----------------------------------------------------------------------------
# ÉTAPE 8 - Génération de la documentation Roxygen ####
# -----------------------------------------------------------------------------
# Compile les commentaires Roxygen2 (#') des fichiers R/ pour :
#   - Générer les fichiers .Rd dans man/
#   - Mettre à jour le fichier NAMESPACE (exports/imports)
#
# ⚠️  À relancer après chaque modification des commentaires Roxygen
#     ou des directives @export / @import
devtools::document()


# -----------------------------------------------------------------------------
#ÉTAPE 9 - Vérification complète du package (CRAN checks) ####
# -----------------------------------------------------------------------------
# Lance la batterie de vérifications standards équivalente aux contrôles CRAN :
#   ✔ Cohérence du DESCRIPTION et du NAMESPACE
#   ✔ Exécution de tous les tests unitaires (testthat)
#   ✔ Vérification de la documentation (exemples, Rd)
#   ✔ Détection des erreurs, warnings et notes
#
# Objectif : 0 error | 0 warning | 0 note avant publication
devtools::check()


# -----------------------------------------------------------------------------
# ÉTAPE 10 - Publication sur GitHub ####
# -----------------------------------------------------------------------------
# Crée un dépôt distant sur GitHub et pousse le code local.
# Configure automatiquement le remote 'origin' dans Git.
#
# Prérequis :
#   - Token GitHub configuré : usethis::create_github_token()
#                              gitcreds::gitcreds_set()
#   - Être connecté : gh::gh_whoami() doit retourner votre profil
#
# ⚠️  Le nom du dépôt GitHub reprendra le nom du package R
usethis::use_github()



# -----------------------------------------------------------------------------
# fichier à ignorer pour le build ####
# -----------------------------------------------------------------------------
# 1. Les déplacer dans un dossier ignoré par le build
usethis::use_build_ignore(c(
  "architecture_fonction_OA_verif.html",
  "devtools_history.R",
  "tableau_test_ref.csv",
  "test.R",
  "README2.md",
  "README2.Rmd",
  "test_complet_real.Rmd",
  "test_complet_real.html"
))

# -----------------------------------------------------------------------------
# fichier à ignorer pour github ####
# -----------------------------------------------------------------------------
usethis::use_git_ignore(c(
  "architecture_fonction_OA_verif.html",
  "test.R"
))
# =============================================================================
# RÉCAPITULATIF SÉQUENTIEL DU WORKFLOW
# =============================================================================

'devtools::create()               # 📦 Structure du package
└─> usethis::use_git()            # 🔀 Versioning local
  └─> use_mit_license()           # ⚖️  Licence
    └─> use_readme_rmd()          # 📝 Documentation utilisateur
      └─> use_package()           # 📌 Dépendances (Imports/Suggests/Depends)
        └─> use_testthat()        # 🧪 Tests unitaires
          └─> use_pkgdown()       # 🌐 Site web
            └─> devtools::document()    # 📚 Docs Roxygen
              └─> devtools::check()    # ✅ Validation CRAN
                └─> use_github()       # 🚀 Publication'

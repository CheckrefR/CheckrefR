# test-checkrefr_valid_services.R
# Fonction cible : checkrefr_valid_services
# Rappel convention skip : Aucun test d'intégration requis pour cette constante

# Helper pour récupérer la constante interne de manière robuste dans l'environnement de test
get_valid_services <- function() {
  if (requireNamespace("checkrefr", quietly = TRUE)) {
    # Accès direct au namespace pour les constantes non exportées
    get("checkrefr_valid_services", envir = asNamespace("checkrefr"))
  } else {
    # Repli si exécuté hors du contexte de package standard
    checkrefr_valid_services
  }
}

# ==== TESTS UNITAIRES (mockes) ====

test_that("checkrefr_valid_services is a character vector", {
  services <- get_valid_services()

  expect_type(services, "character")
  expect_true(is.vector(services))
})

test_that("checkrefr_valid_services contains exactly the four expected services", {
  services <- get_valid_services()
  expected <- c(
    "processFulltextDocument",
    "processHeaderDocument",
    "processReferences",
    "processCitationList"
  )

  # Utilisation d'expect_equal pour une vérification exacte de la valeur et de l'ordre
  expect_equal(services, expected)
})

test_that("checkrefr_valid_services does not contain missing or empty values", {
  services <- get_valid_services()

  # Vérifications de robustesse sur le contenu du vecteur
  expect_false(any(is.na(services)))
  expect_false(any(services == ""))
  expect_true(all(nzchar(services)))
})


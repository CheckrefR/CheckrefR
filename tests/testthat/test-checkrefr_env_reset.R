
# ===========================================================================
# ==== TESTS UNITAIRES (mockes) ====
# ===========================================================================

test_that("checkrefr_env_reset fully resets the environment when fields is NULL", {
  withr::defer(checkrefr_env_reset(verbose = FALSE))

  # Modification directe de variables dans l'environnement interne du package
  assign("timeout", 999L, envir = CheckrefR:::.checkrefr_env)
  assign("oa_min_threshold", 0.12, envir = CheckrefR:::.checkrefr_env)
  assign("mode", "remote", envir = CheckrefR:::.checkrefr_env)

  # Garantir la modification préalable pour valider l'action du reset
  expect_equal(get("timeout", envir = CheckrefR:::.checkrefr_env), 999L)
  expect_equal(get("oa_min_threshold", envir = CheckrefR:::.checkrefr_env), 0.12)
  expect_equal(get("mode", envir = CheckrefR:::.checkrefr_env), "remote")

  # Appel de la fonction de réinitialisation complète
  res <- checkrefr_env_reset(fields = NULL, verbose = FALSE)

  # Vérification du type de retour invisible
  expect_identical(res, CheckrefR:::.checkrefr_env)

  # Vérification du retour aux valeurs d'origine (déterministes)
  expect_equal(get("timeout", envir = CheckrefR:::.checkrefr_env), 120L)
  expect_equal(get("oa_min_threshold", envir = CheckrefR:::.checkrefr_env), 0.60)
  expect_true(is.na(get("mode", envir = CheckrefR:::.checkrefr_env)))
})

test_that("checkrefr_env_reset partially resets the specified fields", {
  withr::defer(checkrefr_env_reset(verbose = FALSE))

  # Modification de plusieurs variables
  assign("timeout", 999L, envir = CheckrefR:::.checkrefr_env)
  assign("oa_min_threshold", 0.12, envir = CheckrefR:::.checkrefr_env)
  assign("max_workers", 99L, envir = CheckrefR:::.checkrefr_env)

  # Réinitialisation ciblée de timeout et oa_min_threshold uniquement
  checkrefr_env_reset(fields = c("oa_min_threshold", "timeout"), verbose = FALSE)

  # Vérification sélective : les deux champs spécifiés sont réinitialisés
  expect_equal(get("timeout", envir = CheckrefR:::.checkrefr_env), 120L)
  expect_equal(get("oa_min_threshold", envir = CheckrefR:::.checkrefr_env), 0.60)

  # max_workers doit rester intact (conserve sa valeur modifiée)
  expect_equal(get("max_workers", envir = CheckrefR:::.checkrefr_env), 99L)
})

test_that("checkrefr_env_reset aborts with invalid fields argument type", {
  # Validation stricte du type d'argument
  expect_error(
    checkrefr_env_reset(fields = 123),
    "fields.*must be a vector of type.*character.*NULL"
  )
  expect_error(
    checkrefr_env_reset(fields = TRUE),
    "fields.*must be a vector of type.*character.*NULL"
  )
})

test_that("checkrefr_env_reset warns about unknown parameters and resets the valid ones", {
  withr::defer(checkrefr_env_reset(verbose = FALSE))

  # Modification d'une variable valide
  assign("timeout", 999L, envir = CheckrefR:::.checkrefr_env)

  # Mock de la fonction cli::cli_alert_warning via local_mocked_bindings
  warning_called <- FALSE
  warning_arg <- NULL
  local_mocked_bindings(
    cli_alert_warning = function(text, ...) {
      warning_called <<- TRUE
      warning_arg <<- text
    },
    .package = "cli"
  )

  # Appel avec un mix de clé valide et invalide
  checkrefr_env_reset(fields = c("timeout", "cle_fictive"), verbose = TRUE)

  # Vérification du warning généré pour la clé inconnue
  expect_true(warning_called)
  expect_match(warning_arg, "Unknown parameter.*")

  # La clé valide doit tout de même être correctement réinitialisée
  expect_equal(get("timeout", envir = CheckrefR:::.checkrefr_env), 120L)
})

test_that("checkrefr_env_reset operates silently when verbose = FALSE", {
  withr::defer(checkrefr_env_reset(verbose = FALSE))

  success_called <- FALSE
  warning_called <- FALSE

  # Mock de l'affichage cli pour intercepter tout message
  local_mocked_bindings(
    cli_alert_success = function(...) {
      success_called <<- TRUE
    },
    cli_alert_warning = function(...) {
      warning_called <<- TRUE
    },
    .package = "cli"
  )

  # 1. Reset complet silencieux (fields = NULL, verbose = FALSE)
  checkrefr_env_reset(fields = NULL, verbose = FALSE)
  expect_false(success_called)

  # 2. Reset partiel avec clés inconnues silencieux (verbose = FALSE)
  checkrefr_env_reset(fields = c("timeout", "cle_fictive"), verbose = FALSE)
  expect_false(warning_called)
})

# ===========================================================================
# ==== TESTS D'INTEGRATION (Docker/reseau reels) ====
# ===========================================================================

test_that("No integration tests required for checkrefr_env_reset", {
  skip_if_not(
    identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"),
    "Tests d'integration desactives"
  )
  # Aucun test d'intégration requis pour cette fonction car elle manipule
  # exclusivement la mémoire interne du package R sans accès Docker ni réseau.
  expect_true(TRUE)
})

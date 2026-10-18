# Fonction cible : checkrefr_set_defaults
# Rappel convention skip : Les tests d'integration ne s'executeront pas sur la CI standard (RUN_INTEGRATION_TESTS != "true")

library(testthat)

# ==== TESTS UNITAIRES (mockes) ====

test_that("checkrefr_set_defaults works with no arguments", {
  info_msg <- NULL

  # Mock de cli::cli_alert_info appelee via ::
  local_mocked_bindings(
    cli_alert_info = function(text, ...) {
      info_msg <<- text
    },
    .package = "cli"
  )

  # Appel sans argument
  res <- withVisible(checkrefr_set_defaults())

  # Verifications du retour invisible et de l'environnement retourne
  expect_false(res$visible)
  expect_identical(res$value, .checkrefr_env)

  # Verification du message cli affiche
  expect_match(info_msg, "No value provided")
})

test_that("checkrefr_set_defaults can modify a single valid variable", {
  success_msg <- NULL

  # Mock de cli::cli_alert_success appelee via ::
  local_mocked_bindings(
    cli_alert_success = function(text, ...) {
      success_msg <<- text
    },
    .package = "cli"
  )

  # Reinitialisation de l'environnement de test et mise en place d'un restaurateur automatique
  checkrefr_env_reset(verbose = FALSE)
  on.exit(checkrefr_env_reset(verbose = FALSE), add = TRUE)

  # Appel de modification
  res <- withVisible(checkrefr_set_defaults(timeout = 45L))

  # Verifications
  expect_false(res$visible)
  expect_identical(res$value, .checkrefr_env)
  expect_equal(.checkrefr_env$timeout, 45L)
  expect_match(success_msg, "Variable\\(s\\) updated")
})

test_that("checkrefr_set_defaults can modify multiple valid variables simultaneously", {
  success_msg <- NULL

  local_mocked_bindings(
    cli_alert_success = function(text, ...) {
      success_msg <<- text
    },
    .package = "cli"
  )

  checkrefr_env_reset(verbose = FALSE)
  on.exit(checkrefr_env_reset(verbose = FALSE), add = TRUE)

  # Appel de modification multiple
  res <- withVisible(checkrefr_set_defaults(timeout = 50L, max_workers = 3L))

  # Verifications
  expect_false(res$visible)
  expect_equal(.checkrefr_env$timeout, 50L)
  expect_equal(.checkrefr_env$max_workers, 3L)
  expect_match(success_msg, "Variable\\(s\\) updated")
})

test_that("checkrefr_set_defaults blocks modifications of protected variables", {
  checkrefr_env_reset(verbose = FALSE)
  on.exit(checkrefr_env_reset(verbose = FALSE), add = TRUE)

  # Tente de modifier la variable protegee 'mode'
  expect_error(
    checkrefr_set_defaults(mode = "remote"),
    "Unknown or non-modifiable variable"
  )
  # Verifie que 'mode' n'a pas change
  expect_true(is.na(.checkrefr_env$mode))

  # Tente de modifier la variable protegee 'docker_container_id'
  expect_error(
    checkrefr_set_defaults(docker_container_id = "1234"),
    "Unknown or non-modifiable variable"
  )
  # Verifie que 'docker_container_id' n'a pas change
  expect_true(is.na(.checkrefr_env$docker_container_id))
})

test_that("checkrefr_set_defaults blocks unknown variables", {
  checkrefr_env_reset(verbose = FALSE)
  on.exit(checkrefr_env_reset(verbose = FALSE), add = TRUE)

  # Tente de modifier une variable imaginaire
  expect_error(
    checkrefr_set_defaults(param_imaginaire = TRUE),
    "Unknown or non-modifiable variable"
  )

  # Verifie que la variable n'a pas ete creee dans l'environnement
  expect_false(exists("param_imaginaire", envir = .checkrefr_env, inherits = FALSE))
})


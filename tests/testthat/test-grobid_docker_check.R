# test-grobid_docker_check.R
# This file contains unit and integration tests for the grobid_docker_check() function.
# Built for testthat (edition 3).

# ==== TESTS UNITAIRES (mockés) ====

test_that("grobid_docker_check() returns TRUE invisibly under nominal conditions", {
  testthat::local_mocked_bindings(
    .checkrefr_docker_installed = function() TRUE,
    .checkrefr_docker_running   = function() TRUE
  )

  # Verification of invisible return and logical value
  res <- withVisible(grobid_docker_check(verbose = FALSE))
  expect_false(res$visible)
  expect_identical(res$value, TRUE)

  # Verification of the console message when verbose is TRUE
  expect_message(
    grobid_docker_check(verbose = TRUE),
    "Docker is available\\."
  )
})

test_that("grobid_docker_check() throws error when Docker is not installed", {
  testthat::local_mocked_bindings(
    .checkrefr_docker_installed = function() FALSE
  )

  # Verification of error throwing and message contents
  err <- expect_error(
    grobid_docker_check(verbose = FALSE),
    class = "rlang_error"
  )

  expect_match(
    conditionMessage(err),
    "Docker could not be found on this system\\.",
    fixed = FALSE
  )
  expect_match(
    conditionMessage(err),
    "docs\\.docker\\.com/get-docker",
    fixed = FALSE
  )
})

test_that("grobid_docker_check() throws error when Docker daemon is not running", {
  testthat::local_mocked_bindings(
    .checkrefr_docker_installed = function() TRUE,
    .checkrefr_docker_running   = function() FALSE
  )

  # Verification of error throwing and message contents
  err <- expect_error(
    grobid_docker_check(verbose = FALSE),
    class = "rlang_error"
  )

  expect_match(
    conditionMessage(err),
    "Docker is installed but not responding\\.",
    fixed = FALSE
  )
  expect_match(
    conditionMessage(err),
    "Check that the Docker daemon is running\\.",
    fixed = FALSE
  )
})

# ==== TESTS D'INTEGRATION (Docker/réseau réels) ====

test_that("grobid_docker_check() works as expected during integration tests", {
  skip_if_not(
    identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"),
    "Tests d'integration desactives"
  )

  # Real execution verification (invisible return)
  res <- withVisible(grobid_docker_check(verbose = FALSE))
  expect_false(res$visible)
  expect_identical(res$value, TRUE)

  # Real execution message verification when verbose is TRUE
  expect_message(
    grobid_docker_check(verbose = TRUE),
    "Docker is available\\."
  )
})

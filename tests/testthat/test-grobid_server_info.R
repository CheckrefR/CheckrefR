# Fichier : test-grobid_server_info.R
# Tâche : Tests unitaires et d'intégration de la fonction grobid_server_info()
# Convention de skip : Les tests d'intégration nécessitant un conteneur Docker
# réel sont ignorés si la variable d'environnement RUN_INTEGRATION_TESTS n'est pas "true".

# ==== TESTS UNITAIRES (mockés) ====

test_that("grobid_server_info returns default values when no server is configured", {
  # Save current state for restoration
  init_mode <- .checkrefr_env$mode
  init_url <- .checkrefr_env$server_url
  init_timeout <- .checkrefr_env$timeout

  withr::defer({
    .checkrefr_env$mode <- init_mode
    .checkrefr_env$server_url <- init_url
    .checkrefr_env$timeout <- init_timeout
  })

  # Configure to unconfigured state
  .checkrefr_env$mode <- NA_character_
  .checkrefr_env$server_url <- NA_character_
  .checkrefr_env$timeout <- NA_integer_

  # Mock ping to assert that no network call is attempted
  local_mocked_bindings(
    .checkrefr_ping = function(...) {
      stop("Ping should not be called when no server is configured")
    }
  )

  # Call function and capture output to verify console printing contains "not configured"
  expect_snapshot(
    res <- grobid_server_info()
  )

  # Verify returned structure and values
  expect_equal(res$mode, "not configured")
  expect_true(is.na(res$url))
  expect_false(res$api_reachable)
  expect_true(is.na(res$grobid_version))
  expect_true(is.na(res$timeout))
})

test_that("grobid_server_info returns correct info when server is configured and reachable", {
  init_mode <- .checkrefr_env$mode
  init_url <- .checkrefr_env$server_url
  init_timeout <- .checkrefr_env$timeout

  withr::defer({
    .checkrefr_env$mode <- init_mode
    .checkrefr_env$server_url <- init_url
    .checkrefr_env$timeout <- init_timeout
  })

  # Configure simulated server
  .checkrefr_env$mode <- "docker"
  .checkrefr_env$server_url <- "http://localhost:8070"
  .checkrefr_env$timeout <- 120L

  # Mock internal functions to simulate a reachable server
  local_mocked_bindings(
    .checkrefr_ping = function(url, timeout) TRUE,
    .checkrefr_get_version = function(url, timeout) "0.9.0"
  )

  # Call and check CLI console output
  expect_snapshot(
    res <- grobid_server_info()
  )

  # Verify return list values
  expect_equal(res$mode, "docker")
  expect_equal(res$url, "http://localhost:8070")
  expect_true(res$api_reachable)
  expect_equal(res$grobid_version, "0.9.0")
  expect_equal(res$timeout, 120L)
})

test_that("grobid_server_info returns api_reachable = FALSE when server is configured but unreachable", {
  init_mode <- .checkrefr_env$mode
  init_url <- .checkrefr_env$server_url
  init_timeout <- .checkrefr_env$timeout

  withr::defer({
    .checkrefr_env$mode <- init_mode
    .checkrefr_env$server_url <- init_url
    .checkrefr_env$timeout <- init_timeout
  })

  # Configure simulated server
  .checkrefr_env$mode <- "remote"
  .checkrefr_env$server_url <- "https://grobidorg-grobid.hf.space"
  .checkrefr_env$timeout <- 10L

  # Mock ping to fail and ensure version is not fetched
  local_mocked_bindings(
    .checkrefr_ping = function(url, timeout) FALSE,
    .checkrefr_get_version = function(...) {
      stop(".checkrefr_get_version should not be called when ping fails")
    }
  )

  # Call and check output
  expect_snapshot(
    res <- grobid_server_info()
  )

  # Verify return list values
  expect_equal(res$mode, "remote")
  expect_equal(res$url, "https://grobidorg-grobid.hf.space")
  expect_false(res$api_reachable)
  expect_true(is.na(res$grobid_version))
  expect_equal(res$timeout, 10L)
})

test_that("grobid_server_info is robust to internal function failures (raised errors)", {
  init_mode <- .checkrefr_env$mode
  init_url <- .checkrefr_env$server_url
  init_timeout <- .checkrefr_env$timeout

  withr::defer({
    .checkrefr_env$mode <- init_mode
    .checkrefr_env$server_url <- init_url
    .checkrefr_env$timeout <- init_timeout
  })

  .checkrefr_env$mode <- "docker"
  .checkrefr_env$server_url <- "http://localhost:8070"
  .checkrefr_env$timeout <- 120L

  # Case 1: .checkrefr_ping raises an unhandled exception.
  # If the function is robust, it should handle this failure and return api_reachable = FALSE.
  local_mocked_bindings(
    .checkrefr_ping = function(url, timeout) {
      stop("Unexpected connection error")
    }
  )

  res <- tryCatch({
    grobid_server_info()
  }, error = function(e) {
    fail(paste("grobid_server_info crashed when .checkrefr_ping raised an error:", conditionMessage(e)))
  })

  expect_false(res$api_reachable)
  expect_true(is.na(res$grobid_version))

  # Case 2: .checkrefr_ping is TRUE, but .checkrefr_get_version raises an error.
  local_mocked_bindings(
    .checkrefr_ping = function(url, timeout) TRUE,
    .checkrefr_get_version = function(url, timeout) {
      stop("Unexpected version payload error")
    }
  )

  res2 <- tryCatch({
    grobid_server_info()
  }, error = function(e) {
    fail(paste("grobid_server_info crashed when .checkrefr_get_version raised an error:", conditionMessage(e)))
  })

  expect_true(res2$api_reachable)
  expect_true(is.na(res2$grobid_version))
})

# ==== TESTS D'INTEGRATION (Docker/réseau réels) ====

test_that("grobid_server_info works with an active Docker server", {
  skip_if_not(
    identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"),
    "Tests d'integration desactives"
  )

  # Startup real Docker GROBID container
  grobid_docker_start(verbose = FALSE)

  # Ensure cleanup at exit
  withr::defer({
    try(grobid_docker_stop(verbose = FALSE), silent = TRUE)
  })

  # Check info
  res <- grobid_server_info()

  expect_equal(res$mode, "docker")
  expect_match(res$url, "^http://localhost:\\d+$")
  expect_true(res$api_reachable)
  expect_match(res$grobid_version, "^\\d+\\.\\d+(\\.\\d+)?") # format semver
})

test_that("grobid_server_info detects when the server has been stopped", {
  skip_if_not(
    identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"),
    "Tests d'integration desactives"
  )

  # Start then stop
  grobid_docker_start(verbose = FALSE)
  grobid_docker_stop(verbose = FALSE)

  # Check info
  res <- grobid_server_info()

  # If stopped, the port is free and ping fails
  expect_false(res$api_reachable)
  expect_true(is.na(res$grobid_version))
})

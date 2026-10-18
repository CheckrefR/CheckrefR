

library("testthat")


# ==== TESTS UNITAIRES (mockes) ====

test_that("grobid_remote_connect rejects invalid model_type via match.arg", {
  env <- CheckrefR:::.checkrefr_env
  old_mode <- env$mode
  old_url <- env$server_url
  old_model_type <- env$grobid_model_type
  on.exit({
    env$mode <- old_mode
    env$server_url <- old_url
    env$grobid_model_type <- old_model_type
  }, add = TRUE)

  expect_error(
    grobid_remote_connect(model_type = "invalid"),
    regexp = "'arg'.*crf.*full"
  )
})

test_that("grobid_remote_connect rejects malformed URL", {
  env <- asNamespace("CheckrefR")$.checkrefr_env
  old_mode <- env$mode
  old_url <- env$server_url
  old_model_type <- env$grobid_model_type
  on.exit({
    env$mode <- old_mode
    env$server_url <- old_url
    env$grobid_model_type <- old_model_type
  }, add = TRUE)

  expect_error(
    grobid_remote_connect(url = "ftp://invalid-protocol.com"),
    regexp = "The URL must start with"
  )
})

test_that("grobid_remote_connect succeeds with explicit valid URL and updates env", {
  env <- CheckrefR:::.checkrefr_env
  old_mode <- env$mode
  old_url <- env$server_url
  old_model_type <- env$grobid_model_type
  on.exit({
    env$mode <- old_mode
    env$server_url <- old_url
    env$grobid_model_type <- old_model_type
  }, add = TRUE)

  local_mocked_bindings(
    .checkrefr_ping = function(url, timeout, interval = 3) TRUE
  )

  res <- expect_invisible(
    grobid_remote_connect(url = "https://my-mocked-grobid.com/", model_type = "full", verbose = FALSE)
  )
  expect_true(res)

  expect_equal(env$mode, "remote")
  expect_equal(env$server_url, "https://my-mocked-grobid.com")
  expect_equal(env$grobid_model_type, "full")
})

test_that("grobid_remote_connect fails when no tested URL is reachable and preserves env", {
  env <- CheckrefR:::.checkrefr_env
  old_mode <- env$mode
  old_url <- env$server_url
  old_model_type <- env$grobid_model_type
  on.exit({
    env$mode <- old_mode
    env$server_url <- old_url
    env$grobid_model_type <- old_model_type
  }, add = TRUE)

  local_mocked_bindings(
    .checkrefr_ping = function(url, timeout, interval = 3) FALSE
  )

  expect_error(
    grobid_remote_connect(url = "https://unreachable-grobid.com", verbose = FALSE),
    regexp = "No reachable remote server among the tested URLs"
  )

  expect_equal(env$mode, old_mode)
  expect_equal(env$server_url, old_url)
  expect_equal(env$grobid_model_type, old_model_type)
})

test_that("grobid_remote_connect resolves default URLs and connects to first reachable", {
  env <- CheckrefR:::.checkrefr_env
  old_mode <- env$mode
  old_url <- env$server_url
  old_model_type <- env$grobid_model_type
  on.exit({
    env$mode <- old_mode
    env$server_url <- old_url
    env$grobid_model_type <- old_model_type
  }, add = TRUE)

  # Neutralise toute connexion laissee par un test precedent
  # (sinon le court-circuit "deja connecte" evite resolve_remote_urls)
  env$mode <- NA_character_
  env$server_url <- NA_character_
  env$grobid_model_type <- NA_character_

  local_mocked_bindings(
    .checkrefr_resolve_remote_urls = function(model_type) {
      c("https://server1.com", "https://server2.com")
    },
    .checkrefr_ping = function(url, timeout, interval = 3) {
      if (grepl("server1", url)) return(FALSE)
      if (grepl("server2", url)) return(TRUE)
      FALSE
    }
  )

  res <- expect_invisible(
    grobid_remote_connect(url = NULL, model_type = "crf", verbose = FALSE)
  )
  expect_true(res)

  expect_equal(env$mode, "remote")
  expect_equal(env$server_url, "https://server2.com")
  expect_equal(env$grobid_model_type, "crf")
})

test_that("grobid_remote_connect is a no-op if already connected to the same configuration", {
  env <- CheckrefR:::.checkrefr_env
  old_mode <- env$mode
  old_url <- env$server_url
  old_model_type <- env$grobid_model_type
  on.exit({
    env$mode <- old_mode
    env$server_url <- old_url
    env$grobid_model_type <- old_model_type
  }, add = TRUE)

  env$mode <- "remote"
  env$server_url <- "https://already-connected.com"
  env$grobid_model_type <- "crf"

  local_mocked_bindings(
    .checkrefr_resolve_remote_urls = function(model_type) {
      stop("Should not be called because of short-circuit!")
    },
    .checkrefr_ping = function(url, timeout, interval = 3) TRUE  # server still alive
  )

  res <- expect_invisible(
    grobid_remote_connect(url = NULL, model_type = "crf", verbose = FALSE)
  )
  expect_true(res)

  expect_equal(env$mode, "remote")
  expect_equal(env$server_url, "https://already-connected.com")
  expect_equal(env$grobid_model_type, "crf")
})

# NOTE: cas ajoute, absent de la fiche d'analyse - Verifie la reaction de .checkrefr_resolve_remote_urls
# lorsque le model_type n'a pas d'URL associee dans l'environnement du package.
test_that("grobid_remote_connect fails when resolve_remote_urls cannot find URLs for model_type", {
  env <- CheckrefR:::.checkrefr_env
  old_mode <- env$mode
  old_url <- env$server_url
  old_model_type <- env$grobid_model_type
  on.exit({
    env$mode <- old_mode
    env$server_url <- old_url
    env$grobid_model_type <- old_model_type
  }, add = TRUE)

  # Neutralise toute connexion laissee par un test precedent
  # (sinon le court-circuit "deja connecte" evite resolve_remote_urls)
  env$mode <- NA_character_
  env$server_url <- NA_character_
  env$grobid_model_type <- NA_character_

  local_mocked_bindings(
    .checkrefr_resolve_remote_urls = function(model_type) {
      cli::cli_abort("No URL configured for model type {.val {model_type}}.")
    },
    .checkrefr_ping = function(url, timeout, interval = 3) FALSE
  )

  expect_error(
    grobid_remote_connect(url = NULL, model_type = "crf", verbose = FALSE),
    regexp = "No URL configured for model type"
  )
})


# ==== TESTS D'INTEGRATION (Docker/reseau reels) ====

test_that("Integration: real connection to local Grobid server started in Docker", {
  skip_if_not(
    identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"),
    "Tests d'integration desactives"
  )

  env <- CheckrefR:::.checkrefr_env
  old_mode <- env$mode
  old_url <- env$server_url
  old_model_type <- env$grobid_model_type
  on.exit({
    try(grobid_docker_stop(verbose = FALSE), silent = TRUE)
    env$mode <- old_mode
    env$server_url <- old_url
    env$grobid_model_type <- old_model_type
  }, add = TRUE)

  start_ok <- tryCatch({
    grobid_docker_start(verbose = FALSE, timeout_ready = 120L)
    TRUE
  }, error = function(e) {
    skip(paste("Local Docker container could not be started:", conditionMessage(e)))
    FALSE
  })

  skip_if_not(start_ok, "Grobid container is not running locally")

  res <- expect_invisible(
    grobid_remote_connect(url = "http://localhost:8070", verbose = FALSE)
  )
  expect_true(res)

  expect_equal(env$mode, "remote")
  expect_equal(env$server_url, "http://localhost:8070")
})

test_that("Integration: real connection to default remote servers", {
  skip_if_not(
    identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"),
    "Tests d'integration desactives"
  )

  env <- CheckrefR:::.checkrefr_env
  old_mode <- env$mode
  old_url <- env$server_url
  old_model_type <- env$grobid_model_type
  on.exit({
    env$mode <- old_mode
    env$server_url <- old_url
    env$grobid_model_type <- old_model_type
  }, add = TRUE)

  res <- tryCatch({
    grobid_remote_connect(url = NULL, model_type = "crf", verbose = FALSE)
  }, error = function(e) {
    skip(paste("External remote servers are unreachable or offline:", conditionMessage(e)))
    NULL
  })

  if (!is.null(res)) {
    expect_true(res)
    expect_equal(env$mode, "remote")
    expect_match(env$server_url, "^https?://")
    expect_equal(env$grobid_model_type, "crf")
  }
})

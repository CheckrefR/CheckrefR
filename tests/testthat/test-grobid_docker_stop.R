library(testthat)

# ==============================================================================
# TEST FILE: test-grobid_docker_stop.R
# SKIP CONVENTION: integration tests only run when the environment variable
# RUN_INTEGRATION_TESTS is set to "true".
#
# MOCKING NOTE: the real system2() only attaches a "status" attribute when the
# command returns a non-zero exit code. Mocks must follow that contract:
#   - success -> return a plain character vector, no attribute
#   - failure -> attach attr(res, "status") <- 1L
# Attaching status = 0L on success breaks identical(trimws(x), "true") in the
# tested function, because trimws() preserves attributes.
# ==============================================================================

# ---- Helper: save and restore the internal package state ---------------------
local_checkrefr_env <- function(.local_envir = parent.frame()) {
  old <- list(
    docker_container_id = .checkrefr_env$docker_container_id,
    mode                = .checkrefr_env$mode,
    server_url          = .checkrefr_env$server_url,
    docker_port         = .checkrefr_env$docker_port
  )
  withr::defer(
    {
      .checkrefr_env$docker_container_id <- old$docker_container_id
      .checkrefr_env$mode                <- old$mode
      .checkrefr_env$server_url          <- old$server_url
      .checkrefr_env$docker_port         <- old$docker_port
    },
    envir = .local_envir
  )
  invisible(old)
}


# ==== UNIT TESTS (mocked) =====================================================

# ---- Step 0: Docker availability guards -------------------------------------

test_that("grobid_docker_stop throws error when Docker is not installed", {
  local_mocked_bindings(
    .checkrefr_docker_installed = function() FALSE
  )

  expect_error(
    grobid_docker_stop(verbose = FALSE),
    "Docker could not be found on this system"
  )
})

test_that("grobid_docker_stop returns FALSE and warns when daemon is not running", {
  local_mocked_bindings(
    .checkrefr_docker_installed = function() TRUE,
    .checkrefr_docker_running   = function() FALSE
  )

  # Non-verbose mode: silent FALSE
  expect_false(grobid_docker_stop(verbose = FALSE))

  # Verbose mode: warning alert expected
  expect_message(
    grobid_docker_stop(verbose = TRUE),
    "Docker is installed but the daemon is not running. Nothing to stop."
  )
})


# ---- Step 1: container identifier resolution --------------------------------

test_that("grobid_docker_stop returns FALSE when no container is registered or active", {
  local_checkrefr_env()
  .checkrefr_env$docker_container_id <- NA_character_

  local_mocked_bindings(
    .checkrefr_docker_installed        = function() TRUE,
    .checkrefr_docker_running          = function() TRUE,
    .checkrefr_sync_env_from_container = function(...) FALSE
  )

  # system2() must never be reached on this path
  local_mocked_bindings(
    system2 = function(command, args, ...) {
      stop("system2() should not be called when no container is registered")
    },
    .package = "base"
  )

  expect_false(grobid_docker_stop(verbose = FALSE))

  expect_message(
    grobid_docker_stop(verbose = TRUE),
    "No GROBID container registered or active."
  )
})


# ---- Step 2: inspect result handling ----------------------------------------

test_that("grobid_docker_stop throws error if container does not exist", {
  local_checkrefr_env()

  .checkrefr_env$docker_container_id <- "ghost_container"
  .checkrefr_env$mode                <- "docker"
  .checkrefr_env$server_url          <- "http://localhost:8070"

  stop_called <- FALSE

  local_mocked_bindings(
    .checkrefr_docker_installed = function() TRUE,
    .checkrefr_docker_running   = function() TRUE
  )

  local_mocked_bindings(
    system2 = function(command, args, ...) {
      if (identical(command, "docker")) {
        if ("inspect" %in% args) {
          # Non-zero status: container unknown to Docker
          res <- "Error: No such object: ghost_container"
          attr(res, "status") <- 1L
          return(res)
        }
        if ("stop" %in% args) {
          stop_called <<- TRUE
          return("ghost_container")
        }
      }
      "ok"
    },
    .package = "base"
  )

  expect_error(
    grobid_docker_stop(verbose = FALSE),
    "Failed to stop container"
  )

  # Step 3 must never be reached
  expect_false(stop_called)
})

test_that("grobid_docker_stop cleans up and returns TRUE for an inactive container", {
  local_checkrefr_env()

  .checkrefr_env$docker_container_id <- "abc123xyz"
  .checkrefr_env$mode                <- "docker"
  .checkrefr_env$server_url          <- "http://localhost:8070"
  .checkrefr_env$docker_port         <- "8070"

  inspect_called <- FALSE
  stop_called    <- FALSE

  local_mocked_bindings(
    .checkrefr_docker_installed = function() TRUE,
    .checkrefr_docker_running   = function() TRUE
  )

  local_mocked_bindings(
    system2 = function(command, args, ...) {
      if (identical(command, "docker")) {
        if ("inspect" %in% args) {
          inspect_called <<- TRUE
          return("false")   # container exists but is stopped
        }
        if ("stop" %in% args) {
          stop_called <<- TRUE
          return("abc123xyz")
        }
      }
      "ok"
    },
    .package = "base"
  )

  expect_true(grobid_docker_stop(verbose = FALSE))
  expect_true(inspect_called)

  # No actual stop is attempted on an already inactive container
  expect_false(stop_called)

  expect_true(is.na(.checkrefr_env$docker_container_id))
  expect_true(is.na(.checkrefr_env$mode))
  expect_true(is.na(.checkrefr_env$server_url))

  # NOTE: unlike step 4, this branch does not reset docker_port
  expect_equal(.checkrefr_env$docker_port, "8070")
})


# ---- Steps 3 and 4: actual stop and state cleanup ---------------------------

test_that("grobid_docker_stop successfully stops container and resets env", {
  local_checkrefr_env()

  .checkrefr_env$docker_container_id <- "abc123xyz"
  .checkrefr_env$mode                <- "docker"
  .checkrefr_env$server_url          <- "http://localhost:8070"
  .checkrefr_env$docker_port         <- "8070"

  inspect_called <- FALSE
  stop_called    <- FALSE
  stop_args      <- NULL

  local_mocked_bindings(
    .checkrefr_docker_installed = function() TRUE,
    .checkrefr_docker_running   = function() TRUE
  )

  local_mocked_bindings(
    system2 = function(command, args, ...) {
      if (identical(command, "docker")) {
        if ("inspect" %in% args) {
          inspect_called <<- TRUE
          return("true")   # success: no status attribute
        }
        if ("stop" %in% args) {
          stop_called <<- TRUE
          stop_args   <<- args
          return("abc123xyz")
        }
      }
      "ok"
    },
    .package = "base"
  )

  expect_true(grobid_docker_stop(verbose = FALSE))

  expect_true(inspect_called)
  expect_true(stop_called)
  expect_equal(stop_args, c("stop", "abc123xyz"))

  expect_true(is.na(.checkrefr_env$docker_container_id))
  expect_true(is.na(.checkrefr_env$mode))
  expect_true(is.na(.checkrefr_env$server_url))
  expect_equal(.checkrefr_env$docker_port, .checkrefr_defaults$docker_port)
})

test_that("grobid_docker_stop throws error if docker stop fails", {
  local_checkrefr_env()

  .checkrefr_env$docker_container_id <- "failing_container"
  .checkrefr_env$mode                <- "docker"
  .checkrefr_env$server_url          <- "http://localhost:8070"

  inspect_called <- FALSE
  stop_called    <- FALSE

  local_mocked_bindings(
    .checkrefr_docker_installed = function() TRUE,
    .checkrefr_docker_running   = function() TRUE
  )

  local_mocked_bindings(
    system2 = function(command, args, ...) {
      if (identical(command, "docker")) {
        if ("inspect" %in% args) {
          inspect_called <<- TRUE
          return("true")   # container is running
        }
        if ("stop" %in% args) {
          stop_called <<- TRUE
          res <- "Error response from daemon: cannot stop container"
          attr(res, "status") <- 1L
          return(res)
        }
      }
      "ok"
    },
    .package = "base"
  )

  expect_error(
    grobid_docker_stop(verbose = FALSE),
    "Failed to stop container"
  )

  expect_true(inspect_called)
  expect_true(stop_called)

  # Internal state must remain untouched after a failure
  expect_equal(.checkrefr_env$docker_container_id, "failing_container")
  expect_equal(.checkrefr_env$mode, "docker")
  expect_equal(.checkrefr_env$server_url, "http://localhost:8070")
})

test_that("grobid_docker_stop preserves an active remote configuration", {
  local_checkrefr_env()

  .checkrefr_env$docker_container_id <- "leftover_container"
  .checkrefr_env$mode                <- "remote"
  .checkrefr_env$server_url          <- "https://kermitt2-grobid.hf.space"
  .checkrefr_env$docker_port         <- "8070"

  local_mocked_bindings(
    .checkrefr_docker_installed = function() TRUE,
    .checkrefr_docker_running   = function() TRUE
  )

  local_mocked_bindings(
    system2 = function(command, args, ...) {
      if (identical(command, "docker")) {
        if ("inspect" %in% args) return("true")
        if ("stop" %in% args)    return("leftover_container")
      }
      "ok"
    },
    .package = "base"
  )

  expect_true(grobid_docker_stop(verbose = FALSE))

  # Only the Docker-specific field is cleared
  expect_true(is.na(.checkrefr_env$docker_container_id))
  expect_equal(.checkrefr_env$mode, "remote")
  expect_equal(.checkrefr_env$server_url, "https://kermitt2-grobid.hf.space")
  expect_equal(.checkrefr_env$docker_port, "8070")
})

test_that("grobid_docker_stop with an explicit container_id leaves env untouched", {
  local_checkrefr_env()

  .checkrefr_env$docker_container_id <- "my_own_container"
  .checkrefr_env$mode                <- "docker"
  .checkrefr_env$server_url          <- "http://localhost:8070"

  stop_args <- NULL

  local_mocked_bindings(
    .checkrefr_docker_installed = function() TRUE,
    .checkrefr_docker_running   = function() TRUE
  )

  local_mocked_bindings(
    system2 = function(command, args, ...) {
      if (identical(command, "docker")) {
        if ("inspect" %in% args) return("true")
        if ("stop" %in% args) {
          stop_args <<- args
          return("other_container")
        }
      }
      "ok"
    },
    .package = "base"
  )

  expect_true(grobid_docker_stop("other_container", verbose = FALSE))
  expect_equal(stop_args, c("stop", "other_container"))

  # The registered id does not match: no cleanup should happen
  expect_equal(.checkrefr_env$docker_container_id, "my_own_container")
  expect_equal(.checkrefr_env$mode, "docker")
  expect_equal(.checkrefr_env$server_url, "http://localhost:8070")
})


# ==== INTEGRATION TESTS (real Docker/network) =================================

test_that("grobid_docker_stop integration test works", {
  skip_if_not(
    identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"),
    "Integration tests disabled"
  )

  # Start a GROBID container via grobid_docker_start()
  start_success <- tryCatch({
    grobid_docker_start(verbose = FALSE)
    TRUE
  }, error = function(e) FALSE)

  skip_if_not(
    start_success,
    "Could not start the GROBID container for the integration test"
  )

  # The container id must be registered
  container_id <- CheckrefR:::.checkrefr_env$docker_container_id
  expect_false(is.na(container_id))

  # Call grobid_docker_stop() with no argument
  stop_res <- grobid_docker_stop(verbose = FALSE)
  expect_true(stop_res)

  # The CheckrefR environment must be reset to NA
  expect_true(is.na(.checkrefr_env$docker_container_id))
  expect_true(is.na(.checkrefr_env$mode))
  expect_true(is.na(.checkrefr_env$server_url))

  skip_if_not(.checkrefr_docker_installed() && .checkrefr_docker_running(),
              "Docker not available")

  # Stopping a second time must return FALSE harmlessly
  expect_false(grobid_docker_stop(verbose = FALSE))
})

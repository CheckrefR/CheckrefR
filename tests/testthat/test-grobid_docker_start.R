# Fichier : test-grobid_docker_start.R
# Edition 3 de {testthat} pour grobid_docker_start()
# Rappel convention skip : les tests d'integration se declenchent uniquement si RUN_INTEGRATION_TESTS="true"

# ==== TESTS UNITAIRES (mockes) ====

test_that("grobid_docker_start validates arguments correctly", {
  checkrefr_env_reset(verbose = FALSE)

  # docker_image validations
  expect_error(
    grobid_docker_start(docker_image = NULL),
    "must be a single non-empty character string"
  )
  expect_error(
    grobid_docker_start(docker_image = NA_character_),
    "must be a single non-empty character string"
  )
  expect_error(
    grobid_docker_start(docker_image = ""),
    "must be a single non-empty character string"
  )
  expect_error(
    grobid_docker_start(docker_image = "invalid image space"),
    "does not look like a valid Docker image reference"
  )

  # grobid_version validations
  expect_error(
    grobid_docker_start(grobid_version = NULL),
    "must be a single non-empty character string"
  )
  expect_error(
    grobid_docker_start(grobid_version = ""),
    "must be a single non-empty character string"
  )
  expect_error(
    grobid_docker_start(grobid_version = NA_character_),
    "must be a single non-empty character string"
  )

  # max_ram validations
  expect_error(
    grobid_docker_start(max_ram = NULL),
    "must be a single string of the form"
  )
  expect_error(
    grobid_docker_start(max_ram = "invalid"),
    "must be a single string of the form"
  )
  expect_error(
    grobid_docker_start(max_ram = "4"),
    "must be a single string of the form"
  )

  # port validations
  expect_error(
    grobid_docker_start(port = "abc"),
    "must be a single valid TCP port number"
  )
  expect_error(
    grobid_docker_start(port = -1),
    "must be a single valid TCP port number"
  )
  expect_error(
    grobid_docker_start(port = 999999),
    "must be a single valid TCP port number"
  )

  # pull validations
  expect_error(
    grobid_docker_start(pull = "yes"),
    "must be a single logical value"
  )
  expect_error(
    grobid_docker_start(pull = NA),
    "must be a single logical value"
  )

  # timeout_ready validations
  expect_error(
    grobid_docker_start(timeout_ready = -10),
    "must be a single positive number"
  )
  expect_error(
    grobid_docker_start(timeout_ready = "abc"),
    "must be a single positive number"
  )
})

test_that("grobid_docker_start launches container successfully (nominal case)", {
  checkrefr_env_reset(verbose = FALSE)

  local_mocked_bindings(
    .checkrefr_docker_installed = function(...) TRUE,
    .checkrefr_docker_running = function(...) TRUE,
    .checkrefr_container_active = function(...) FALSE,
    .checkrefr_port_is_free = function(...) TRUE,
    .checkrefr_image_exists = function(...) TRUE,
    .checkrefr_docker_wait_ready = function(...) TRUE
  )
  local_mocked_bindings(
    system2 = function(...) "mock_container_id_123",
    .package = "base"
  )

  res <- expect_invisible(grobid_docker_start(
    docker_image = "lfoppiano/grobid:",
    grobid_version = "0.9.0",
    model_type = "crf",
    port = 8070,
    max_ram = "4g",
    pull = FALSE,
    verbose = FALSE
  ))

  expect_true(res)

  # Check R internal environment variables updates
  expect_equal(.checkrefr_env$docker_container_id, "mock_container_id_123")
  expect_equal(.checkrefr_env$docker_port, "8070")
  expect_equal(.checkrefr_env$server_url, "http://localhost:8070")
  expect_equal(.checkrefr_env$mode, "docker")
  expect_equal(.checkrefr_env$docker_image, "lfoppiano/grobid:")
  expect_equal(.checkrefr_env$grobid_version, "0.9.0")
  expect_equal(.checkrefr_env$grobid_model_type, "crf")
})

test_that("grobid_docker_start attempts auto-start of daemon when running is FALSE", {
  checkrefr_env_reset(verbose = FALSE)

  running_calls <- 0L
  mock_running <- function(...) {
    running_calls <<- running_calls + 1L
    if (running_calls == 1L) {
      return(FALSE)
    }
    TRUE
  }

  start_docker_called <- FALSE
  mock_start_docker <- function(...) {
    start_docker_called <<- TRUE
    invisible(NULL)
  }

  local_mocked_bindings(
    .checkrefr_docker_installed = function(...) TRUE,
    .checkrefr_docker_running = mock_running,
    .start_docker = mock_start_docker,
    .checkrefr_container_active = function(...) FALSE,
    .checkrefr_port_is_free = function(...) TRUE,
    .checkrefr_image_exists = function(...) TRUE,
    .checkrefr_docker_wait_ready = function(...) TRUE
  )
  local_mocked_bindings(
    system2 = function(...) "mock_container_id_456",
    .package = "base"
  )

  res <- expect_invisible(grobid_docker_start(verbose = TRUE))
  expect_true(res)
  expect_true(start_docker_called)
  expect_equal(running_calls, 2L)
})

test_that("grobid_docker_start throws error when local port is in use", {
  checkrefr_env_reset(verbose = FALSE)

  local_mocked_bindings(
    .checkrefr_docker_installed = function(...) TRUE,
    .checkrefr_docker_running = function(...) TRUE,
    .checkrefr_container_active = function(...) FALSE,
    .checkrefr_port_is_free = function(...) FALSE
  )

  expect_error(
    grobid_docker_start(port = 8070),
    "Port 8070 is already in use by another process"
  )
})

test_that("grobid_docker_start throws error if docker run fails", {
  checkrefr_env_reset(verbose = FALSE)

  local_mocked_bindings(
    .checkrefr_docker_installed = function(...) TRUE,
    .checkrefr_docker_running = function(...) TRUE,
    .checkrefr_container_active = function(...) FALSE,
    .checkrefr_port_is_free = function(...) TRUE,
    .checkrefr_image_exists = function(...) TRUE
  )
  local_mocked_bindings(
    system2 = function(...) character(0),
    .package = "base"
  )

  expect_error(
    grobid_docker_start(verbose = FALSE),
    "Failed to launch the Docker container"
  )
})


# ==== TESTS D'INTEGRATION (Docker/reseau reels) ====

test_that("grobid_docker_start integration lifecycle", {
  skip_if_not(
    identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"),
    "Tests d'integration desactives"
  )

  # Cleanup at the end of execution to release resources
  on.exit(try(grobid_docker_stop(verbose = FALSE)), add = TRUE)

  # Retrieve and parse testing image configured in the CI pipeline
  test_image <- Sys.getenv("GROBID_TEST_IMAGE", unset = "lfoppiano/grobid:0.9.0-crf")
  parts <- strsplit(test_image, ":")[[1]]
  docker_image <- paste0(parts[1], ":")
  version_part <- parts[2]

  if (grepl("-", version_part)) {
    sub_parts <- strsplit(version_part, "-")[[1]]
    grobid_version <- sub_parts[1]
    model_type <- sub_parts[2]
  } else {
    grobid_version <- version_part
    model_type <- NA_character_
  }

  # Test with non-default ports to avoid collision during testing
  port1 <- 8070L
  port2 <- 8071L

  # 1. Start the container on port1
  res <- expect_invisible(grobid_docker_start(
    docker_image = docker_image,
    grobid_version = grobid_version,
    model_type = model_type,
    port = port1,
    verbose = TRUE
  ))
  expect_true(res)
  expect_equal(.checkrefr_env$mode, "docker")
  expect_equal(.checkrefr_env$server_url, paste0("http://localhost:", port1))

  # 2. Idempotency (redundant identical start)
  res_idem <- expect_invisible(grobid_docker_start(
    docker_image = docker_image,
    grobid_version = grobid_version,
    model_type = model_type,
    port = port1,
    verbose = TRUE
  ))
  expect_true(res_idem)

  # 3. Port/image configuration change triggers container replacement
  res_new <- expect_invisible(grobid_docker_start(
    docker_image = docker_image,
    grobid_version = grobid_version,
    model_type = model_type,
    port = port2,
    verbose = TRUE
  ))
  expect_true(res_new)
  expect_equal(.checkrefr_env$server_url, paste0("http://localhost:", port2))
})

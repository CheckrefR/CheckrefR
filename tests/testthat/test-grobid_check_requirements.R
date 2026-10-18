# Function: grobid_check_requirements
# Convention: Skipped when RUN_INTEGRATION_TESTS is not "true"

# ==== TESTS UNITAIRES (mockes) ====

test_that("grobid_check_requirements detects operating system correctly", {
  # Windows detection
  local_mocked_bindings(
    Sys.info = function() c(sysname = "Windows"),
    .package = "base"
  )
  res_win <- grobid_check_requirements(verbose = FALSE, check_docker = FALSE, check_remote = FALSE)
  expect_equal(res_win$os, "windows")

  # macOS detection
  local_mocked_bindings(
    Sys.info = function() c(sysname = "Darwin"),
    .package = "base"
  )
  res_mac <- grobid_check_requirements(verbose = FALSE, check_docker = FALSE, check_remote = FALSE)
  expect_equal(res_mac$os, "macos")

  # Linux detection
  local_mocked_bindings(
    Sys.info = function() c(sysname = "Linux"),
    .package = "base"
  )
  res_linux <- grobid_check_requirements(verbose = FALSE, check_docker = FALSE, check_remote = FALSE)
  expect_equal(res_linux$os, "linux")
})


test_that("grobid_check_requirements handles offline internet status without remote check", {
  local_mocked_bindings(
    .checkrefr_check_internet = function() FALSE,
    .checkrefr_ping = function(url, timeout = 5L) FALSE
  )

  expect_message(
    res <- grobid_check_requirements(verbose = TRUE, check_docker = FALSE, check_remote = FALSE),
    "unreachable"
  )

  expect_false(res$internet_available)
})

test_that("grobid_check_requirements falls back to remote server to confirm internet", {
  local_mocked_bindings(
    .checkrefr_check_internet = function() FALSE,
    .checkrefr_ping = function(url, timeout, ...) TRUE
  )

  # Warning is still emitted for Google, but internet is eventually TRUE
  expect_message(
    res <- grobid_check_requirements(verbose = TRUE, check_docker = FALSE, check_remote = TRUE),
    "Google unreachable"
  )

  expect_true(res$internet_available)
  expect_true(res$remote_default_reachable)
})

test_that("grobid_check_requirements handles missing Docker correctly", {
  local_mocked_bindings(
    .checkrefr_docker_installed = function() FALSE,
    .checkrefr_ping = function(...) FALSE
  )

  res <- grobid_check_requirements(verbose = FALSE, check_docker = TRUE, check_remote = FALSE)

  expect_false(res$docker_installed)
  expect_false(res$docker_running)
  expect_true(is.na(res$docker_version))
  expect_equal(res$recommended_mode, "none")
})

test_that("grobid_check_requirements prioritizes Docker even if daemon is stopped", {
  local_mocked_bindings(
    .checkrefr_docker_installed = function() TRUE,
    .checkrefr_docker_running = function() FALSE,
    .checkrefr_docker_version = function() "24.0.7"
  )

  res <- grobid_check_requirements(verbose = FALSE, check_docker = TRUE, check_remote = FALSE)

  expect_true(res$docker_installed)
  expect_false(res$docker_running)
  expect_equal(res$recommended_mode, "docker") # Docker-first policy
})

test_that("grobid_check_requirements runs silently when verbose is FALSE", {
  local_mocked_bindings(
    .checkrefr_check_internet = function() TRUE,
    .checkrefr_docker_installed = function() TRUE,
    .checkrefr_docker_running = function() TRUE,
    .checkrefr_docker_version = function() "24.0.7"
  )

  expect_silent({
    res <- grobid_check_requirements(verbose = FALSE, check_docker = TRUE, check_remote = FALSE)
  })

  expect_s3_class(res, "checkrefr_requirements")
})

# ==== TESTS D'INTEGRATION (Docker/reseau reels) ====

test_that("grobid_check_requirements runs successfully in a real environment", {
  skip_if_not(
    identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"),
    "Tests d'integration desactives"
  )

  res <- grobid_check_requirements(verbose = FALSE, check_docker = TRUE, check_remote = FALSE)

  expect_s3_class(res, "checkrefr_requirements")
  expect_true(res$internet_available)
  expect_true(res$docker_installed)
  expect_match(res$r_version, "^\\d+\\.\\d+(\\.\\d+)?")
})

test_that("grobid_check_requirements recommends docker in integration environment", {
  skip_if_not(
    identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"),
    "Tests d'integration desactives"
  )

  res <- grobid_check_requirements(verbose = FALSE, check_docker = TRUE, check_remote = FALSE)

  expect_equal(res$recommended_mode, "docker")
})

test_that("grobid_check_requirements inventories remote servers if requested", {
  skip_if_not(
    identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"),
    "Tests d'integration desactives"
  )

  res <- grobid_check_requirements(verbose = FALSE, check_docker = FALSE, check_remote = TRUE)

  expect_type(res$remote_reachable_urls, "list")
  expect_named(res$remote_reachable_urls, c("crf", "full"))
  expect_type(res$remote_reachable_urls$crf, "character")
  expect_type(res$remote_reachable_urls$full, "character")
})

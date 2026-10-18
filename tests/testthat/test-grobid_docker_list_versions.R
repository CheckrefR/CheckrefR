# Test script for grobid_docker_list_versions
#
# This file contains both unit tests (mocked, no external network or Docker dependency)
# and integration tests (requiring RUN_INTEGRATION_TESTS="true" and real Docker Hub connection).
#
# Integration tests are systematically skipped if RUN_INTEGRATION_TESTS != "true".

library(testthat)

# ==== TESTS UNITAIRES (mockes) ====

test_that("grobid_docker_list_versions returns a sorted tibble in nominal case (mocked)", {
  # Mock JSON response from Docker Hub API
  mock_json_response <- list(
    results = list(
      list(
        name = "0.9.0",
        full_size = 123456,
        last_updated = "2026-08-10T12:00:00Z",
        images = list(list(digest = "sha256:abc"))
      ),
      list(
        name = "0.8.0",
        full_size = 789012,
        last_updated = "2026-08-01T12:00:00Z",
        images = list(list(digest = "sha256:def"))
      )
    ),
    `next` = NULL
  )

  mock_resp <- list()
  class(mock_resp) <- "httr2_response"

  # Stub httr2 functions inside grobid_docker_list_versions (both with and without namespace)
  mockery::stub(grobid_docker_list_versions, "req_perform", mock_resp)
  mockery::stub(grobid_docker_list_versions, "httr2::req_perform", mock_resp)

  mockery::stub(grobid_docker_list_versions, "resp_status", 200L)
  mockery::stub(grobid_docker_list_versions, "httr2::resp_status", 200L)

  mockery::stub(grobid_docker_list_versions, "resp_body_json", mock_json_response)
  mockery::stub(grobid_docker_list_versions, "httr2::resp_body_json", mock_json_response)

  # Stub request and other pipeline steps to prevent real internet connection and pipeline failures
  mock_request <- function(url) {
    req <- list(url = url)
    class(req) <- "httr2_request"
    req
  }
  mockery::stub(grobid_docker_list_versions, "request", mock_request)
  mockery::stub(grobid_docker_list_versions, "httr2::request", mock_request)

  mock_identity <- function(req, ...) req
  mockery::stub(grobid_docker_list_versions, "req_timeout", mock_identity)
  mockery::stub(grobid_docker_list_versions, "httr2::req_timeout", mock_identity)
  mockery::stub(grobid_docker_list_versions, "req_error", mock_identity)
  mockery::stub(grobid_docker_list_versions, "httr2::req_error", mock_identity)

  # Call function invisibly
  res <- withr::with_options(
    list(cli.num_colors = 1),
    grobid_docker_list_versions(repository = "lfoppiano/grobid", verbose = FALSE)
  )

  # Assertions
  expect_s3_class(res, "tbl_df")
  expect_equal(nrow(res), 2)
  expect_named(res, c("name", "full_size", "last_updated", "digest"))
  expect_equal(res$name, c("0.9.0", "0.8.0"))
  expect_equal(res$full_size, c(123456, 789012))
  expect_equal(res$last_updated, c("2026-08-10T12:00:00Z", "2026-08-01T12:00:00Z"))
  expect_equal(res$digest, c("sha256:abc", "sha256:def"))
})

test_that("grobid_docker_list_versions handles no tags found case with a warning and empty tibble", {
  # Mock JSON response with empty results list
  mock_json_empty <- list(
    results = list(),
    `next` = NULL
  )

  mock_resp <- list()
  class(mock_resp) <- "httr2_response"

  mockery::stub(grobid_docker_list_versions, "req_perform", mock_resp)
  mockery::stub(grobid_docker_list_versions, "httr2::req_perform", mock_resp)

  mockery::stub(grobid_docker_list_versions, "resp_status", 200L)
  mockery::stub(grobid_docker_list_versions, "httr2::resp_status", 200L)

  mockery::stub(grobid_docker_list_versions, "resp_body_json", mock_json_empty)
  mockery::stub(grobid_docker_list_versions, "httr2::resp_body_json", mock_json_empty)

  # Stub request and other pipeline steps
  mock_request <- function(url) {
    req <- list(url = url)
    class(req) <- "httr2_request"
    req
  }
  mockery::stub(grobid_docker_list_versions, "request", mock_request)
  mockery::stub(grobid_docker_list_versions, "httr2::request", mock_request)

  mock_identity <- function(req, ...) req
  mockery::stub(grobid_docker_list_versions, "req_timeout", mock_identity)
  mockery::stub(grobid_docker_list_versions, "httr2::req_timeout", mock_identity)
  mockery::stub(grobid_docker_list_versions, "req_error", mock_identity)
  mockery::stub(grobid_docker_list_versions, "httr2::req_error", mock_identity)

  # Verify that a warning is emitted and check its structure
  expect_warning(
    {
      res <- grobid_docker_list_versions(repository = "lfoppiano/grobid", verbose = FALSE)
    },
    regexp = "No tag found for.*lfoppiano/grobid"
  )

  expect_s3_class(res, "tbl_df")
  expect_equal(nrow(res), 0)
  expect_named(res, c("name", "full_size", "last_updated", "digest"))
  expect_type(res$name, "character")
  expect_type(res$full_size, "double")
  expect_type(res$last_updated, "character")
  expect_type(res$digest, "character")
})

test_that("grobid_docker_list_versions resolves default repository when NULL", {

  orig_image <- .checkrefr_env$docker_image
  withr::defer(.checkrefr_env$docker_image <- orig_image)
  .checkrefr_env$docker_image <- "lfoppiano/grobid:"

   mock_json <- list(
    results = list(
      list(
        name = "0.9.0",
        full_size = 100,
        last_updated = "2026-08-10T12:00:00Z",
        images = list(list(digest = "sha256:abc"))
      )
    ),
    `next` = NULL
  )

  testthat::local_mocked_bindings(
    request = function(url) structure(list(url = url), class = "httr2_request"),
    req_timeout = function(req, ...) req,
    req_error = function(req, ...) req,
    req_perform = function(req) structure(list(), class = "httr2_response"),
    resp_status = function(resp) 200L,
    resp_body_json = function(resp, ...) mock_json,
    .package = "httr2"
  )

  # 3. Exécuter avec repository = NULL
  res <- grobid_docker_list_versions(repository = NULL, verbose = FALSE)

  # 4. Vérifier simplement qu'on a récupéré les données (preuve que le NULL est résolu)
  expect_s3_class(res, "tbl_df")
  expect_equal(nrow(res), 1)
  expect_equal(res$name, "0.9.0")
})

test_that("grobid_docker_list_versions respects verbose argument and suppresses CLI output", {
  mock_json_response <- list(
    results = list(
      list(
        name = "0.9.0",
        full_size = 123456,
        last_updated = "2026-08-10T12:00:00Z",
        images = list(list(digest = "sha256:abc"))
      )
    ),
    `next` = NULL
  )

  mock_resp <- list()
  class(mock_resp) <- "httr2_response"

  mockery::stub(grobid_docker_list_versions, "req_perform", mock_resp)
  mockery::stub(grobid_docker_list_versions, "httr2::req_perform", mock_resp)

  mockery::stub(grobid_docker_list_versions, "resp_status", 200L)
  mockery::stub(grobid_docker_list_versions, "httr2::resp_status", 200L)

  mockery::stub(grobid_docker_list_versions, "resp_body_json", mock_json_response)
  mockery::stub(grobid_docker_list_versions, "httr2::resp_body_json", mock_json_response)

  mock_identity <- function(req, ...) req
  mockery::stub(grobid_docker_list_versions, "req_timeout", mock_identity)
  mockery::stub(grobid_docker_list_versions, "httr2::req_timeout", mock_identity)
  mockery::stub(grobid_docker_list_versions, "req_error", mock_identity)
  mockery::stub(grobid_docker_list_versions, "httr2::req_error", mock_identity)

  mock_request <- function(url) {
    req <- list(url = url)
    class(req) <- "httr2_request"
    req
  }
  mockery::stub(grobid_docker_list_versions, "request", mock_request)
  mockery::stub(grobid_docker_list_versions, "httr2::request", mock_request)

  # Mock cli calls to verify no output is generated when verbose = FALSE
  mock_cli_alert <- mockery::mock()
  mock_cli_h1 <- mockery::mock()

  mockery::stub(grobid_docker_list_versions, "cli::cli_alert_info", mock_cli_alert)
  mockery::stub(grobid_docker_list_versions, "cli::cli_h1", mock_cli_h1)

  res <- grobid_docker_list_versions(repository = "lfoppiano/grobid", verbose = FALSE)

  mockery::expect_called(mock_cli_alert, 0)
  mockery::expect_called(mock_cli_h1, 0)
})


# ==== TESTS D'INTEGRATION (Docker/reseau reels) ====

test_that("grobid_docker_list_versions queries real Docker Hub API and returns valid tags", {
  skip_if_not(
    identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"),
    "Tests d'integration desactives (RUN_INTEGRATION_TESTS != 'true')"
  )

  # Call function without mocks
  res <- grobid_docker_list_versions(repository = "lfoppiano/grobid", verbose = FALSE)

  # Basic structure assertions
  expect_s3_class(res, "tbl_df")
  expect_gt(nrow(res), 0)
  expect_named(res, c("name", "full_size", "last_updated", "digest"))

  # Verify presence of standard GROBID tags
  expect_true(any(res$name %in% c("0.9.0", "0.9.1", "0.9.0-crf", "0.9.1-crf")))
})

test_that("grobid_docker_list_versions respects pagination and page_size limit", {
  skip_if_not(
    identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"),
    "Tests d'integration desactives (RUN_INTEGRATION_TESTS != 'true')"
  )

  # Pagination limit testing: page_size = 5, max_pages = 2
  res <- grobid_docker_list_versions(
    repository = "lfoppiano/grobid",
    page_size  = 5L,
    max_pages  = 2L,
    verbose    = FALSE
  )

  expect_s3_class(res, "tbl_df")
  expect_gt(nrow(res), 0)
  expect_lte(nrow(res), 10) # 5 elements per page * 2 pages maximum
  expect_named(res, c("name", "full_size", "last_updated", "digest"))
})

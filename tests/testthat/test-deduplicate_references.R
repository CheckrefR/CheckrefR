# test-deduplicate_references.R
# This file contains unit and integration tests for the deduplicate_references function.
# It uses the testthat (edition 3) testing framework.

# ==== TESTS UNITAIRES (mockes) ====

test_that("deduplicate_references throws error when required columns are missing", {
  # Verification of argument errors
  # The function requires: source_file, ref_n, score_global.

  bad_data <- data.frame(
    source_file = "test.pdf",
    ref_n = 1L,
    stringsAsFactors = FALSE
    # score_global is missing
  )

  expect_error(
    deduplicate_references(bad_data),
    regexp = "The following required columns are missing"
  )
})

test_that("deduplicate_references deduplicates references normally by keeping highest score", {
  # Deduplication nominal case
  # Mock the internal .print_validation_summary side effect to isolate unit tests
  local_mocked_bindings(
    .print_validation_summary = function(data) { NULL }
  )

  test_data <- data.frame(
    source_file = c("doc.pdf", "doc.pdf", "doc.pdf"),
    ref_n = c(1L, 1L, 2L),
    score_global = c(0.4, 0.85, 0.9),
    candidate_id = c("cand1", "cand2", "cand3"),
    stringsAsFactors = FALSE
  )

  result <- deduplicate_references(test_data, verbose = TRUE)

  # Structural assertions
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2L)
  expect_equal(ncol(result), 4L)

  # Logic assertions: only the best candidate per group (source_file, ref_n) is kept
  expect_equal(result$candidate_id, c("cand2", "cand3"))
  expect_equal(result$score_global, c(0.85, 0.9))
})

test_that("deduplicate_references resolves ties by keeping the first encountered row", {
  # Tie resolution (Ties)
  local_mocked_bindings(
    .print_validation_summary = function(data) { NULL }
  )

  test_data <- data.frame(
    source_file = c("doc.pdf", "doc.pdf"),
    ref_n = c(2L, 2L),
    score_global = c(0.9, 0.9),
    candidate_id = c("first_cand", "second_cand"),
    stringsAsFactors = FALSE
  )

  result <- deduplicate_references(test_data, verbose = TRUE)

  expect_equal(nrow(result), 1L)
  expect_equal(result$candidate_id, "first_cand")
})

test_that("deduplicate_references treats NA scores as -Inf", {
  # Handling of NA scores during comparison
  local_mocked_bindings(
    .print_validation_summary = function(data) { NULL }
  )

  test_data <- data.frame(
    source_file = c("doc.pdf", "doc.pdf"),
    ref_n = c(1L, 1L),
    score_global = c(NA_real_, 0.15),
    candidate_id = c("cand_na", "cand_015"),
    stringsAsFactors = FALSE
  )

  result <- deduplicate_references(test_data, verbose = TRUE)

  expect_equal(nrow(result), 1L)
  expect_equal(result$candidate_id, "cand_015")
  expect_equal(result$score_global, 0.15)
})

test_that("deduplicate_references respects verbose = FALSE", {
  # Silent mode execution
  called <- FALSE
  local_mocked_bindings(
    .print_validation_summary = function(data) {
      called <<- TRUE
    }
  )

  test_data <- data.frame(
    source_file = "doc.pdf",
    ref_n = 1L,
    score_global = 0.8,
    stringsAsFactors = FALSE
  )

  # When verbose = FALSE, .print_validation_summary should NOT be called
  result_silent <- deduplicate_references(test_data, verbose = FALSE)
  expect_false(called)

  # When verbose = TRUE, .print_validation_summary should be called
  result_verbose <- deduplicate_references(test_data, verbose = TRUE)
  expect_true(called)
})

test_that("deduplicate_references handles empty data frame correctly with early return", {
  # Cas d'un data.frame vide (0 ligne) - Maintenant pleinement intégré
  empty_data <- data.frame(
    source_file = character(),
    ref_n = integer(),
    score_global = numeric(),
    stringsAsFactors = FALSE
  )

  # Verbose = TRUE: should alert the user and return empty data
  expect_message(
    result <- deduplicate_references(empty_data, verbose = TRUE),
    regexp = "No references"
  )
  expect_equal(nrow(result), 0L)
  expect_s3_class(result, "data.frame")

  # Verbose = FALSE: should return silently without message
  expect_silent(
    result_silent <- deduplicate_references(empty_data, verbose = FALSE)
  )
  expect_equal(nrow(result_silent), 0L)
})



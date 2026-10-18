# Nom de la fonction : oa_matching_info
# Rappel de la convention de skip pour l'intégration :
# skip_if_not(identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"), "Tests d'integration desactives")

library(testthat)

# ==== TESTS UNITAIRES (mockes) ====

test_that("oa_matching_info returns correct structured list", {
  # Clean environment first
  checkrefr_env_reset(verbose = FALSE)

  # Retrieve info invisibly and check visibility
  res <- withVisible(oa_matching_info())

  expect_false(res$visible)
  expect_type(res$value, "list")
  expect_named(res$value, c("thresholds", "weights", "query_controls", "author_window", "truncation"))

  # Check respective subkeys and their names
  expect_named(res$value$thresholds, c("oa_probable_threshold", "oa_min_threshold", "oa_doi_threshold"))
  expect_named(res$value$weights, c("oa_w_title", "oa_w_authors", "oa_w_year"))
  expect_named(res$value$query_controls, c("oa_max_candidates", "oa_api_key"))
  expect_named(res$value$author_window, c("oa_use_window", "oa_window_size", "oa_large_author_threshold"))
  expect_named(res$value$truncation, c("oa_min_coverage_ratio", "oa_author_lambda", "oa_sym_max_diff_abs", "oa_sym_max_diff_prop"))
})

test_that("oa_matching_info integrates changes from checkrefr_set_defaults", {
  # Clean environment first
  checkrefr_env_reset(verbose = FALSE)
  on.exit(checkrefr_env_reset(verbose = FALSE), add = TRUE)

  # Modify default parameters via checkrefr_set_defaults
  checkrefr_set_defaults(
    oa_min_threshold = 0.55,
    oa_w_title = 0.70,
    oa_max_candidates = 5L
  )

  res <- oa_matching_info()

  expect_equal(res$thresholds$oa_min_threshold, 0.55)
  expect_equal(res$weights$oa_w_title, 0.70)
  expect_equal(res$query_controls$oa_max_candidates, 5L)
})

test_that("oa_matching_info prints expected formatted console output", {
  checkrefr_env_reset(verbose = FALSE)

  captured_lines <- character()
  withCallingHandlers(
    {
      oa_matching_info()
    },
    cliMessage = function(msg) {
      captured_lines <<- c(captured_lines, msg$message)
      invokeRestart("muffleMessage")
    }
  )

  output_str <- cli::ansi_strip(paste(captured_lines, collapse = "\n"))

  expect_match(output_str, "OpenAlex Matching Parameters", fixed = TRUE)
  expect_match(output_str, "Score Thresholds", fixed = TRUE)
  expect_match(output_str, "Scoring Weights", fixed = TRUE)
  expect_match(output_str, "Query Controls", fixed = TRUE)
  expect_match(output_str, "Author Window Strategy", fixed = TRUE)
  expect_match(output_str, "Truncation Penalty & Symmetry", fixed = TRUE)
})

test_that("oa_matching_info handles NA values gracefully without crashing", {
  checkrefr_env_reset(verbose = FALSE)
  on.exit(checkrefr_env_reset(verbose = FALSE), add = TRUE)

  # Set parameters to NA to verify formulators (.fmt_num, .fmt_bool, .fmt_mail)
  checkrefr_set_defaults(
    oa_api_key = NA_character_,
    oa_probable_threshold = NA_real_
  )

  res <- oa_matching_info()
  expect_true(is.na(res$query_controls$oa_api_key))
  expect_true(is.na(res$thresholds$oa_probable_threshold))

  captured_lines <- character()
  withCallingHandlers(
    {
      oa_matching_info()
    },
    cliMessage = function(msg) {
      captured_lines <<- c(captured_lines, msg$message)
      invokeRestart("muffleMessage")
    }
  )
  output_str <- cli::ansi_strip(paste(captured_lines, collapse = "\n"))

  # Ensure the formatter functions correctly output 'NA' and '(not set)'
  expect_match(output_str, "NA", fixed = TRUE)
  expect_match(output_str, "not set", fixed = TRUE)
})

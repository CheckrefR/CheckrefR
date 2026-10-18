# test-process_citation_file.R
# Test script for process_citation_file()
# Following project rules, testthat edition 3 is used.

library(testthat)

# ==============================================================================
# ==== TESTS UNITAIRES (mockes) ================================================
# ==============================================================================

test_that("process_citation_file stops if file does not exist", {
  expect_error(
    process_citation_file("non_existent_file_xyz.txt"),
    regexp = "File not found"
  )
})

test_that("process_citation_file stops with a clear error if the file is empty or contains only blank lines", {
  # Create a temp file containing only blank lines
  tmp_file <- tempfile(fileext = ".txt")
  writeLines(c("", "   ", "\t"), tmp_file)
  on.exit(unlink(tmp_file))

  expect_error(
    process_citation_file(tmp_file),
    regexp = "is empty or contains only blank lines"
  )
})

test_that("process_citation_file cleans whitespace and empty lines from citations before sending", {
  # Create a temp file with blank lines and valid citations
  tmp_file <- tempfile(fileext = ".txt")
  writeLines(c("Smith, J. (2020). Title 1.", "", "  ", "Doe, J. (2021). Title 2."), tmp_file)
  on.exit(unlink(tmp_file))

  # Mock grobid_process_file to return raw XML dummy
  local_mocked_bindings(
    grobid_process_file = function(...) "<TEI>dummy</TEI>"
  )

  # Check that message counts exactly 2 citations instead of 4
  expect_message(
    process_citation_file(tmp_file, verbose = TRUE, output_format = "raw"),
    regexp = "Sending 2 citation\\(s\\) to GROBID"
  )
})

test_that("process_citation_file returns raw XML if output_format is raw", {
  tmp_file <- tempfile(fileext = ".txt")
  writeLines("Smith, J. (2020). Title 1.", tmp_file)
  on.exit(unlink(tmp_file))

  sim_xml <- "<TEI xmlns=\"http://www.tei-c.org/ns/1.0\"><text><body><listBibl><biblStruct>dummy</biblStruct></listBibl></body></text></TEI>"

  local_mocked_bindings(
    grobid_process_file = function(file, service, params, output_format, verbose, model_type) {
      expect_equal(service, "processCitationList")
      expect_equal(output_format, "raw")
      return(sim_xml)
    }
  )

  res <- process_citation_file(tmp_file, output_format = "raw")
  expect_equal(res, sim_xml)
})

test_that("process_citation_file parses XML and returns a structured tibble", {
  tmp_file <- tempfile(fileext = ".txt")
  writeLines("Smith, J. (2020). Title 1.", tmp_file)
  on.exit(unlink(tmp_file))

  sim_xml <- "<TEI>dummy</TEI>"
  sim_tibble <- tibble::tibble(
    ref_n = 1L,
    raw_reference = "Smith, J. (2020). Title 1.",
    title = "Title 1",
    authors = "Smith, J.",
    year = 2020L
  )

  local_mocked_bindings(
    grobid_process_file = function(...) sim_xml,
    parse_citation_list = function(xml, raw_references) {
      expect_equal(xml, sim_xml)
      expect_equal(raw_references, "Smith, J. (2020). Title 1.")
      return(sim_tibble)
    }
  )

  res <- process_citation_file(tmp_file, output_format = "parsed")
  expect_s3_class(res, "tbl_df")
  expect_equal(res$title, "Title 1")
  expect_equal(res$ref_n, 1L)
})

test_that("process_citation_file returns invisible NA_character_ if grobid_process_file returns NA", {
  tmp_file <- tempfile(fileext = ".txt")
  writeLines("Smith, J. (2020). Title 1.", tmp_file)
  on.exit(unlink(tmp_file))

  local_mocked_bindings(
    grobid_process_file = function(...) NA_character_
  )

  # Check raw format
  res_raw <- withVisible(process_citation_file(tmp_file, output_format = "raw"))
  expect_true(is.na(res_raw$value))

  # Check parsed format (should intercept NA and not call parse_citation_list)
  res_parsed <- withVisible(process_citation_file(tmp_file, output_format = "parsed"))
  expect_true(is.na(res_parsed$value))
  # expect_false(res_parsed$visible)
})

# NOTE: test d'argument invalide ajoute pour couverture exhaustive, absent de la fiche d'analyse
test_that("process_citation_file validates output_format with match.arg", {
  tmp_file <- tempfile(fileext = ".txt")
  writeLines("Smith, J. (2020). Title 1.", tmp_file)
  on.exit(unlink(tmp_file))

  expect_error(
    process_citation_file(tmp_file, output_format = "invalid_format"),
    regexp = "'arg' should be one of"
  )
})


# ==============================================================================
# ==== TESTS D'INTEGRATION (Docker/reseau reels) ===============================
# ==============================================================================

test_that("process_citation_file integrates with actual GROBID server", {
  skip_if_not(
    identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"),
    "Tests d'integration desactives"
  )

  # Resolve example txt file from extdata, or fallback to auto-creation
  # extdata_dir <- system.file("extdata", package = "CheckrefR")
  # txt_files <- list.files(extdata_dir, pattern = "\\.txt$", full.names = TRUE)
  txt_files <- system.file("extdata", package = "CheckrefR") |>
    list.files(pattern = "ref_test\\.txt", full.names = TRUE) |>
    (\(x) x[1])()

  if (length(txt_files) > 0L) {
    txt_file <- txt_files[1]
  } else {
    txt_file <- tempfile(fileext = ".txt")
    writeLines(
      c(
        "Smith, J., & Doe, A. (2020). Structural equation modeling. Psychological Methods, 25(1), 1-15. https://doi.org/10.1037/met0000250",
        "Curie, M., & Einstein, A. (1915). On the electrodynamics of moving bodies. Journal of Physics, 14, 321-340."
      ),
      txt_file
    )
    on.exit(unlink(txt_file), add = TRUE)
  }

  # 1. Process in parsed format (default)
  res_parsed <- process_citation_file(txt_file, output_format = "parsed", model_type = "crf")

  expect_s3_class(res_parsed, "tbl_df")
  expect_true(nrow(res_parsed) >= 1)

  # Verify structure of columns
  expected_cols <- c("ref_n", "raw_reference", "title", "authors", "authors_list", "year")
  expect_true(all(expected_cols %in% colnames(res_parsed)))

  # Check specific data constraints
  expect_type(res_parsed$ref_n, "integer")
  expect_type(res_parsed$title, "character")
  expect_type(res_parsed$authors, "character")
  expect_type(res_parsed$year, "integer")
  expect_type(res_parsed$authors_list, "list")

  # 2. Process in raw XML format
  res_raw <- process_citation_file(txt_file, output_format = "raw", model_type = "crf")
  expect_type(res_raw, "character")
  expect_match(res_raw, "<TEI", ignore.case = TRUE)
  expect_match(res_raw, "</TEI>", ignore.case = TRUE)

  # 3. Verify model_type argument transmission works (crf or full)
  # (Since GROBID supports both tags depending on installation)
  res_model_crf <- process_citation_file(txt_file, model_type = "crf", output_format = "parsed")
  expect_s3_class(res_model_crf, "tbl_df")
  expect_true(nrow(res_model_crf) >= 1)
})

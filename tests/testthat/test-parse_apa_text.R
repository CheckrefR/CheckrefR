# test-parse_apa_text.R
# Fonction : parse_apa_text
# Convention : Les tests d'intégration nécessitent RUN_INTEGRATION_TESTS = "true" et un conteneur Grobid actif.
#              Les tests unitaires sont mockés et s'exécutent sur tous les OS sans dépendance externe.

library(testthat)

# ==== TESTS UNITAIRES (mockes) ====

# NOTE: Aucune dépendance système (system2), réseau (HTTP) ou Docker n'est appelée par cette fonction locale.
# Par conséquent, aucun mock (local_mocked_bindings ou mockery::stub) n'est techniquement nécessaire ici.

test_that("Validation of inputs throws correct errors", {
  # 1. Non-character, non-data.frame input
  expect_error(
    parse_apa_text(list(a = 1)),
    regexp = "must be: a path to a"
  )

  # 2. Data frame with multiple columns
  expect_error(
    parse_apa_text(data.frame(a = "ref", b = "ref")),
    regexp = "with a single column"
  )

  # 3. Data frame with no rows/references
  expect_error(
    parse_apa_text(data.frame(a = character(0))),
    regexp = "does not contain any usable reference"
  )

  # 4. Empty character vector / empty strings
  expect_error(
    parse_apa_text("   "),
    regexp = "does not contain any usable reference"
  )

  # 5. Non-existent .txt file
  expect_error(
    parse_apa_text("missing_references_file_xyz.txt"),
    regexp = "does not exist"
  )
})

test_that("Reading empty file raises expected error", {
  temp_file <- tempfile(fileext = ".txt")
  writeLines(character(0), temp_file)
  on.exit(unlink(temp_file), add = TRUE)

  expect_error(
    parse_apa_text(temp_file),
    regexp = "does not contain any usable reference"
  )
})

test_that("Reading a valid .txt file parses references correctly", {
  temp_file <- tempfile(fileext = ".txt")
  writeLines(
    c(
      "Smith, J. (2020). Title of paper. Journal, 12(3), 45-67. https://doi.org/10.1234/xyz",
      "Doe, J., & Roe, R. (2019). Title two. Journal, 5(1), 1-10."
    ),
    temp_file
  )
  on.exit(unlink(temp_file), add = TRUE)

  res <- parse_apa_text(temp_file, as_ref_df = FALSE)
  expect_s3_class(res, "data.frame")
  expect_equal(nrow(res), 2)
  expect_equal(res$publication_year, c(2020, 2019))
  expect_equal(res$doi, c("10.1234/xyz", NA_character_))
  expect_equal(res$title, c("Title of paper", "Title two"))
})

test_that("Nominal extraction with as_ref_df = FALSE parses fields correctly", {
  ref <- "Smith, J., & Doe, R. (2020). Amazing paper. Journal of Science, 1(1), 10-15. https://doi.org/10.1234/xyz"
  res <- parse_apa_text(ref, as_ref_df = FALSE)

  expect_s3_class(res, "data.frame")
  expect_equal(nrow(res), 1)
  expect_equal(res$publication_year, 2020)
  expect_equal(res$doi, "10.1234/xyz")
  expect_equal(res$title, "Amazing paper")
  expect_equal(res$authorships, "Smith, J; Doe, R")

  # Check the structure of authorships_list
  expect_type(res$authorships_list, "list")
  auth_df <- res$authorships_list[[1]]
  expect_s3_class(auth_df, "data.frame")
  expect_equal(ncol(auth_df), 2)
  expect_named(auth_df, c("first_name", "last_name"))
  expect_equal(auth_df$first_name, c("J", "R"))
  expect_equal(auth_df$last_name, c("Smith", "Doe"))
})

test_that("Validation mode (as_ref_df = TRUE) returns expected schema and content", {
  refs <- c(
    "Smith, J. (2020). Title one. Journal, 12(3), 45-67.",
    "Doe, J., & Roe, R. (2019). Title two. Journal, 5(1), 1-10. https://doi.org/10.1234/xyz"
  )

  res <- parse_apa_text(refs, as_ref_df = TRUE, source_file_label = "Custom_Label")

  expect_s3_class(res, "tbl_df")
  expect_equal(nrow(res), 2)
  expect_named(res, c("raw_reference","source_file", "ref_n", "title", "doi", "year", "authors", "authors_list"))

  expect_equal(res$source_file, c("Custom_Label", "Custom_Label"))
  expect_equal(res$ref_n, c(1L, 2L)) # Sequential numbering
  expect_equal(res$year, c(2020, 2019))
  expect_equal(res$doi, c(NA_character_, "10.1234/xyz"))
  expect_equal(res$title, c("Title one", "Title two"))
  expect_equal(res$authors, c("Smith, J", "Doe, J; Roe, R"))

  # Verify authors_list column
  expect_type(res$authors_list, "list")
  expect_s3_class(res$authors_list[[1]], "data.frame")
  expect_equal(res$authors_list[[1]]$last_name, "Smith")
  expect_equal(res$authors_list[[1]]$first_name, "J")

  expect_equal(res$authors_list[[2]]$last_name, c("Doe", "Roe"))
  expect_equal(res$authors_list[[2]]$first_name, c("J", "R"))
})

test_that("Robustness to degenerate formats returns NA cleanly without error", {
  # No year, no period after title, completely missing APA format
  ref_degraded <- "Smith J Title of paper without proper APA formatting"
  res <- parse_apa_text(ref_degraded, as_ref_df = FALSE)

  expect_s3_class(res, "data.frame")
  expect_equal(nrow(res), 1)
  expect_true(is.na(res$publication_year))
  expect_true(is.na(res$doi))
  expect_true(is.na(res$title))
  expect_true(is.na(res$authorships))
  expect_equal(nrow(res$authorships_list[[1]]), 0)

  # Year is present but invalid/not matching standard (YYYY)
  ref_bad_year <- "Smith, J. (in press). Some Title. Journal."
  res_bad_year <- parse_apa_text(ref_bad_year, as_ref_df = FALSE)
  expect_true(is.na(res_bad_year$publication_year))

  # Title without terminating period
  ref_no_title_dot <- "Smith, J. (2020). Title without dot"
  res_no_title_dot <- parse_apa_text(ref_no_title_dot, as_ref_df = FALSE)
  expect_true(is.na(res_no_title_dot$title))
})


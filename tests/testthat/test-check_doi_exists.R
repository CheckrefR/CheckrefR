

# ==== TESTS UNITAIRES (mockes) ====

test_that("check_doi_exists raises explicit errors for invalid arguments", {
  # doi is not character
  expect_error(
    check_doi_exists(doi = 123),
    regexp = "\`doi\` must be a character string or character vector."
  )
  expect_error(
    check_doi_exists(doi = TRUE),
    regexp = "\`doi\` must be a character string or character vector."
  )

  # named is not logical or of length != 1
  expect_error(
    check_doi_exists("10.1126/science.169.3946.635", named = "invalid"),
    regexp = "\`named\` must be a single logical value \\(TRUE or FALSE\\)."
  )
  expect_error(
    check_doi_exists("10.1126/science.169.3946.635", named = c(TRUE, FALSE)),
    regexp = "\`named\` must be a single logical value \\(TRUE or FALSE\\)."
  )
})

test_that("check_doi_exists handles syntactically invalid or missing DOIs without calling network", {
  # We mock .check_single_doi to fail if it is called,
  # to guarantee no network call is made for invalid DOIs.
  local_mocked_bindings(
    .check_single_doi = function(doi_norm) {
      stop("Should not be called for invalid DOIs!")
    }
  )

  invalid_dois <- c("invalid_doi_syntax", NA, "10.abc/123", "")

  result <- check_doi_exists(invalid_dois)

  expect_identical(result, rep(NA, length(invalid_dois)))
})

test_that("check_doi_exists manages names correctly based on 'named' argument", {
  # Mocking .check_single_doi to avoid real network queries
  local_mocked_bindings(
    .check_single_doi = function(doi_norm) {
      TRUE
    }
  )

  dois <- c("10.1126/science.169.3946.635", "HTTPS://DOI.ORG/10.1126/science.169.3946.636")

  # Case 1: named = TRUE
  res_named <- check_doi_exists(dois, named = TRUE)
  expect_named(res_named, c("10.1126/science.169.3946.635", "10.1126/science.169.3946.636"))
  expect_equal(unname(res_named), c(TRUE, TRUE))

  # Case 2: named = FALSE (default)
  res_unnamed <- check_doi_exists(dois, named = FALSE)
  expect_null(names(res_unnamed))
  expect_equal(res_unnamed, c(TRUE, TRUE))
})

test_that("check_doi_exists correctly handles mocked .check_single_doi responses", {
  # 1. Positive response (TRUE)
  local_mocked_bindings(
    .check_single_doi = function(doi_norm) {
      TRUE
    }
  )
  expect_true(check_doi_exists("10.1126/science.169.3946.635"))

  # 2. Negative response (FALSE)
  local_mocked_bindings(
    .check_single_doi = function(doi_norm) {
      FALSE
    }
  )
  expect_false(check_doi_exists("10.9999/this-doi-does-not-exist"))

  # 3. Network or other failure (FALSE)
  # According to the pre-test analysis sheet: "Renvoie FALSE pour cet element."
  local_mocked_bindings(
    .check_single_doi = function(doi_norm) {
      FALSE
    }
  )
  expect_false(check_doi_exists("10.1126/science.169.3946.635"))
})

# ==== TESTS D'INTEGRATION (Docker/reseau reels) ====

test_that("check_doi_exists resolves a real valid DOI over the network", {
  skip_if_not(
    identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"),
    "Tests d'integration desactives"
  )

  # Real valid DOI
  expect_true(check_doi_exists("10.1126/science.169.3946.635"))
})

test_that("check_doi_exists returns FALSE for a real non-existent DOI over the network", {
  skip_if_not(
    identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"),
    "Tests d'integration desactives"
  )

  # Real non-existent DOI (but syntactically valid)
  expect_false(check_doi_exists("10.9999/this-doi-does-not-exist"))
})

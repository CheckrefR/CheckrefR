# Fichier de test : test-grobid_process_file.R
# Fonction cible : grobid_process_file()
#
# Rappel de la convention de skip :
# Les tests unitaires sont exécutés sur tous les environnements sans dépendance à Docker/réseau.
# Les tests d'intégration sont exécutés uniquement si Sys.getenv("RUN_INTEGRATION_TESTS") == "true".

# ==== TESTS UNITAIRES (mockes) ====

test_that("grobid_process_file raises an error for an unknown service", {
  expect_error(
    grobid_process_file(file = "test.pdf", service = "invalid_service"),
    "Unknown service:"
  )
})

test_that("grobid_process_file raises appropriate file validation errors", {
  # File not found
  expect_error(
    grobid_process_file(file = "non_existent_file.pdf"),
    "File not found:"
  )

  # Incorrect extension (.txt instead of .pdf for processFulltextDocument)
  tmp_file <- tempfile(fileext = ".txt")
  writeLines("content", tmp_file)
  on.exit(unlink(tmp_file), add = TRUE)

  expect_error(
    grobid_process_file(file = tmp_file, service = "processFulltextDocument"),
    "Incorrect extension for service"
  )

  # Multiple files for single-file services
  expect_error(
    grobid_process_file(file = c("file1.pdf", "file2.pdf")),
    "requires a single file path"
  )
})

test_that("grobid_process_file returns raw XML/TEI intact when output_format is 'raw'", {
  tmp_pdf <- tempfile(fileext = ".pdf")
  writeLines("dummy pdf", tmp_pdf)
  on.exit(unlink(tmp_pdf), add = TRUE)

  fake_xml <- "<TEI>mocked XML content</TEI>"

  local_mocked_bindings(
    .checkrefr_ensure_server = function(...) TRUE,
    .grobid_retry_call = function(...) fake_xml
  )

  res <- grobid_process_file(
    file = tmp_pdf,
    service = "processFulltextDocument",
    output_format = "raw",
    verbose = FALSE
  )

  expect_equal(res, fake_xml)
})

test_that("grobid_process_file correctly dispatches parsing and returns parsed results", {
  tmp_pdf <- tempfile(fileext = ".pdf")
  writeLines("dummy pdf", tmp_pdf)
  on.exit(unlink(tmp_pdf), add = TRUE)

  fake_xml <- "<TEI>mocked XML content</TEI>"
  fake_tibble <- tibble::tibble(
    section_type = "title",
    content = "mocked title"
  )

  local_mocked_bindings(
    .checkrefr_ensure_server = function(...) TRUE,
    .grobid_retry_call = function(...) fake_xml,
    .grobid_dispatch_parse = function(service, xml_text, source_file, raw_references = NULL) {
      fake_tibble$source_file <- basename(source_file)
      fake_tibble
    }
  )

  res <- grobid_process_file(
    file = tmp_pdf,
    service = "processFulltextDocument",
    output_format = "parsed",
    verbose = FALSE
  )

  expect_s3_class(res, "tbl_df")
  expect_equal(ncol(res), 3L)
  expect_equal(res$source_file, basename(tmp_pdf))
  expect_equal(res$content, "mocked title")
})

test_that("grobid_process_file correctly handles a character vector of citations for processCitationList", {
  citations_input <- c("Dupont, J. (2020). Titre 1.", "Smith, A. (2021). Titre 2.")

  captured_file_path <- NA_character_
  file_existed_during_call <- FALSE
  captured_content <- character(0)

  local_mocked_bindings(
    .checkrefr_ensure_server = function(...) TRUE,
    .grobid_retry_call = function(endpoint, file_path, params, user_agent) {
      captured_file_path <<- file_path
      file_existed_during_call <<- file.exists(file_path)
      if (file_existed_during_call) {
        captured_content <<- readLines(file_path)
      }
      return("<TEI>mocked citation xml</TEI>")
    },
    .grobid_dispatch_parse = function(service, xml_text, source_file, raw_references = NULL) {
      tibble::tibble(
        ref_n = 1:2,
        title = c("Titre 1", "Titre 2"),
        source_file = basename(source_file)
      )
    }
  )

  res <- grobid_process_file(
    file = citations_input,
    service = "processCitationList",
    output_format = "parsed",
    verbose = FALSE
  )

  expect_true(file_existed_during_call)
  expect_match(captured_file_path, "tmp|temp")
  expect_equal(captured_content, citations_input)
  expect_false(file.exists(captured_file_path))
  expect_s3_class(res, "tbl_df")
  expect_equal(nrow(res), 2L)
})

test_that("grobid_process_file handles network errors or empty API response by issuing a warning and returning NA", {
  tmp_pdf <- tempfile(fileext = ".pdf")
  writeLines("dummy pdf", tmp_pdf)
  on.exit(unlink(tmp_pdf), add = TRUE)

  local_mocked_bindings(
    .checkrefr_ensure_server = function(...) TRUE,
    .grobid_retry_call = function(...) NA_character_
  )

  expect_warning(
    {
      res <- grobid_process_file(
        file = tmp_pdf,
        service = "processFulltextDocument",
        output_format = "raw",
        verbose = FALSE
      )
    },
    "No result for"
  )

  expect_true(is.na(res))
})


# ==== TESTS D'INTEGRATION (Docker/reseau reels) ====

test_that("integration: grobid_process_file successfully extracts a sample PDF with a real Docker container", {
  skip_if_not(
    identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"),
    "Tests d'integration desactives"
  )

  pdf_file <- system.file("extdata", package = "CheckrefR") |>
    list.files(pattern = "\\.pdf$", full.names = TRUE) |>
    (\(x) x[1])()

  skip_if(length(pdf_file) == 0 || !file.exists(pdf_file), "Fichier PDF d'exemple non disponible")

  res <- grobid_process_file(
    file          = pdf_file,
    service       = "processReferences",
    output_format = "parsed",
    mode          = "docker",
    verbose       = FALSE
  )

  expect_s3_class(res, "tbl_df")
  expect_true(nrow(res) >= 1)
  expect_named(res)
  expect_true("source_file" %in% names(res))
  expect_match(res$source_file[1], "pdf$", ignore.case = TRUE)
})

test_that("integration: grobid_process_file works in remote mode if a server is available", {
  skip_if_not(
    identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"),
    "Tests d'integration desactives"
  )

  has_remote <- tryCatch({
    grobid_remote_connect(verbose = FALSE)
    TRUE
  }, error = function(e) FALSE)

  skip_if_not(has_remote, "Aucun serveur GROBID distant n'est accessible pour les tests")

  pdf_file <- system.file("extdata", package = "CheckrefR") |>
    list.files(pattern = "\\.pdf$", full.names = TRUE) |>
    (\(x) x[1])()

  skip_if(length(pdf_file) == 0 || !file.exists(pdf_file), "Fichier PDF d'exemple non disponible")

  res <- grobid_process_file(
    file          = pdf_file,
    service       = "processReferences",
    output_format = "parsed",
    mode          = "remote",
    verbose       = FALSE
  )

  expect_s3_class(res, "tbl_df")
  expect_true(nrow(res) >= 1)
  expect_true("source_file" %in% names(res))
})

test_that("integration: grobid_process_file with processCitationList parses a vector of real citations", {
  skip_if_not(
    identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"),
    "Tests d'integration desactives"
  )

  citations_input <- c(
    "Smith, J., & Doe, R. (2020). Testing in R. Journal of Testing, 10(2), 100-110.",
    "Curie, M. (1903). Recherches sur les substances radioactives. Gauthier-Villars."
  )

  res <- grobid_process_file(
    file          = citations_input,
    service       = "processCitationList",
    output_format = "parsed",
    verbose       = FALSE
  )

  expect_s3_class(res, "tbl_df")
  expect_true(nrow(res) >= 1)
  expect_true("title" %in% names(res))
  expect_match(res$source_file[1], ".*\\.txt$")
})

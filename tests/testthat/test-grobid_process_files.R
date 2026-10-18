# Nom de la fonction : grobid_process_files
# Convention de skip : skip_if_not(identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"), "Tests d'integration desactives")

# ==== TESTS UNITAIRES (mockes) ====

test_that("grobid_process_files throws an error when files vector is empty", {
  # Aucun controle direct specifique pour les autres arguments n'est detecte dans la fiche d'analyse,
  # donc seul le controle du vecteur 'files' vide est verifie ici.
  expect_error(
    grobid_process_files(character(0)),
    "The vector .*files.* is empty"
  )
})

test_that("grobid_process_files works sequentially in nominal case (parallel = FALSE)", {
  local_mocked_bindings(
    .checkrefr_ensure_server = function(...) NULL,
    grobid_process_file = function(file, ...) {
      data.frame(
        title = paste0("title_", basename(file)),
        source_file = basename(file),
        stringsAsFactors = FALSE
      )
    }
  )

  res <- grobid_process_files(c("file1.pdf", "file2.pdf"), parallel = FALSE, progress = FALSE)

  expect_s3_class(res, "data.frame")
  expect_equal(ncol(res), 2)
  expect_equal(res$title, c("title_file1.pdf", "title_file2.pdf"))
  expect_equal(res$source_file, c("file1.pdf", "file2.pdf"))
})

test_that("grobid_process_files invokes pbapply when progress is TRUE and parallel is FALSE", {
  pb_called <- FALSE
  local_mocked_bindings(
    .checkrefr_ensure_server = function(...) NULL,
    grobid_process_file = function(file, ...) {
      data.frame(
        title = paste0("title_", basename(file)),
        source_file = basename(file),
        stringsAsFactors = FALSE
      )
    }
  )
  local_mocked_bindings(
    pblapply = function(X, FUN, ...) {
      pb_called <<- TRUE
      lapply(X, FUN, ...)
    },
    .package = "pbapply"
  )

  res <- grobid_process_files(c("file1.pdf", "file2.pdf"), parallel = FALSE, progress = TRUE)
  expect_true(pb_called)
})

# test_that("grobid_process_files works in parallel mode (parallel = TRUE)", {
#   plan_calls <- list()
#
#   # Mock de la fonction interne du package et de grobid_process_file
#   local_mocked_bindings(
#     .checkrefr_ensure_server = function(...) NULL,
#     grobid_process_file = function(file, ...) {
#       data.frame(
#         title = paste0("title_", basename(file)),
#         source_file = basename(file),
#         stringsAsFactors = FALSE
#       )
#     }
#   )
#
#   # Mock de future::plan appele avec :: dans le package
#   local_mocked_bindings(
#     plan = function(strategy, ...) {
#       plan_calls[[length(plan_calls) + 1]] <<- strategy
#       NULL
#     },
#     .package = "future"
#   )
#
#   # Mock de future.apply::future_lapply appele avec :: dans le package
#   local_mocked_bindings(
#     future_lapply = function(X, FUN, ...) {
#       lapply(X, FUN, ...)
#     },
#     .package = "future.apply"
#   )
#
#   res <- grobid_process_files(c("file1.pdf", "file2.pdf"), parallel = TRUE, n_workers = 2, progress = FALSE)
#
#   expect_s3_class(res, "data.frame")
#   expect_equal(res$title, c("title_file1.pdf", "title_file2.pdf"))
#   expect_true(length(plan_calls) >= 1)
#   expect_match(
#     as.character(attr(plan_calls[[1]], "class")[1]),
#     "multisession"
#   )
# })

test_that("grobid_process_files works in parallel mode (parallel = TRUE)", {
  plan_calls <- list()

  # Mock des fonctions internes du package
  local_mocked_bindings(
    .checkrefr_ensure_server = function(...) NULL,
    grobid_process_file = function(file, ...) {
      data.frame(
        title = paste0("title_", basename(file)),
        source_file = basename(file),
        stringsAsFactors = FALSE
      )
    }
  )

  # Rend le test independant du nombre de coeurs du runner (CI : 1-2 coeurs)
  local_mocked_bindings(
    detectCores = function(...) 8L,
    .package = "parallel"
  )

  # Mock de future::plan (appele avec :: dans le package)
  local_mocked_bindings(
    plan = function(strategy, ...) {
      plan_calls[[length(plan_calls) + 1]] <<- strategy
      NULL
    },
    .package = "future"
  )

  # Mock de future.apply::future_lapply (appele avec :: dans le package)
  local_mocked_bindings(
    future_lapply = function(X, FUN, ...) {
      lapply(X, FUN, ...)
    },
    .package = "future.apply"
  )

  res <- grobid_process_files(
    c("file1.pdf", "file2.pdf"),
    parallel = TRUE,
    n_workers = 2,
    progress = FALSE,
    mode = "docker"
  )

  expect_s3_class(res, "data.frame")
  expect_equal(res$title, c("title_file1.pdf", "title_file2.pdf"))

  # plan() doit avoir ete appele au moins une fois (multisession, puis reset)
  expect_gte(length(plan_calls), 1)

  # Le premier appel doit correspondre a la strategie multisession
  expect_identical(plan_calls[[1]], future::multisession)
})


test_that(
  "grobid_process_files handles errors gracefully when on_error is 'warn'",
  {
    local_mocked_bindings(
      .checkrefr_ensure_server = function(...) NULL,

      grobid_process_file = function(file, ...) {
        if (basename(file) == "error.pdf") {
          stop("simulated error")
        }

        data.frame(
          title = paste0("title_", basename(file)),
          source_file = basename(file),
          stringsAsFactors = FALSE
        )
      }
    )

    expect_condition(
      res <- grobid_process_files(
        c("file1.pdf", "error.pdf", "file2.pdf"),
        parallel = FALSE,
        on_error = "warn",
        progress = FALSE
      ),
      regexp = "Error on error\\.pdf: simulated error",
      class = "rlang_warning"
    )

    expect_s3_class(res, "data.frame")

    expect_equal(
      res$title,
      c("title_file1.pdf", "title_file2.pdf")
    )
  }
)

test_that("grobid_process_files interrupts execution when on_error is 'stop'", {
  local_mocked_bindings(
    .checkrefr_ensure_server = function(...) NULL,
    grobid_process_file = function(file, ...) {
      if (basename(file) == "error.pdf") {
        stop("Processing failed")
      }
      data.frame(
        title = paste0("title_", basename(file)),
        source_file = basename(file),
        stringsAsFactors = FALSE
      )
    }
  )

  expect_error({
    grobid_process_files(
      c("file1.pdf", "error.pdf", "file2.pdf"),
      parallel = FALSE,
      on_error = "stop",
      progress = FALSE
    )
  })
})


# ==== TESTS D'INTEGRATION (Docker/reseau reels) ====

test_that("grobid_process_files works sequentially with real PDF files in integration environment", {
  skip_if_not(
    identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"),
    "Tests d'integration desactives"
  )

  pdf_files <- list.files(
    system.file("extdata", package = "CheckrefR"),
    pattern = "\\.pdf$",
    full.names = TRUE
  )
  skip_if(length(pdf_files) == 0, "No test PDF file found in extdata")

  test_files <- pdf_files[seq_len(min(2L, length(pdf_files)))]

  res <- grobid_process_files(
    files = test_files,
    service = "processReferences",
    output_format = "parsed",
    parallel = FALSE,
    progress = FALSE
  )

  expect_s3_class(res, "data.frame")
  expect_true(nrow(res) >= 1)
  expect_true("source_file" %in% names(res))
  expect_true("title" %in% names(res))
  expect_true("authors" %in% names(res))
})

test_that("grobid_process_files works in parallel with real PDF files in integration environment", {
  skip_if_not(
    identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"),
    "Tests d'integration desactives"
  )

  pdf_files <- list.files(
    system.file("extdata", package = "CheckrefR"),
    pattern = "\\.pdf$",
    full.names = TRUE
  )
  skip_if(length(pdf_files) == 0, "No test PDF file found in extdata")

  test_files <- pdf_files[seq_len(min(2L, length(pdf_files)))]

  res <- grobid_process_files(
    files = test_files,
    service = "processReferences",
    output_format = "parsed",
    parallel = TRUE,
    n_workers = 2L,
    progress = FALSE
  )

  expect_s3_class(res, "data.frame")
  expect_true(nrow(res) >= 1)
  expect_true("source_file" %in% names(res))
  expect_true("title" %in% names(res))
})

test_that("grobid_process_files saves XML/TEI results to disk in integration environment", {
  skip_if_not(
    identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"),
    "Tests d'integration desactives"
  )

  pdf_files <- list.files(
    system.file("extdata", package = "CheckrefR"),
    pattern = "\\.pdf$",
    full.names = TRUE
  )
  skip_if(length(pdf_files) == 0, "No test PDF file found in extdata")

  test_files <- pdf_files[seq_len(min(2L, length(pdf_files)))]

  tmp_dir <- tempfile("grobid_out_")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  res <- grobid_process_files(
    files = test_files,
    service = "processReferences",
    output_dir = tmp_dir,
    parallel = FALSE,
    progress = FALSE
  )

  skip_if_not(requireNamespace("CheckrefR", quietly = TRUE))

  # base_name <- sub("\\.pdf$", "", basename(test_files))
  # res_paths <- paste(tmp_dir,paste(base_name,".tei.xml",sep = ""), sep = "\\")
  #
  # # expect_type(res_paths, "character")
  # # expect_equal(length(res_paths), length(test_files))
  #
  # for (path in res_paths) {
  #   expect_true(file.exists(path))
  # }

  base_name <- tools::file_path_sans_ext(basename(test_files))
  res_paths <- file.path(tmp_dir, paste0(base_name, ".tei.xml"))

  expect_length(res_paths, length(test_files))
  for (path in res_paths) {
    expect_true(file.exists(path))
  }

})


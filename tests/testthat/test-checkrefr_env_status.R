# test-checkrefr_env_status.R
# Test script for checkrefr_env_status
# Convention: skip_if_not(identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true")) used for integration tests.

# ==== TESTS UNITAIRES (mockes) ====

test_that("checkrefr_env_status displays all variables when var is NULL", {
  .checkrefr_init_env()

  captured_lines <- character()

  withCallingHandlers(
    {
      result <- checkrefr_env_status()
    },
    cliMessage = function(msg) {
      captured_lines <<- c(captured_lines, msg$message)
      invokeRestart("muffleMessage")
    }
  )

  clean_output <- cli::ansi_strip(paste(captured_lines, collapse = "\n"))

  expect_type(result, "list")
  expect_true(length(result) >= 1)
  expect_named(result)

  default_names <- names(.checkrefr_defaults)
  expect_true(all(default_names %in% names(result)))

  expect_match(clean_output, "Checkrefr environment status", fixed = TRUE)

  for (name in default_names) {
    expect_match(clean_output, name, fixed = TRUE)
  }
})

test_that("checkrefr_env_status displays only target variables when var is specified", {
  # Re-initialize
  .checkrefr_init_env()

  target_vars <- c("mode", "timeout")

  captured_lines <- character()
  withCallingHandlers(
    {
      result <- checkrefr_env_status(var = target_vars)
    },
    cliMessage = function(msg) {
      captured_lines <<- c(captured_lines, msg$message)
      invokeRestart("muffleMessage")
    }
  )
  clean_output <- cli::ansi_strip(paste(captured_lines, collapse = "\n"))

  # Verify invisible return list contains only these two elements
  expect_type(result, "list")
  expect_equal(names(result), target_vars)
  expect_equal(length(result), 2L)

  # Verify console output
  expect_match(clean_output, "Checkrefr environment status", fixed = TRUE)
  expect_match(clean_output, "mode", fixed = TRUE)
  expect_match(clean_output, "timeout", fixed = TRUE)

  # Verify other variables are NOT printed
  expect_false(grepl("docker_port", clean_output))
  expect_false(grepl("grobid_version", clean_output))
})

test_that("checkrefr_env_status raises an error when var is not character or NULL", {
  # Test with non-character argument (e.g. list or numeric)
  expect_error(
    checkrefr_env_status(var = list("mode")),
    "var.*must be a vector of type.*character.*or.*NULL"
  )
  expect_error(
    checkrefr_env_status(var = 123),
    "var.*must be a vector of type.*character.*or.*NULL"
  )
})

test_that("checkrefr_env_status formats special types correctly via .checkrefr_print_named_value", {
  # Backup environment to avoid side effects
  backup_env <- as.list(.checkrefr_env)
  on.exit({
    # Restore environment on completion or error
    for (nm in names(backup_env)) {
      assign(nm, backup_env[[nm]], envir = .checkrefr_env)
    }
  }, add = TRUE)

  capture_cli_output <- function(expr) {
    captured_lines <- character()
    withCallingHandlers(
      expr,
      cliMessage = function(msg) {
        captured_lines <<- c(captured_lines, msg$message)
        invokeRestart("muffleMessage")
      }
    )
    cli::ansi_strip(paste(captured_lines, collapse = "\n"))
  }

  # 1. Test logical TRUE (checkmark \u2713)
  .checkrefr_env$mode <- TRUE
  clean_true <- capture_cli_output({
    checkrefr_env_status(var = "mode")
  })
  expect_match(clean_true, "mode: \u2713", fixed = TRUE)

  # 2. Test logical FALSE (cross \u2717)
  .checkrefr_env$mode <- FALSE
  clean_false <- capture_cli_output({
    checkrefr_env_status(var = "mode")
  })
  expect_match(clean_false, "mode: \u2717", fixed = TRUE)

  # 3. Test NA
  .checkrefr_env$mode <- NA_character_
  clean_na <- capture_cli_output({
    checkrefr_env_status(var = "mode")
  })
  expect_match(clean_na, "mode: NA", fixed = TRUE)

  # 4. Test empty vector
  .checkrefr_env$mode <- character(0)
  clean_empty <- capture_cli_output({
    checkrefr_env_status(var = "mode")
  })
  expect_match(clean_empty, "mode: \\(empty\\)")

  # 5. Test NULL
  assign("mode", NULL, envir = .checkrefr_env)
  clean_null <- capture_cli_output({
    checkrefr_env_status(var = "mode")
  })
  expect_match(clean_null, "mode: \"NULL\"", fixed = TRUE)
})

# NOTE: cas ajoute, absent de la fiche d'analyse - Permet de valider l'utilisation de local_mocked_bindings() sur une fonction interne
test_that("checkrefr_env_status calls .checkrefr_print_named_value using local_mocked_bindings", {
  # We mock .checkrefr_print_named_value using local_mocked_bindings()
  called_with <- list()
  local_mocked_bindings(
    .checkrefr_print_named_value = function(label, val, indent = 0L) {
      called_with[[length(called_with) + 1]] <<- list(label = label, val = val)
    }
  )

  # Call the function for a single variable
  checkrefr_env_status(var = "docker_port")

  # Verify that our mocked function was called with the right arguments
  expect_equal(length(called_with), 1L)
  expect_equal(called_with[[1]]$label, "docker_port")
})

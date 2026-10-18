# Fonction : grobid_install_guide
# Ce test vérifie le comportement de la fonction grobid_install_guide() qui
# génère un guide d'installation adapté au système de l'utilisateur.
#
# Conformément à la convention du package :
# - Les tests unitaires mockent toutes les dépendances externes (Docker, requêtes HTTP, etc.)
#   en utilisant prioritairement testthat::local_mocked_bindings().
# - Les tests d'intégration réels ne s'exécutent que si RUN_INTEGRATION_TESTS="true"
#   et utilisent de réels appels.

library(testthat)

# ==== TESTS UNITAIRES (mockés) ====

test_that("grobid_install_guide raises an error if requirements is not of class checkrefr_requirements", {
  # L'argument requirements doit être de classe checkrefr_requirements (si non NULL)
  expect_error(
    grobid_install_guide(requirements = list(invalid_field = TRUE)),
    class = "error"
  )
})

test_that("grobid_install_guide displays a correct guide for Windows OS when Docker is not installed", {
  req_windows <- list(
    os                       = "windows",
    os_version               = "Windows 11 (build 22000)",
    r_version                = "4.3.0",
    internet_available       = TRUE,
    docker_installed         = FALSE,
    docker_running           = FALSE,
    docker_version           = NA_character_,
    grobid_container_active  = FALSE,
    grobid_container_id      = NA_character_,
    remote_default_reachable = TRUE,
    remote_reachable_urls    = list(crf = "https://grobidorg-grobid.hf.space"),
    recommended_url          = "https://grobidorg-grobid.hf.space",
    recommended_remote_mode  = "crf",
    current_mode             = "not configured",
    current_url              = "not configured",
    recommended_mode         = "remote"
  )
  class(req_windows) <- c("checkrefr_requirements", "list")

  out <- paste(
    testthat::capture_messages(grobid_install_guide(req_windows)),
    collapse = ""
  )

  # Validation des sections clés attendues dans la console
  expect_match(out, "GROBID installation guide", ignore.case = TRUE)
  expect_match(out, "OS\\s+:\\s+windows", ignore.case = TRUE)
  expect_match(out, "Docker Desktop for Windows", ignore.case = TRUE)
  expect_match(out, "https://docs.docker.com/desktop/install/windows-install/", fixed = TRUE)
})

test_that("grobid_install_guide displays a correct guide for macOS when Docker is not installed", {
  req_macos <- list(
    os                       = "macos",
    os_version               = "Darwin 21.4.0",
    r_version                = "4.3.0",
    internet_available       = TRUE,
    docker_installed         = FALSE,
    docker_running           = FALSE,
    docker_version           = NA_character_,
    grobid_container_active  = FALSE,
    grobid_container_id      = NA_character_,
    remote_default_reachable = TRUE,
    remote_reachable_urls    = list(crf = "https://grobidorg-grobid.hf.space"),
    recommended_url          = "https://grobidorg-grobid.hf.space",
    recommended_remote_mode  = "crf",
    current_mode             = "not configured",
    current_url              = "not configured",
    recommended_mode         = "remote"
  )
  class(req_macos) <- c("checkrefr_requirements", "list")

  out <- paste(
    testthat::capture_messages(grobid_install_guide(req_macos)),
    collapse = ""
  )

  expect_match(out, "GROBID installation guide", ignore.case = TRUE)
  expect_match(out, "OS\\s+:\\s+macos", ignore.case = TRUE)
  expect_match(out, "Option A - Docker Desktop", ignore.case = TRUE)
  expect_match(out, "Option B - Homebrew", ignore.case = TRUE)
  expect_match(out, "brew install --cask docker", fixed = TRUE)
})

test_that("grobid_install_guide displays a correct guide for other unknown OS when Docker is not installed", {

   req_other <- list(
    os                       = "solaris",
    os_version               = "SunOS 5.11",
    r_version                = "4.3.0",
    internet_available       = TRUE,
    docker_installed         = FALSE,
    docker_running           = FALSE,
    docker_version           = NA_character_,
    grobid_container_active  = FALSE,
    grobid_container_id      = NA_character_,
    remote_default_reachable = FALSE,
    remote_reachable_urls    = list(),
    recommended_url          = NA_character_,
    recommended_remote_mode  = NA_character_,
    current_mode             = "not configured",
    current_url              = "not configured",
    recommended_mode         = "none"
  )
  class(req_other) <- c("checkrefr_requirements", "list")

  out <- paste(
    testthat::capture_messages(grobid_install_guide(req_other)),
    collapse = ""
  )

  expect_match(out, "GROBID installation guide", ignore.case = TRUE)
  expect_match(out, "OS\\s+:\\s+solaris", ignore.case = TRUE)
  expect_match(out, "Check the official documentation", ignore.case = TRUE)
  expect_match(out, "https://docs.docker.com/engine/install/", fixed = TRUE)
})

test_that("grobid_install_guide formats Docker install guide for Debian/Ubuntu linux distro", {
  req_linux <- list(
    os                       = "linux",
    os_version               = "Ubuntu 22.04 LTS",
    r_version                = "4.3.0",
    internet_available       = TRUE,
    docker_installed         = FALSE,
    docker_running           = FALSE,
    docker_version           = NA_character_,
    grobid_container_active  = FALSE,
    grobid_container_id      = NA_character_,
    remote_default_reachable = FALSE,
    remote_reachable_urls    = list(),
    recommended_url          = NA_character_,
    recommended_remote_mode  = NA_character_,
    current_mode             = "not configured",
    current_url              = "not configured",
    recommended_mode         = "none"
  )
  class(req_linux) <- c("checkrefr_requirements", "list")

  # Mocking readLines to simulate Debian/Ubuntu /etc/os-release contents
  local_mocked_bindings(
    readLines = function(...) c("ID=ubuntu", "NAME=\"Ubuntu\"", "ID_LIKE=debian"),
    .package = "base"
  )

  out <- paste(
    testthat::capture_messages(grobid_install_guide(req_linux)),
    collapse = ""
  )

  expect_match(out, "Detected distribution:\\s+ubuntu\\s+\\(Debian/Ubuntu family\\)", ignore.case = TRUE)
  expect_match(out, "sudo apt-get install -y docker.io", fixed = TRUE)
  expect_match(out, "sudo systemctl enable --now docker", fixed = TRUE)
})

test_that("grobid_install_guide formats Docker install guide for RHEL/Fedora linux distro", {
  req_linux <- list(
    os                       = "linux",
    os_version               = "Red Hat Enterprise Linux 9",
    r_version                = "4.3.0",
    internet_available       = TRUE,
    docker_installed         = FALSE,
    docker_running           = FALSE,
    docker_version           = NA_character_,
    grobid_container_active  = FALSE,
    grobid_container_id      = NA_character_,
    remote_default_reachable = FALSE,
    remote_reachable_urls    = list(),
    recommended_url          = NA_character_,
    recommended_remote_mode  = NA_character_,
    current_mode             = "not configured",
    current_url              = "not configured",
    recommended_mode         = "none"
  )
  class(req_linux) <- c("checkrefr_requirements", "list")

  # Mocking readLines to simulate RHEL /etc/os-release contents
  local_mocked_bindings(
    readLines = function(...) c("ID=rhel", "NAME=\"Red Hat Enterprise Linux\"", "ID_LIKE=fedora"),
    .package = "base"
  )

  out <- paste(
    testthat::capture_messages(grobid_install_guide(req_linux)),
    collapse = ""
  )

  expect_match(out, "Detected distribution:\\s+rhel\\s+\\(RHEL/Fedora family\\)", ignore.case = TRUE)
  expect_match(out, "sudo dnf install -y docker", fixed = TRUE)
  expect_match(out, "sudo systemctl enable --now docker", fixed = TRUE)
})

test_that("grobid_install_guide handles unknown or failing readLines for Linux distro gracefully", {
  req_linux <- list(
    os                       = "linux",
    os_version               = "Custom Linux",
    r_version                = "4.3.0",
    internet_available       = TRUE,
    docker_installed         = FALSE,
    docker_running           = FALSE,
    docker_version           = NA_character_,
    grobid_container_active  = FALSE,
    grobid_container_id      = NA_character_,
    remote_default_reachable = FALSE,
    remote_reachable_urls    = list(),
    recommended_url          = NA_character_,
    recommended_remote_mode  = NA_character_,
    current_mode             = "not configured",
    current_url              = "not configured",
    recommended_mode         = "none"
  )
  class(req_linux) <- c("checkrefr_requirements", "list")

  # Mocking readLines to raise an error, simulating file missing or permissions error
  local_mocked_bindings(
    readLines = function(...) stop("Failed to read file"),
    .package = "base"
  )

  out <- paste(
    testthat::capture_messages(grobid_install_guide(req_linux)),
    collapse = ""
  )

  expect_match(out, "Unrecognized distribution \\(unknown\\)", ignore.case = TRUE)
  expect_match(out, "https://docs.docker.com/engine/install/", fixed = TRUE)
})

test_that("grobid_install_guide triggers grobid_check_requirements when requirements is NULL", {
  req_mocked <- list(
    os                       = "macos",
    os_version               = "Darwin 22.1.0",
    r_version                = "4.3.1",
    internet_available       = TRUE,
    docker_installed         = TRUE,
    docker_running           = TRUE,
    docker_version           = "24.0.5",
    grobid_container_active  = TRUE,
    grobid_container_id      = "mocked_id_12345",
    remote_default_reachable = FALSE,
    remote_reachable_urls    = list(),
    recommended_url          = NA_character_,
    recommended_remote_mode  = NA_character_,
    current_mode             = "docker",
    current_url              = "http://localhost:8070",
    recommended_mode         = "docker"
  )
  class(req_mocked) <- c("checkrefr_requirements", "list")

  # Mocking grobid_check_requirements to avoid real system and network scans
  local_mocked_bindings(
    grobid_check_requirements = function(verbose, test_all_urls) {
      expect_false(verbose)
      expect_true(test_all_urls)
      return(req_mocked)
    }
  )

  out <- paste(
    testthat::capture_messages(grobid_install_guide(requirements = NULL, test_all_urls = TRUE)),
    collapse = ""
  )

  # Verification that the mocked environment values are correctly rendered
  expect_match(out, "OS\\s+:\\s+macos", ignore.case = TRUE)
  expect_match(out, "Darwin 22.1.0", fixed = TRUE)
})

test_that("grobid_install_guide stops and displays danger message when no Internet and no Docker are available", {
  req_offline <- list(
    os                       = "windows",
    os_version               = "Windows 11",
    r_version                = "4.3.0",
    internet_available       = FALSE,
    docker_installed         = FALSE,
    docker_running           = FALSE,
    docker_version           = NA_character_,
    grobid_container_active  = FALSE,
    grobid_container_id      = NA_character_,
    remote_default_reachable = FALSE,
    remote_reachable_urls    = list(),
    recommended_url          = NA_character_,
    recommended_remote_mode  = NA_character_,
    current_mode             = "not configured",
    current_url              = "not configured",
    recommended_mode         = "none"
  )
  class(req_offline) <- c("checkrefr_requirements", "list")

  out <- paste(
    testthat::capture_messages(grobid_install_guide(req_offline)),
    collapse = "" )
  res <- grobid_install_guide(req_offline)

  # Validation of return value (invisible(NULL)) and output warnings
  expect_null(res)
  expect_match(out, "No Internet connection detected, and Docker is not installed.", fixed = TRUE)
  expect_match(out, "Docker cannot be installed or a remote server reached", fixed = TRUE)
})


# ==== TESTS D'INTEGRATION (Docker/réseau réels) ====

test_that("grobid_install_guide integrates with real environment on ubuntu-latest", {
  skip_if_not(
    identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"),
    "Tests d'integration desactives"
  )

  # No mock used here, let it run real queries and system checks
  out <- paste(
    testthat::capture_messages(grobid_install_guide(requirements = NULL, test_all_urls = FALSE)),
    collapse = "" )

  res <- grobid_install_guide(requirements = NULL, test_all_urls = FALSE)

  expect_null(res)
  expect_match(out, "GROBID installation guide", ignore.case = TRUE)
  expect_match(out, "1\\. Environment summary", ignore.case = TRUE)
  expect_match(out, "2\\. Recommended option", ignore.case = TRUE)
})

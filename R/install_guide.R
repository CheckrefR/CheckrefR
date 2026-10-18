#' Display an installation guide adapted to the environment


#'
#' Generates and displays a step-by-step guide based on the detected
#' system state. If Docker is not installed, guides towards its
#' installation according to the OS. If there is no Internet connection,
#' indicates alternative options.
#'
#' @param requirements `list` or `NULL` - Result of
#'   `grobid_check_requirements()`. If `NULL`, the diagnostic is relaunched
#'   automatically. If provided, must contain all the expected fields
#'   (see `grobid_check_requirements()`).
#' @param test_all_urls `logical(1)` Used only if `requirements`
#'   is `NULL` (the diagnostic is then relaunched with this value).
#'   If `TRUE`, all configured remote servers are tested; if
#'   `FALSE`, the test stops at the first reachable server found.
#'   Default: `TRUE`.
#'
#' @return `invisible(NULL)`
#' @importFrom cli cli_h1 cli_h2 cli_ul cli_alert_info cli_alert_success cli_alert_warning cli_alert_danger
#' @export
grobid_install_guide <- function(requirements = NULL, test_all_urls = TRUE) {

  if (!is.null(requirements)) {
    .checkrefr_validate_requirements(requirements)
  } else {
    requirements <- grobid_check_requirements(
      verbose = FALSE,
      test_all_urls = test_all_urls
    )
  }

  req <- requirements


  # 1. Environment summary

  cli::cli_h1("GROBID installation guide")
  cli::cli_h2("1. Environment summary")

  cli::cli_ul(c(
    "OS       : {req$os} ({req$os_version})",
    "Internet : {(.checkrefr_status_icon(req$internet_available))}",
    "Docker installed : {(.checkrefr_status_icon(req$docker_installed))}",
    "Docker running  : {(.checkrefr_status_icon(req$docker_running))}",
    "Remote server(s) reachable : {(.checkrefr_status_icon(req$remote_default_reachable))}"
  ))

  if (req$remote_default_reachable) {
    cli::cli_alert_info(
      "Remote server found (fallback only): {.url {req$recommended_url}} (mode: {req$recommended_remote_mode})"
    )
  }

  # -- Detail by mode if remote URLs were tested
  if (length(req$remote_reachable_urls) > 0L) {
    for (mode_name in names(req$remote_reachable_urls)) {
      reachable <- req$remote_reachable_urls[[mode_name]]
      if (length(reachable) > 0L) {
        cli::cli_alert_success(
          "Mode {.val {mode_name}}: {length(reachable)} reachable server(s)."
        )
      }
    }
  }

  # -- Warning if the test was not exhaustive
  if (isFALSE(test_all_urls) && is.null(requirements) == FALSE) {
    if (req$remote_default_reachable) {
      cli::cli_alert_info(
        "The test stopped at the first reachable remote server. ",
        "Other servers may be available (rerun with {.code test_all_urls = TRUE} to discover them)."
      )
    }
  }


  # 2. Recommended option
  # Docker-first policy: as soon as Docker is installed, local mode is the
  # recommended path, regardless of remote server availability. Remote is
  # only ever presented as a temporary fallback, never as an equivalent
  # alternative.

  cli::cli_h2("2. Recommended option")

  if (req$docker_running) {

    cli::cli_alert_success(
      "Docker is installed and running: {.strong local mode is ready to use}."
    )
    cli::cli_alert_info(
      "Run {.run grobid_docker_start()} to start (or reuse) the GROBID container."
    )
    .checkrefr_guide_validation()
    return(invisible(NULL))

  } else if (req$docker_installed) {

    cli::cli_alert_success(
      "Docker is installed on this system: {.strong local mode is strongly recommended}."
    )
    cli::cli_alert_info(
      "Docker is not currently running, but it can be started automatically. \\
      Run {.run grobid_docker_start()} - the package will attempt to start the \\
      Docker daemon and the GROBID container for you."
    )

    if (req$remote_default_reachable) {
      cli::cli_alert_warning(
        "A remote server is reachable (mode: {req$recommended_remote_mode}), but it \\
        should only be used as a temporary fallback (e.g. {.fn grobid_remote_connect}). \\
        Relying on Docker locally avoids depending on third-party service availability, \\
        rate limits, or downtime."
      )
    }

    # Docker is installed but not running -> guide the user to start it
    cli::cli_h2("3. Starting Docker")
    switch(req$os,
           "windows" = cli::cli_ul(c(
             "Open the {.strong Docker Desktop} application from the Start menu.",
             "Wait until the Docker icon in the taskbar is active.",
             "Restart R and run {.run grobid_install_guide()}, or directly {.run grobid_docker_start()}."
           )),
           "macos" = cli::cli_ul(c(
             "Open {.strong Docker Desktop} from Launchpad or Applications.",
             "Wait until the Docker icon in the menu bar is active.",
             "Restart R and run {.run grobid_install_guide()}, or directly {.run grobid_docker_start()}."
           )),
           "linux" = cli::cli_ul(c(
             "Start the Docker service with the command:",
             "  {.code sudo systemctl start docker}",
             "Restart R and run {.run grobid_install_guide()}, or directly {.run grobid_docker_start()}."
           )),
           cli::cli_alert_info("Start the Docker service manually then rerun the guide.")
    )

    .checkrefr_guide_validation()
    return(invisible(NULL))
  }

  # -- From here: Docker is NOT installed at all

  if (!req$internet_available) {
    cli::cli_alert_danger("No Internet connection detected, and Docker is not installed.")
    cli::cli_ul(c(
      "Docker cannot be installed or a remote server reached without Internet access.",
      "If you are on an isolated network, contact your system administrator to either \\
      restore Internet access (to install Docker) or configure a local/offline solution."
    ))
    return(invisible(NULL))
  }

  if (req$remote_default_reachable) {
    cli::cli_alert_warning(
      "Docker is not installed on this system. A remote server is reachable \\
      (mode: {req$recommended_remote_mode}) and can be used {.strong as a temporary fallback}."
    )
    cli::cli_alert_info(
      "Connect with: {.run grobid_remote_connect()}"
    )
    cli::cli_alert_info(
      "You can also directly call {.run grobid_process_file()} or {.run grobid_process_files()} \\
      with {.code mode = \"remote\"}, without a prior connection."
    )
    cli::cli_alert_danger(
      "However, {.strong installing Docker is strongly recommended} for a stable, reliable, \\
      and self-contained setup, independent of external service availability, rate limits, \\
      or downtime. See the installation instructions below."
    )
  } else {
    cli::cli_alert_danger(
      "No mode available for now: Docker is not installed and no remote server is reachable."
    )
    cli::cli_alert_info(
      "Installing Docker (see section 3) is the recommended and most reliable path forward."
    )
  }


  # 3. Step-by-step Docker installation instructions

  cli::cli_h2("3. Docker installation")
  cli::cli_alert_info("Docker is not installed. Follow the instructions below.")
  .checkrefr_guide_docker_install(req$os)


  # 4. Validation test

  .checkrefr_guide_validation()

  invisible(NULL)
}


# Internal display helpers


.checkrefr_guide_docker_install <- function(os) {
  switch(os,
         "windows" = {
           cli::cli_ul(c(
             "Download Docker Desktop for Windows:",
             "  {.url https://docs.docker.com/desktop/install/windows-install/}",
             "Run the installer and follow the instructions.",
             "Restart your Windows session if prompted.",
             "Open Docker Desktop and wait until it is ready.",
             "Restart R and run {.run grobid_install_guide()}."
           ))
         },
         "macos" = {
           cli::cli_ul(c(
             "Option A - Docker Desktop (recommended):",
             "  {.url https://docs.docker.com/desktop/install/mac-install/}",
             "Option B - Homebrew:",
             "  {.code brew install --cask docker}",
             "Open Docker Desktop after installation.",
             "Restart R and run {.run grobid_install_guide()}."
           ))
         },
         "linux" = {
           .checkrefr_guide_docker_linux()
         },
         {
           cli::cli_alert_info(
             "Check the official documentation: {.url https://docs.docker.com/engine/install/}"
           )
         }
  )
}

.checkrefr_guide_docker_linux <- function() {
  # Distribution detection
  distro <- tryCatch(
    {
      lines <- readLines("/etc/os-release", warn = FALSE)
      id_line <- grep("^ID=", lines, value = TRUE)
      if (length(id_line) > 0L) {
        to_lower_unicode(trimws(sub("^ID=", "", id_line[[1L]])))
      } else {
        "unknown"
      }
    },
    error = function(e) "unknown"
  )

  debian_based <- c("ubuntu", "debian", "mint", "pop", "elementary")
  rhel_based   <- c("fedora", "rhel", "centos", "rocky", "almalinux")

  if (distro %in% debian_based) {
    cli::cli_ul(c(
      "Detected distribution: {.strong {distro}} (Debian/Ubuntu family)",
      "Run in a terminal:",
      "  {.code sudo apt-get update}",
      "  {.code sudo apt-get install -y docker.io}",
      "  {.code sudo systemctl enable --now docker}",
      "  {.code sudo usermod -aG docker $USER}",
      "Log out then log back in to apply the permissions.",
      "Restart R and run {.run grobid_install_guide()}."
    ))
  } else if (distro %in% rhel_based) {
    cli::cli_ul(c(
      "Detected distribution: {.strong {distro}} (RHEL/Fedora family)",
      "Run in a terminal:",
      "  {.code sudo dnf install -y docker}",
      "  {.code sudo systemctl enable --now docker}",
      "  {.code sudo usermod -aG docker $USER}",
      "Log out then log back in to apply the permissions.",
      "Restart R and run {.run grobid_install_guide()}."
    ))
  } else {
    cli::cli_alert_info(
      "Unrecognized distribution ({distro}). See:"
    )
    cli::cli_ul(c(
      "{.url https://docs.docker.com/engine/install/}"
    ))
  }
}

.checkrefr_guide_validation <- function() {
  cli::cli_h2("4. Validation test")
  cli::cli_alert_info(
    "Once Docker is running, check your environment with:"
  )
  cli::cli_ul(c(
    "{.run grobid_check_requirements()}"
  ))
}


.checkrefr_validate_requirements <- function(requirements) {

  is_valid_class <- inherits(requirements, "checkrefr_requirements")

  if (!isTRUE(is_valid_class)) {
    cli::cli_abort(c(
      "Incorrect {.arg requirements}.",
      "i" = "Provide the result of {.fn grobid_check_requirements} as the {.arg requirements} argument, or leave {.code requirements = NULL} to relaunch the diagnostic."
    ))
  }

  invisible(requirements)
}

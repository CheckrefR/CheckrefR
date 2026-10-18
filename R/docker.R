# 01_docker.R
# GROBID Docker container management






# Checking Docker availability

#' Check whether Docker is available on the system
#'
#' Checks that Docker is installed and that the daemon is currently
#' running. This function is intended to be used directly
#' by the user to diagnose their Docker environment.
#'
#' @param verbose `logical(1)` Display a confirmation message.
#'   Default: `TRUE`.
#'
#' @return `invisible(TRUE)` if Docker is installed and operational.
#'   Raises an error otherwise.
#'
#' @examples
#' \dontrun{
#' grobid_docker_check()
#' }
#'
#' @importFrom cli cli_abort cli_alert_success
#' @export
grobid_docker_check <- function(verbose = TRUE) {

  if (!.checkrefr_docker_installed()) {
    cli::cli_abort(c(
      "Docker could not be found on this system.",
      "i" = "See {.url https://docs.docker.com/get-docker/} for installation instructions."
    ))
  }

  if (!.checkrefr_docker_running()) {
    cli::cli_abort(c(
      "Docker is installed but not responding.",
      "i" = "Check that the Docker daemon is running."
    ))
  }

  if (verbose) cli::cli_alert_success("Docker is available.")
  invisible(TRUE)
}


# Checking local port availability


.checkrefr_port_is_free <- function(port) {
  con <- tryCatch(
    suppressWarnings(
      socketConnection(
        host    = "localhost",
        port    = port,
        open    = "rb",
        timeout = 1L
      )
    ),
    error = function(e) NULL
  )


  if (is.null(con)) {
    return(TRUE)
  }

  close(con)
  FALSE
}


# Capturing container logs for diagnostics


.checkrefr_capture_logs <- function(container_id) {
  tryCatch(
    system2(
      "docker",
      args   = c("logs", "--tail", "50", container_id),
      stdout = TRUE,
      stderr = TRUE
    ),
    error = function(e) character(0L)
  )
}


#' Start the GROBID container via Docker
#'
#' @description
#' Launches a GROBID container in the background after checking that Docker
#' is installed and operational. If the Docker daemon is not started,
#' an automatic startup attempt is performed. The function then waits
#' for the service to be ready via an HTTP health check.
#'
#' @param docker_image `character(1)` Base of the Docker image to use.
#'   Default: value of `.checkrefr_env$docker_image`. Default: "lfoppiano/grobid:"
#' @param grobid_version `character(1)` GROBID version.
#'   Default: value of `.checkrefr_env$grobid_version`. Default: "0.9.0".
#' @param port `integer(1)` Local port to expose. Default: `8070`.
#' @param max_ram `character(1)` Memory limit for the container. Default: `"4g"`.
#' @param pull `logical(1)` Force downloading of the image. Default: `FALSE`.
#' @param timeout_ready `integer(1)` Max seconds to wait for GROBID. Default: `120`.
#' @param verbose `logical(1)` Display progress messages. Default: `TRUE`.
#' @param model_type `character(1)` or `NULL`. GROBID model variant:
#'   \itemize{
#'     \item `NULL` or `""` (default) -- no variant specified, the image
#'       is used without a suffix (`{version}`), historical behavior.
#'     \item `"full"` -- image including the Deep Learning and CRF models.
#'       Docker tag convention: `{version}-full`.
#'     \item `"crf"` -- CRF-only image. Docker tag convention:
#'       `{version}-crf`.
#'   }
#'   See \url{https://grobid.readthedocs.io/en/latest/Grobid-docker/}.
#'   Default: `.checkrefr_env$grobid_model_type`.
#'
#' @return `invisible(TRUE)` if the container started and GROBID is responding.
#'
#' @details
#' The function performs the following steps in order:
#' \enumerate{
#'   \item Checking that Docker is installed on the system.
#'   \item Checking that the Docker daemon is running.
#'         If not, an automatic startup attempt
#'         is performed via `.start_docker()`.
#'   \item Checking that the requested port is free.
#'   \item Optional download of the Docker image (`pull = TRUE`).
#'   \item Launching the container in the background.
#'   \item Waiting for the GROBID service to respond (HTTP health check).
#'   \item Updating the package's internal environment variables.
#' }
#'
#' @examples
#' \dontrun{
#' grobid_docker_start()
#' grobid_docker_start(grobid_version = "0.8.1", port = 8080)
#' grobid_docker_start(pull = TRUE, max_ram = "8g")
#' }
#'
#' @seealso [grobid_docker_check()] for a simple Docker diagnostic,
#'   [grobid_remote_connect()] to connect to a remote server.
#'
#' @importFrom cli cli_abort cli_alert_info cli_alert_success cli_progress_bar cli_progress_done cli_progress_step cli_progress_update
#' @importFrom httr2 req_error req_perform req_timeout request resp_status
#' @importFrom processx process
#' @export
grobid_docker_start <- function(
    docker_image   = .checkrefr_env$docker_image,
    grobid_version = .checkrefr_env$grobid_version,
    model_type     = .checkrefr_env$grobid_model_type,
    port           = .checkrefr_env$docker_port,
    max_ram        = "4g",
    pull           = FALSE,
    timeout_ready  = .checkrefr_env$timeout,
    verbose        = TRUE
) {

  # -- 0. Input validation -------------------------------------------- #
  # User-provided arguments must always be validated before anything else,
  # since they take priority over the internal environment state.

  if (!is.character(docker_image) || length(docker_image) != 1L ||
      is.na(docker_image) || !nzchar(trimws(docker_image))) {
    cli::cli_abort(c(
      "{.arg docker_image} must be a single non-empty character string.",
      "x" = "Value provided: {.val {docker_image}}"
    ))
  }
  # A Docker image reference must look like "namespace/repo" or "namespace/repo:tag"
  # (letters, digits, dots, dashes, underscores, slashes, colon for the tag).
  if (!grepl("^[a-z0-9]+([._-][a-z0-9]+)*(/[a-z0-9]+([._-][a-z0-9]+)*)*:?$",
             docker_image, ignore.case = TRUE)) {
    cli::cli_abort(c(
      "{.arg docker_image} does not look like a valid Docker image reference.",
      "x" = "Value provided: {.val {docker_image}}",
      "i" = "Expected format: {.val namespace/repository:} (trailing colon expected \\
      before the version is appended)."
    ))
  }

  if (!is.character(grobid_version) || length(grobid_version) != 1L ||
      is.na(grobid_version) || !nzchar(trimws(grobid_version))) {
    cli::cli_abort(c(
      "{.arg grobid_version} must be a single non-empty character string.",
      "x" = "Value provided: {.val {grobid_version}}",
      "i" = "Use {.fn grobid_docker_list_versions} to see the available GROBID versions."
    ))
  }

  if (!is.character(max_ram) || length(max_ram) != 1L ||
      is.na(max_ram) || !grepl("^[0-9]+[gGmM]$", trimws(max_ram))) {
    cli::cli_abort(c(
      "{.arg max_ram} must be a single string of the form {.val \"<number><g|m>\"} (e.g. {.val \"4g\"}).",
      "x" = "Value provided: {.val {max_ram}}"
    ))
  }

  port_int <- suppressWarnings(as.integer(port))
  if (is.na(port_int) || length(port_int) != 1L || port_int <= 0L || port_int > 65535L) {
    cli::cli_abort(c(
      "{.arg port} must be a single valid TCP port number (1-65535).",
      "x" = "Value provided: {.val {port}}"
    ))
  }
  port <- port_int

  if (!is.logical(pull) || length(pull) != 1L || is.na(pull)) {
    cli::cli_abort("{.arg pull} must be a single logical value (TRUE or FALSE).")
  }

  timeout_ready <- suppressWarnings(as.numeric(timeout_ready))
  if (is.na(timeout_ready) || length(timeout_ready) != 1L || timeout_ready <= 0) {
    cli::cli_abort(c(
      "{.arg timeout_ready} must be a single positive number (in seconds).",
      "x" = "Value provided: {.val {timeout_ready}}"
    ))
  }

  # -- Normalizing model_type
  model_type <- .checkrefr_normalize_model_type(model_type)

  # -- Building the full image name
  # If model_type is NA -> no suffix (historical behavior)
  image <- if (is.na(model_type) || model_type == "") {
    paste0(docker_image, grobid_version)
  } else {
    paste0(docker_image, grobid_version, "-", model_type)
  }

  # -- 1. Docker installed
  if (!.checkrefr_docker_installed()) {
    cli::cli_abort(c(
      "Docker could not be found on this system.",
      "i" = "See {.url https://docs.docker.com/get-docker/} for installation instructions."
    ))
  }

  # -- 2. Docker daemon running
  if (!.checkrefr_docker_running()) {
    if (verbose) {
      cli::cli_alert_info("The Docker daemon is not started. Attempting to start it...")
    }
    .start_docker()
    if (!.checkrefr_docker_running()) {
      cli::cli_abort(c(
        "Unable to start the Docker daemon automatically.",
        "i" = "Start Docker manually then run the command again."
      ))
    }
    if (verbose) cli::cli_alert_success("Docker daemon started.")
  }

  # -- 3. Single-container policy: if a GROBID container is already active,
  # the explicitly requested configuration (image, version, model_type,
  # port, ...) always takes priority over whatever is currently running.
  # We compare the *effective* requested configuration against the active
  # one; if anything differs, the active container is stopped and replaced.
  # If everything matches, we short-circuit and reuse it (no-op).

  if (.checkrefr_container_active()) {

    active_image_matches <- identical(
      paste0(.checkrefr_env$docker_image, .checkrefr_env$grobid_version),
      paste0(docker_image, grobid_version)
    )
    active_model_matches <- identical(.checkrefr_env$grobid_model_type, model_type)
    active_port_matches   <- identical(as.character(.checkrefr_env$docker_port), as.character(port))
    expected_url       <- paste0("http://localhost:", port)
    active_url_matches <- identical(.checkrefr_env$server_url, expected_url)

    if (!active_url_matches && active_port_matches && verbose) {
      cli::cli_alert_warning(
        "Internal inconsistency detected: {.field server_url} \\
        ({.val {.checkrefr_env$server_url}}) does not match the expected \\
        value for the active port ({.val {expected_url}}). Forcing a clean restart."
      )
    }

    requested_matches_active <- active_image_matches &&
      active_model_matches &&
      active_port_matches &&
      active_url_matches

    if (requested_matches_active) {
      if (verbose) {
        label <- if (is.na(model_type)) "(no variant specified)" else model_type
        cli::cli_alert_info(
          "The requested GROBID container {label} is already active on port {port}. Nothing to do."
        )
      }
      return(invisible(TRUE))
    }

    if (verbose) {
      cli::cli_alert_info(
        "A different GROBID container configuration is currently active. \\
        Stopping it to apply the explicitly requested configuration..."
      )
    }
    grobid_docker_stop(verbose = verbose)
  }

  # -- 4. Port free
  # At this point, the single-container policy guarantees that no GROBID
  # container of ours is left running, so a busy port necessarily belongs
  # to a third-party process (or another, externally-managed container).
  if (!.checkrefr_port_is_free(port)) {
    cli::cli_abort(c(
      "Port {port} is already in use by another process.",
      "i" = "Choose a different port via the {.arg port} argument, or free up port {port}."
    ))
  }

  # -- 5. Checking whether the image is present locally
  image_present <- .checkrefr_image_exists(image)

  if (!image_present && !isTRUE(pull)) {
    if (verbose) {
      cli::cli_alert_info(
        "Image {.val {image}} is not present locally. Forcing download."
      )
    }
    pull <- TRUE
  }

  # -- 6. Optional pull with progress bar
  if (isTRUE(pull)) {
    if (verbose) cli::cli_progress_step("Downloading image {image}...")

    px <- processx::process$new(
      "docker",
      args   = c("pull", image),
      stdout = "|",
      stderr = "|"
    )

    if (verbose) {
      cli::cli_progress_bar(name = "Docker pull", type = "iterator", total = NA)
    }

    while (px$is_alive()) {
      all_lines <- c(px$read_output_lines(), px$read_error_lines())
      if (length(all_lines) > 0L && verbose) {
        cli::cli_progress_update(status = tail(all_lines, 1L))
      }
      Sys.sleep(0.2)
    }

    all_lines <- c(px$read_output_lines(), px$read_error_lines())
    if (length(all_lines) > 0L && verbose) {
      cli::cli_progress_update(status = tail(all_lines, 1L))
    }
    px$wait()
    if (verbose) cli::cli_progress_done()

    pull_result <- px$get_exit_status()
    if (pull_result != 0L) {
      cli::cli_abort(c(
        "Failed to download image {.val {image}}.",
        "i" = "Check the image name and your internet connection."
      ))
    }
    if (verbose) cli::cli_alert_success("Image {.val {image}} downloaded successfully.")
  }

  # -- 7. Launching the container
  docker_args <- c(
    "run", "--rm", "-d",
    "--memory", max_ram,
    "-p", paste0(port, ":8070"),
    image
  )

  if (verbose) cli::cli_progress_step("Starting the GROBID container...")

  container_id <- system2("docker", args = docker_args, stdout = TRUE, stderr = TRUE)

  if (!is.character(container_id) || length(container_id) == 0L) {
    cli::cli_abort(c(
      "Failed to launch the Docker container.",
      "i" = "Check the Docker logs for more details."
    ))
  }

  container_id <- trimws(container_id[1])

  # -- 8. Updating the internal environment
  # The explicitly requested configuration always wins here: docker_image,
  # grobid_version and grobid_model_type are set from the user-provided
  # arguments (validated above), not re-derived defensively from the image
  # string, to guarantee the "explicit argument always takes priority" rule
  # even in edge cases where the derived value could differ from the input
  # (e.g. unusual tag naming).
  .checkrefr_env$docker_container_id <- container_id
  .checkrefr_env$docker_port         <- as.character(port)
  .checkrefr_env$server_url          <- paste0("http://localhost:", port)
  .checkrefr_env$mode                <- "docker"
  .checkrefr_env$docker_image        <- docker_image
  .checkrefr_env$grobid_version      <- grobid_version
  .checkrefr_env$grobid_model_type   <- model_type

  .checkrefr_docker_wait_ready(
    url          = .checkrefr_env$server_url,
    timeout      = timeout_ready,
    container_id = container_id,
    verbose      = verbose
  )

  invisible(TRUE)
}



# Health check: waiting for GROBID to be ready


.checkrefr_docker_wait_ready <- function(url, timeout, container_id, verbose) {

  health_url <- paste0(url, "/api/isalive")
  deadline   <- Sys.time() + timeout
  ready      <- FALSE

  if (verbose) {
    cli::cli_progress_bar(
      name  = "Waiting for GROBID",
      total = timeout
    )
  }

  while (Sys.time() < deadline) {

    still_running <- suppressWarnings(
      system2("docker", args = c("inspect", "--format", "{{.State.Running}}", container_id),
              stdout = TRUE, stderr = FALSE)
    )
    if (!identical(trimws(still_running), "true")) {
      if (verbose) cli::cli_alert_danger("The container stopped prematurely.")
      break
    }

    resp <- tryCatch(
      httr2::request(health_url) |>
        httr2::req_timeout(3L)  |>
        httr2::req_error(is_error = \(r) FALSE) |>
        httr2::req_perform(),
      error = function(e) NULL
    )

    if (!is.null(resp) && httr2::resp_status(resp) == 200L) {
      ready <- TRUE
      break
    }

    if (verbose) cli::cli_progress_update()
    Sys.sleep(2L)
  }

  if (verbose) cli::cli_progress_done()

  if (!ready) {
    logs <- .checkrefr_capture_logs(container_id)

    cli::cli_abort(c(
      "GROBID did not start within the allotted time ({timeout}s).",
      "i" = "Container logs:",
      paste0("  ", logs)
    ))
  }

  if (verbose) cli::cli_alert_success("GROBID is ready at {url}")
  invisible(TRUE)
}


.start_docker <- function(timeout = 60) {

  # 0. Check that Docker is installed
  if (!.checkrefr_docker_installed()) {
    stop("Docker is not installed or cannot be found in the PATH.")
  }

  os <- Sys.info()["sysname"]

  # 1. Launch Docker depending on the OS
  if (os == "Windows") {

    exe <- .find_docker_desktop_windows()
    if (is.na(exe)) stop("Docker Desktop could not be found on this Windows system.")
    shell(paste0('start "" "', exe, '"'), wait = FALSE)

  } else if (os == "Darwin") {

    app <- "/Applications/Docker.app"
    if (!dir.exists(app)) stop("Docker Desktop could not be found on this Mac.")
    system2("open", args = c("-a", "Docker"), wait = FALSE)

  } else if (os == "Linux") {

    ret <- system2("systemctl", args = c("start", "docker"),
                   stdout = FALSE, stderr = FALSE)
    if (ret != 0) stop("Unable to start Docker. Check your permissions (docker group).")

  } else {
    stop("Unsupported OS: ", os)
  }

  # 2. Wait for Docker to be ready
  message("Starting Docker", appendLF = FALSE)
  debut <- proc.time()["elapsed"]

  repeat {

    pret <- system2("docker", args = "info",
                    stdout = FALSE, stderr = FALSE) == 0
    if (pret) {
      message("\u2705")
      return(invisible(TRUE))
    }

    ecoule <- proc.time()["elapsed"] - debut
    if (ecoule > timeout) {
      message("")
      stop("Docker did not start within the allotted time (", timeout, "s).")
    }

    message(".", appendLF = FALSE)
    Sys.sleep(3)
  }
}


# Windows helper
.find_docker_desktop_windows <- function() {

  # Method 1: common paths (priority)
  chemins <- c(
    file.path(Sys.getenv("ProgramFiles"),  "Docker/Docker/Docker Desktop.exe"),
    file.path(Sys.getenv("LOCALAPPDATA"),  "Programs/Docker/Docker/Docker Desktop.exe"),
    file.path(Sys.getenv("ProgramW6432"),  "Docker/Docker/Docker Desktop.exe")
  )
  trouve <- chemins[file.exists(chemins)]
  if (length(trouve) > 0) return(trouve[1])

  # Method 2: PowerShell - search the registry
  ps <- tryCatch(
    system2("powershell",
            args = c("-Command",
                     '(Get-ItemProperty "HKLM:\\SOFTWARE\\Docker Inc.\\Docker Desktop" -ErrorAction SilentlyContinue).InstallLocation'),
            stdout = TRUE, stderr = FALSE),
    warning = function(w) character(0),
    error   = function(e) character(0)
  )
  if (length(ps) > 0 && nchar(ps[1]) > 0) {
    return(file.path(ps[1], "Docker Desktop.exe"))
  }

  return(NA_character_)
}



# Stopping the GROBID Docker container

#' Stop the currently running GROBID Docker container
#'
#' Stops the GROBID container started via [grobid_docker_start()]. By default,
#' the function targets the container registered in the package's internal
#' environment (`.checkrefr_env$docker_container_id`). An explicit identifier
#' can be provided to stop a different container.
#'
#' @param container_id `character(1)` or `NULL`. Identifier of the container to
#'   stop. If `NULL`, uses the container currently registered in
#'   `.checkrefr_env$docker_container_id`. Default: `NULL`.
#' @param verbose `logical(1)` Display progress messages.
#'   Default: `TRUE`.
#'
#' @return `invisible(TRUE)` if the container was stopped (or was not
#'   active), `invisible(FALSE)` if no container could be identified.
#'
#' @details
#' Since the container was launched with the `--rm` option (see
#' [grobid_docker_start()]), stopping it via `docker stop` also causes
#' its automatic removal by Docker. The package's internal variables
#' (`docker_container_id`, `server_url`, `mode`) are reset after
#' stopping.
#'
#' @examples
#' \dontrun{
#' grobid_docker_start()
#' grobid_docker_stop()
#' }
#'
#' @seealso [grobid_docker_start()], [grobid_docker_check()]
#'
#' @importFrom cli cli_abort cli_alert_info cli_alert_success cli_progress_step
#' @export
# Stopping the GROBID Docker container
grobid_docker_stop <- function(container_id = NULL, verbose = TRUE) {

  # -- 0. Docker must be installed to be able to stop anything
  if (!.checkrefr_docker_installed()) {
    cli::cli_abort(c(
      "Docker could not be found on this system.",
      "i" = "Nothing to stop."
    ))
  }

  # -- 0bis. Docker daemon must be running to interact with containers
  if (!.checkrefr_docker_running()) {
    if (verbose) {
      cli::cli_alert_warning(
        "Docker is installed but the daemon is not running. Nothing to stop."
      )
    }
    return(invisible(FALSE))
  }

  # -- 1. Resolving the container identifier
  target_id <- container_id %||% .checkrefr_env$docker_container_id

  if (is.null(target_id) || is.na(target_id)) {
    # Attempt to resync before giving up
    .checkrefr_sync_env_from_container(verbose = FALSE)
    target_id <- .checkrefr_env$docker_container_id
  }

  if (is.null(target_id) || is.na(target_id)) {
    if (verbose) {
      cli::cli_alert_info("No GROBID container registered or active.")
    }
    return(invisible(FALSE))
  }

  # -- 2. Check that the container is actually active before attempting to stop it
  inspect_result <- suppressWarnings(
    system2(
      "docker",
      args   = c("inspect", "--format", "{{.State.Running}}", target_id),
      stdout = TRUE,
      stderr = TRUE
    )
  )

  inspect_status <- attr(inspect_result, "status")
  container_exists <- is.null(inspect_status) || inspect_status == 0L

  if (!container_exists) {
    cli::cli_abort(c(
      "Failed to stop container {.val {substr(target_id, 1, 12)}}.",
      "i" = "Docker output: {paste(inspect_result, collapse = ' ')}"
    ))
  }

  if (!identical(trimws(inspect_result), "true")) {
    if (verbose) {
      cli::cli_alert_info(
        "Container {.val {substr(target_id, 1, 12)}} is not active."
      )
    }
    # We still clean up the internal state if it matched this container,
    # but only the Docker-specific fields: mode/server_url must only be
    # reset if the active mode is actually "docker". If the user has since
    # switched to "remote" (e.g. via grobid_remote_connect()), stopping a
    # leftover local container must NOT wipe out the active remote
    # configuration.
    if (identical(.checkrefr_env$docker_container_id, target_id)) {
      .checkrefr_env$docker_container_id <- NA_character_
      if (identical(.checkrefr_env$mode, "docker")) {
        .checkrefr_env$server_url <- NA_character_
        .checkrefr_env$mode       <- NA_character_
      }
    }
    return(invisible(TRUE))
  }

  # -- 3. Actual stop
  if (verbose) {
    cli::cli_progress_step(
      "Stopping container {.val {substr(target_id, 1, 12)}}..."
    )
  }

  result <- suppressWarnings(
    system2(
      "docker",
      args   = c("stop", target_id),
      stdout = TRUE,
      stderr = TRUE
    )
  )

  status <- attr(result, "status")
  success <- is.null(status) || status == 0L

  if (!success) {
    cli::cli_abort(c(
      "Failed to stop container {.val {substr(target_id, 1, 12)}}.",
      "i" = "Docker output: {paste(result, collapse = ' ')}"
    ))
  }

  # -- 4. Cleaning up the internal environment (only if it was "our" container)
  # Same rationale as step 2 above: only reset mode/server_url/docker_port
  # if the active mode is actually "docker", to avoid destroying an active
  # remote configuration as a side effect of stopping a local container.
  if (identical(.checkrefr_env$docker_container_id, target_id)) {
    .checkrefr_env$docker_container_id <- NA_character_
    if (identical(.checkrefr_env$mode, "docker")) {
      .checkrefr_env$server_url <- NA_character_
      .checkrefr_env$mode       <- NA_character_
      .checkrefr_env$docker_port <- .checkrefr_defaults$docker_port
    }
  }

  if (verbose) {
    cli::cli_alert_success(
      "Container {.val {substr(target_id, 1, 12)}} stopped successfully."
    )
  }

  invisible(TRUE)
}

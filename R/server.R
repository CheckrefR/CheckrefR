# Managing the connection to the remote GROBID server

.checkrefr_normalize_url <- function(url) {
  url <- trimws(url)

  if (!grepl("^https?://", url)) {
    cli::cli_abort(c(
      "The URL must start with {.val http://} or {.val https://}.",
      "i" = "URL provided: {.val {url}}"
    ))
  }

  # Remove trailing slash
  sub("/$", "", url)
}


#' @importFrom httr2 req_error req_perform req_timeout request resp_status
.checkrefr_ping <- function(url, timeout, interval = 3) {

  url_isalive <- paste0(url, "/api/isalive")
  deadline    <- Sys.time() + timeout

  while (Sys.time() < deadline) {

    success <- tryCatch(
      {
        resp <- httr2::request(url_isalive)  |>
          httr2::req_timeout(5)              |>  # timeout PER attempt
          httr2::req_error(is_error = \(r) FALSE) |>  # no error on 4xx/5xx
          httr2::req_perform()

        httr2::resp_status(resp) == 200L
      },
      error = function(e) FALSE  # connection refused -> retry
    )

    if (isTRUE(success)) return(TRUE)

    Sys.sleep(interval)
  }

  return(FALSE)
}


#' @importFrom httr2 req_perform req_timeout request resp_body_string
#' @importFrom jsonlite fromJSON
.checkrefr_get_version <- function(url, timeout) {
  tryCatch(
    {
      resp <- httr2::request(paste0(url, "/api/version")) |>
        httr2::req_timeout(timeout)                       |>
        httr2::req_perform()

      body <- httr2::resp_body_string(resp)

      # Some servers return a JSON {"version":"x.y.z","revision":"..."}
      # others return the string "x.y.z" directly
      parsed <- tryCatch(
        jsonlite::fromJSON(body),
        error = function(e) NULL
      )

      if (!is.null(parsed) && !is.null(parsed[["version"]])) {
        parsed[["version"]]
      } else {
        body  # raw string if no structured JSON
      }
    },
    error = function(e) NA_character_
  )
}




# Connection to the remote server


#' Configure the connection to a remote GROBID server
#'
#' Configures the package to use a GROBID server accessible via HTTP/HTTPS.
#'
#' @param url `character(1)` URL of the GROBID server.
#'   Default: `"https://grobidorg-grobid.hf.space"`.
#' @param model_type `character(1)` or `NULL`. Desired GROBID model
#'   variant for automatic selection of a remote server among
#'   `.checkrefr_env$remote_default_url`:
#'   \itemize{
#'     \item `NULL` or `""` (default) -- treated as `"crf"` for the
#'       URL selection (default rule, since no preference
#'       was expressed).
#'     \item `"crf"` / `"full"` -- uses the corresponding URL list.
#'   }
#'   See [grobid_process_file()] for more information on the `"crf"` or `"full"` model types.
#'   Ignored if `url` is provided explicitly.
#'   Default: `.checkrefr_env$grobid_model_type`.
#' @param timeout `integer(1)` Request timeout in seconds. Default: `120`.
#' @param verbose `logical(1)` Display messages. Default: `TRUE`.
#'
#' @return `invisible(TRUE)` if the server responds.
#' @importFrom cli cli_abort cli_alert_success cli_progress_step
#' @export
grobid_remote_connect <- function(
    url        = NULL,
    model_type = .checkrefr_env$grobid_model_type,
    timeout    = .checkrefr_env$timeout,
    verbose    = TRUE
) {

  model_type <- .checkrefr_normalize_model_type(model_type)

  # -- If no explicit URL is requested and a remote server
  # is already configured and working, avoid rechecking everything
  if (is.null(url) &&
      identical(.checkrefr_env$mode, "remote") &&
      !is.na(.checkrefr_env$server_url) &&
      identical(.checkrefr_env$grobid_model_type, model_type)) {    # consistency of requested type

    current_url <- .checkrefr_env$server_url

    if (.checkrefr_ping(.checkrefr_env$server_url, timeout)) {
      if (verbose) {
        cli::cli_alert_success(
          "Remote server already configured and reachable: {.url {current_url}}"
        )
      }
      return(invisible(TRUE))
    }
  }

  # -- Resolution of the candidate URL(s) ---------------------------- #
  urls_to_try <- if (!is.null(url)) {
    .checkrefr_normalize_url(url)
  } else {
    .checkrefr_resolve_remote_urls(model_type)
  }

  connected <- FALSE
  chosen_url <- NA_character_

  for (candidate in urls_to_try) {
    candidate_norm <- .checkrefr_normalize_url(candidate)

    if (verbose) {
      cli::cli_progress_step("Testing {.url {candidate_norm}}...")
    }

    if (.checkrefr_ping(candidate_norm, timeout = min(timeout, 15L))) {
      connected  <- TRUE
      chosen_url <- candidate_norm
      break
    }
  }

  if (!connected) {
    cli::cli_abort(c(
      "No reachable remote server among the tested URLs.",
      "i" = "URLs tested: {.val {urls_to_try}}"
    ))
  }

  .checkrefr_env$server_url        <- chosen_url
  .checkrefr_env$mode              <- "remote"
  .checkrefr_env$grobid_model_type <- model_type    # - NA if the user did not specify anything

  if (verbose) {
    label <- if (is.na(model_type)) "not specified (treated as crf for selection)" else model_type
    cli::cli_alert_success(
      "Connected to the remote GROBID server: {.url {chosen_url}} (model_type: {label})"
    )
  }

  invisible(TRUE)
}


# Information about the configured server


#' Get information about the configured GROBID server
#'
#' Returns a summary of the current GROBID server configuration
#' (execution mode, URL, version) and tests in real time the availability
#' of the API if a server is configured.
#'
#' @return An invisible `list` containing:
#' \describe{
#'   \item{`mode`}{`character`. Current execution mode: `"docker"`,
#'     `"remote"` or `"not configured"` if no server has yet been
#'     started or connected.}
#'   \item{`url`}{`character`. URL of the configured GROBID server
#'     (e.g. `"http://localhost:8070"`), or `NA` if no server is
#'     configured.}
#'   \item{`api_reachable`}{`logical`. `TRUE` if the GROBID API responds,
#'     `FALSE` otherwise (including if no server is configured).}
#'   \item{`grobid_version`}{`character`. GROBID version returned by
#'     the server if it is reachable, `NA` otherwise.}
#'   \item{`timeout`}{`integer`. Delay (in seconds) used for the connection
#'     test, taken from the current package configuration
#'     (see [checkrefr_set_defaults()]), or `NA` if no server is
#'     configured.}
#' }
#'
#'
#' @examples
#' \dontrun{
#' grobid_docker_start()
#' grobid_server_info()
#' }
#'
#' @seealso [grobid_check_requirements()] for a full diagnostic of
#'   the environment, [grobid_docker_start()] and [grobid_remote_connect()]
#'   to configure a server, [checkrefr_env_status()] to check
#'   the raw state of the package's internal environment.
#'
#' @importFrom cli cli_dl cli_h1
#' @export
grobid_server_info <- function() {

  mode    <- .checkrefr_env$mode
  url     <- .checkrefr_env$server_url
  timeout <- .checkrefr_env$timeout

  # -- Summary display (factored out to avoid duplication)
  .display_info <- function(info) {
    cli::cli_h1("GROBID Server")
    cli::cli_dl(c(
      "Mode"      = info$mode,
      "URL"       = if (!is.na(info$url)) info$url else "-",
      "Reachable" = if (isTRUE(info$api_reachable)) "yes" else "no",
      "Version"   = if (!is.na(info$grobid_version)) info$grobid_version
      else "unknown",
      "Timeout"   = if (!is.na(info$timeout)) paste0(info$timeout, "s")
      else "-"
    ))
  }

  # -- Not configured case
  if (is.na(mode)) {
    info <- list(
      mode           = "not configured",
      url            = NA_character_,
      api_reachable  = FALSE,
      grobid_version = NA_character_,
      timeout        = NA_integer_
    )

    .display_info(info)
    return(invisible(info))
  }

  # -- Configured case
  api_reachable <- tryCatch(
    .checkrefr_ping(url, timeout),
    error = function(e) FALSE
  )

  grobid_version <- if (isTRUE(api_reachable)) {
    tryCatch(
      .checkrefr_get_version(url, timeout),
      error = function(e) NA_character_
    )
  } else {
    NA_character_
  }

  info <- list(
    mode           = mode,
    url            = url,
    api_reachable  = api_reachable,
    grobid_version = grobid_version,
    timeout        = timeout
  )

  .display_info(info)
  invisible(info)
}


#' Resolves the URL (or list of candidate URLs) to use in remote mode
#' according to the requested model_type.
#'
#' Resolution rule:
#'   - If `model_type` is NA/empty -> treated as "crf" (only
#'     for URL selection; the value stored in
#'     `.checkrefr_env$grobid_model_type` remains unchanged if the user
#'     did not specify anything).
#'   - Otherwise, directly use the list corresponding to "crf" or
#'     "full" in `.checkrefr_env$remote_default_url`.
#'
#' @param model_type `character(1)` or `NA` -- normalized value (via
#'   `.checkrefr_normalize_model_type()`).
#' @return `character` vector of URLs ordered by priority.
#' @importFrom cli cli_abort
#' @noRd
.checkrefr_resolve_remote_urls <- function(model_type) {

  effective_type <- if (is.na(model_type)) "crf" else model_type   # >> REQUESTED RULE

  urls_by_type <- .checkrefr_env$remote_default_url

  if (!is.list(urls_by_type) || is.null(urls_by_type[[effective_type]])) {
    cli::cli_abort(c(
      "No URL configured for model type {.val {effective_type}}.",
      "i" = "Check {.code .checkrefr_env$remote_default_url} or use {.fn checkrefr_set_defaults}."
    ))
  }

  urls_by_type[[effective_type]]
}


#' Ensure the availability of the GROBID server
#'
#' Internal function that guarantees a GROBID server is accessible
#' before any operation requiring the service. Automatically handles
#' Docker mode (container startup) and remote mode (connection).
#'
#' @param mode `character(1)` Connection mode: `"docker"` or `"remote"`.
#'   Default: value of `.checkrefr_env$mode`, or `"docker"` if not defined.
#' @param verbose `logical(1)` Display progress messages.
#'   Default: `TRUE`.
#'
#' @return `invisible(TRUE)` if the server is ready.
#'
#' @importFrom cli cli_abort cli_alert_info cli_alert_success
#' @keywords internal
.checkrefr_ensure_server <- function(
    mode       = .checkrefr_env$mode,
    model_type = .checkrefr_env$grobid_model_type,
    verbose    = TRUE
) {
  # -- No more normalization here: model_type is already normalized by
  # the caller (grobid_process_file() / grobid_process_files()).

  if (is.na(mode)) mode <- "docker"

  if (!is.na(.checkrefr_env$mode) && .checkrefr_env$mode != mode) {

    # If a Docker container is currently active, it must be properly
    # stopped before losing its reference, otherwise it leaks as an
    # orphaned background process consuming RAM indefinitely.
    if (identical(.checkrefr_env$mode, "docker") &&
        !is.na(.checkrefr_env$docker_container_id)) {
      if (verbose) {
        cli::cli_alert_info(
          "Switching away from Docker mode: stopping the active container first..."
        )
      }
      grobid_docker_stop(verbose = verbose)
    }

    checkrefr_env_reset(
      fields  = c("mode", "docker_container_id", "docker_port",
                  "server_url", "grobid_version"),
      verbose = verbose
    )
  }

  # ===== DOCKER MODE ==================================================== #
  if (mode == "docker") {

    container_matches_type <- identical(.checkrefr_env$grobid_model_type, model_type)

    if (.checkrefr_container_active() && container_matches_type) {
      if (is.na(.checkrefr_env$server_url) || is.na(.checkrefr_env$mode)) {
        .checkrefr_sync_env_from_container(verbose = verbose)
      }
    } else {
      if (verbose) {
        label <- if (is.na(model_type)) "no variant specified" else model_type
        cli::cli_alert_info(
          "No active GROBID container ({label}). Starting automatically..."
        )
      }
      grobid_docker_start(model_type = model_type, verbose = verbose)
    }

    url     <- .checkrefr_env$server_url
    timeout <- .checkrefr_env$timeout

    if (!.checkrefr_ping(url, timeout)) {
      cli::cli_abort(c(
        "The Docker GROBID server is not responding.",
        "i" = "URL tested: {.url {url}}",
        "i" = "The container may still be starting up.",
        "i" = "Increase the timeout via {.fn grobid_docker_start}."
      ))
    }

    if (verbose) {
      cli::cli_alert_success("Docker GROBID server ready: {.url {url}}")
    }

    return(invisible(TRUE))
  }

  # ===== REMOTE MODE ==================================================== #
  if (mode == "remote") {

    type_matches <- identical(.checkrefr_env$grobid_model_type, model_type)

    url     <- .checkrefr_env$server_url
    timeout <- .checkrefr_env$timeout

    needs_connect <- is.na(url) || .checkrefr_env$mode != "remote" || !type_matches

    if (needs_connect) {
      if (verbose) {
        label <- if (is.na(model_type)) "no variant specified (treated as crf)" else model_type
        cli::cli_alert_info(
          "Connecting/reconnecting to the remote server ({label})..."
        )
      }
      grobid_remote_connect(model_type = model_type, timeout = timeout, verbose = verbose)
      url <- .checkrefr_env$server_url
    }

    if (!.checkrefr_ping(url, timeout)) {
      cli::cli_abort(c(
        "The remote GROBID server is not responding.",
        "i" = "URL tested: {.url {url}}",
        "i" = "Check the URL or increase the timeout via {.fn grobid_remote_connect}."
      ))
    }

    if (verbose) {
      cli::cli_alert_success("Remote GROBID server ready: {.url {url}}")
    }

    return(invisible(TRUE))
  }
}

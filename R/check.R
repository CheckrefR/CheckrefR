# 03_check.R

# Main diagnostic

#' Check system requirements for using GROBID
#'
#' Performs a complete diagnostic of the execution environment: operating
#' system, R version, Internet connection, Docker availability and
#' connectivity to one or more remote GROBID servers configured by
#' default. The diagnostic ends with a recommendation of the most suitable
#' operating mode (`"docker"` or `"remote"`), but this is not mandatory.
#'
#' @param verbose `logical(1)` Display a formatted report in the console.
#'   Default: `TRUE`.
#' @param check_docker `logical(1)` Include the check of Docker
#'   availability (installation, daemon startup, active GROBID
#'   container). Default: `TRUE`.
#' @param check_remote `logical(1)` Test connectivity to the remote
#'   servers configured by default (`.checkrefr_env$remote_default_url`).
#'   Default: `TRUE`.
#' @param test_all_urls `logical(1)` If `TRUE`, tests all URLs
#'   configured for each mode (`"crf"` / `"full"`) even after finding a
#'   first reachable URL. If `FALSE`, the function stops testing as soon
#'   as a reachable URL is found. Default: `TRUE`.
#'   For details concerning the GROBID model type (`"crf"` / `"full"`)
#'   see the documentation of [grobid_process_file()].
#'
#' @return A `list` (returned invisibly) containing the following fields:
#'   \describe{
#'     \item{`os`}{`character(1)` Detected operating system
#'       (`"windows"`, `"macos"`, `"linux"` or other).}
#'     \item{`os_version`}{`character(1)` OS version detail.}
#'     \item{`r_version`}{`character(1)` R version used.}
#'     \item{`internet_available`}{`logical(1)` Internet connection detected.}
#'     \item{`docker_installed`}{`logical(1)` Docker is installed.}
#'     \item{`docker_running`}{`logical(1)` The Docker daemon is running.}
#'     \item{`docker_version`}{`character(1)` Docker client version,
#'       or `NA` if not installed.}
#'     \item{`grobid_container_active`}{`logical(1)` A GROBID container
#'       is currently active.}
#'     \item{`grobid_container_id`}{`character(1)` Identifier of the
#'       active GROBID container, or `NA` otherwise.}
#'     \item{`remote_default_reachable`}{`logical(1)` At least one
#'       default remote server is reachable.}
#'     \item{`remote_reachable_urls`}{`list` named by mode (`"crf"`,
#'       `"full"`) of `character` vectors of reachable URLs.}
#'     \item{`recommended_url`}{`character(1)` Recommended remote URL,
#'       or `NA` if none is reachable.}
#'     \item{`recommended_remote_mode`}{`character(1)` Mode associated
#'       with the recommended URL (`"crf"` or `"full"`), or `NA`.}
#'     \item{`current_mode`}{`character(1)` Mode currently configured
#'       in the package's internal environment.}
#'     \item{`current_url`}{`character(1)` Currently configured URL.}
#'     \item{`recommended_mode`}{`character(1)` Recommended global
#'       mode: `"docker"`, `"remote"` or `NA` if no mode is available.}
#'   }
#'
#' @examples
#' \dontrun{
#' # Full diagnostic with console report
#' grobid_check_requirements()
#'
#' # Silent diagnostic, without Docker check
#' req <- grobid_check_requirements(verbose = FALSE, check_docker = FALSE)
#' req$recommended_mode
#' }
#'
#' @seealso [grobid_install_guide()], [grobid_docker_check()],
#'   [grobid_server_info()], [checkrefr_set_defaults()]
#'
#' @importFrom cli cli_h2 cli_alert_success cli_h1 cli_ul cli_alert_info cli_alert_warning cli_text cli_abort cli_alert_danger cli_progress_done col_green col_red cli_warn
#'
#' @export
grobid_check_requirements <- function(
    verbose        = TRUE,
    check_docker   = TRUE,
    check_remote   = TRUE,
    test_all_urls  = TRUE
) {

  # -- OS
  sysname    <- Sys.info()[["sysname"]]
  os         <- switch(sysname,
                       "Windows" = "windows",
                       "Darwin"  = "macos",
                       "Linux"   = "linux",
                       to_lower_unicode(sysname)
  )
  os_version <- paste(sysname, R.version$os)
  r_version  <- paste0(R.version$major, ".", R.version$minor)

  # -- Internet & Remote servers (fused test)
  # Rationale: testing Google alone can produce false negatives on restricted
  # networks (corporate proxy, firewall) where the actual GROBID remote
  # servers are reachable. Conversely, we must always determine
  # internet_available independently of check_remote, since it is used
  # elsewhere in the package regardless of whether GROBID servers respond.
  #
  # Strategy:
  #   1. Always test Google first (fast, cheap, works in the vast majority
  #      of environments).
  #   2. If check_remote is TRUE, also test the configured GROBID remote
  #      URLs (crf/full). This single pass feeds both `internet_available`
  #      (if ANY of Google or a GROBID URL responds, internet is available)
  #      and the detailed remote diagnostic (`remote_reachable_urls`,
  #      `recommended_url`, etc.).
  #   3. If check_remote is FALSE, only Google is tested for internet.

  if (verbose) cli::cli_alert_info("Checking Internet connection...")

  internet <- FALSE

  # -- Step 1: Google test (always performed)
  google_ok <- .checkrefr_check_internet()
  if (isTRUE(google_ok)) {
    internet <- TRUE
    if (verbose) cli::cli_alert_success("Internet reachable (via Google).")
  } else if (verbose) {
    cli::cli_alert_warning(
      "Google unreachable. Will also try configured GROBID remote server(s) \\
      to confirm Internet availability."
    )
  }

  # -- Step 2: Remote GROBID servers (Multi-URL, structured by mode: "crf" / "full")
  remote_reachable_urls    <- list()   # named list of reachable URL vectors, by mode
  remote_default_reachable <- FALSE
  recommended_url          <- NA_character_
  recommended_remote_mode  <- NA_character_  # "crf" or "full"
  urls_to_test             <- list()
  urls_status              <- list()

  # We must run the remote URL test if check_remote is TRUE, OR if Google
  # failed and we still need to determine internet_available via a
  # GROBID URL fallback.
  need_remote_test <- isTRUE(check_remote) || !internet

  if (need_remote_test) {
    if (verbose) cli::cli_h2("Testing remote servers")

    # Named list configured via checkrefr_set_defaults, e.g. list(crf = c(...), full = c(...))
    urls_to_test <- .checkrefr_env$remote_default_url

    # Initialize output structures with the same names/lengths
    urls_status <- lapply(urls_to_test, function(v) logical(0))
    remote_reachable_urls <- lapply(urls_to_test, function(v) character(0))

    stop_all <- FALSE  # flag to also interrupt the outer loop if test_all_urls = FALSE

    for (mode_name in names(urls_to_test)) {

      urls_vec <- urls_to_test[[mode_name]]

      for (url in urls_vec) {
        if (verbose) cli::cli_alert_info("Testing {.url {url}} [{mode_name}]...")

        is_alive <- .checkrefr_ping(url, timeout = 5L)

        urls_status[[mode_name]] <- c(urls_status[[mode_name]], is_alive)

        if (is_alive) {

          # Any responding GROBID server confirms Internet availability,
          # even if Google itself was unreachable (restricted network case).
          if (!internet) {
            internet <- TRUE
            if (verbose) {
              cli::cli_alert_success(
                "Internet reachable (confirmed via GROBID server {.url {url}})."
              )
            }
          }

          remote_reachable_urls[[mode_name]] <- c(remote_reachable_urls[[mode_name]], url)

          if (!remote_default_reachable) {
            remote_default_reachable <- TRUE
            recommended_url          <- url        # Store the priority URL that responds
            recommended_remote_mode  <- mode_name   # ... as well as its associated mode
            if (verbose) {
              cli::cli_alert_success(
                "Operational server found: {.url {url}} (mode: {mode_name})"
              )
            }
          }

          if (!test_all_urls) {
            stop_all <- TRUE
            break  # exit the inner loop (urls_vec)
          }
        }
      }

      if (stop_all) break  # exit the outer loop (names(urls_to_test))
    }
  }

  # -- Docker
  docker_installed         <- FALSE
  docker_running           <- FALSE
  docker_version           <- NA_character_
  grobid_container_active  <- FALSE
  grobid_container_id      <- NA_character_

  if (check_docker) {
    if (verbose) cli::cli_alert_info("Checking Docker...")
    docker_installed <- .checkrefr_docker_installed()
    docker_running   <- .checkrefr_docker_running()
    docker_version   <- .checkrefr_docker_version()

    if (docker_running) {
      grobid_container_active <- .checkrefr_container_active()
      grobid_container_id     <- if (grobid_container_active) {
        .checkrefr_env$docker_container_id
      } else {
        NA_character_
      }
    }
  }

  # -- Recommended mode
  # Docker-first policy: Docker being *installed* is enough to make it the
  # recommended path, since starting the daemon (grobid_docker_start()) can
  # be automated by the package. Remote is only recommended as the primary
  # path when Docker is not installed at all on the system.
  recommended_mode <- if (docker_installed) {
    "docker"
  } else if (remote_default_reachable) {
    "remote"
  } else {
    "none"
  }

  # -- Current state
  current_mode_raw <- .checkrefr_env$mode
  current_mode <- if (is.null(current_mode_raw) ||
                      length(current_mode_raw) == 0L ||
                      is.na(current_mode_raw)) {
    "not configured"
  } else {
    current_mode_raw
  }
  current_url_raw <- .checkrefr_env$server_url
  current_url <- if (is.null(current_url_raw) ||
                     length(current_url_raw) == 0L ||
                     is.na(current_url_raw)) {
    "not configured"
  } else {
    current_url_raw
  }

  # -- Building the result list
  result <- list(
    os                       = os,
    os_version               = os_version,
    r_version                = r_version,
    internet_available       = internet,
    docker_installed         = docker_installed,
    docker_running           = docker_running,
    docker_version           = docker_version,
    grobid_container_active  = grobid_container_active,
    grobid_container_id      = grobid_container_id,
    remote_default_reachable = remote_default_reachable,
    remote_reachable_urls    = remote_reachable_urls,   # named list by mode
    recommended_url          = recommended_url,
    recommended_remote_mode  = recommended_remote_mode, # "crf", "full" or NA
    current_mode             = current_mode,
    current_url              = current_url,
    recommended_mode         = recommended_mode
  )

  # -- Console report
  if (verbose) {
    cli::cli_h1("GROBID Diagnostic")

    cli::cli_h2("Environment")
    cli::cli_ul(c(
      "OS      : {os} ({os_version})",
      "R       : {r_version}",
      "Internet: {(.checkrefr_status_icon(internet))}"
    ))

    if (check_docker) {
      cli::cli_h2("Docker")
      cli::cli_ul(c(
        "Installed : {(.checkrefr_status_icon(docker_installed))}",
        "Running   : {(.checkrefr_status_icon(docker_running))}",
        "Version   : {if (!is.na(docker_version)) docker_version else 'N/A'}",
        "Active GROBID container : {(.checkrefr_status_icon(grobid_container_active))}"
      ))
      if (grobid_container_active) {
        cli::cli_alert_info(
          "Container ID: {.val {substr(grobid_container_id, 1, 12)}}"
        )
      }
      if (docker_installed && !docker_running) {
        cli::cli_alert_info(
          "Docker is installed but not currently running. It can be started automatically \\
          when needed (e.g. via {.fn grobid_docker_start})."
        )
      }
    }

    if (check_remote) {
      cli::cli_h2("Remote server(s)")

      if (length(urls_to_test) == 0L) {
        cli::cli_alert_warning(
          "No remote server tested (Internet unavailable or empty list)."
        )
      } else {
        # Detail by mode, then by URL actually tested
        for (mode_name in names(urls_to_test)) {

          urls_vec    <- urls_to_test[[mode_name]]
          status_vec  <- urls_status[[mode_name]]

          if (length(status_vec) == 0L) next  # mode not tested (e.g. early stop)

          cli::cli_text("{.strong Mode {mode_name}}:")

          details <- vapply(
            seq_along(status_vec),
            function(i) {
              paste0(
                urls_vec[i], " : ",
                .checkrefr_status_icon(status_vec[i])
              )
            },
            character(1)
          )
          cli::cli_ul(details)
        }

        cli::cli_ul(c(
          "Reachable remote server : {(.checkrefr_status_icon(remote_default_reachable))}"
        ))

        if (remote_default_reachable) {
          cli::cli_alert_info(
            "Recommended URL: {.url {recommended_url}} (mode: {recommended_remote_mode})"
          )
        }
      }
    }

    cli::cli_h2("Current configuration")
    cli::cli_ul(c(
      "Mode : {current_mode}",
      "URL  : {if (!is.na(current_url)) current_url else 'not defined'}"
    ))

    cli::cli_h2("Recommendation")
    switch(recommended_mode,
           "docker" = {
             if (docker_running) {
               cli::cli_alert_success(
                 "Docker is running - use {.fn grobid_docker_start} to launch or reuse the GROBID container."
               )
             } else {
               cli::cli_alert_success(
                 "Docker is installed on this system: {.strong local mode is strongly recommended}."
               )
               cli::cli_alert_info(
                 "Run {.fn grobid_docker_start} to start Docker and the GROBID container automatically."
               )
               if (remote_default_reachable) {
                 cli::cli_alert_warning(
                   "A remote server is also reachable, but relying on Docker (local) \\
                   is preferable for stability and independence from \\
                   external service availability."
                 )
               }
             }
           },
           "remote" = cli::cli_alert_warning(
             "Docker is not installed on this system. A remote server is reachable \\
             ({.url {recommended_url}}, mode: {recommended_remote_mode}) and can be used \\
             as a fallback via {.fn grobid_remote_connect}, but installing Docker \\
             is recommended for a more reliable, self-contained setup. \\
             See {.fn grobid_install_guide} for installation instructions."
           ),
           cli::cli_alert_danger(
             "No mode available. Install Docker (recommended) or check your Internet connection. \\
             See {.fn grobid_install_guide} for step-by-step instructions."
           )
    )
  }

  # Marking: we add the class, without changing anything else
  class(result) <- c("checkrefr_requirements", class(result))

  invisible(result)
}


# Internal helpers


# Check Internet availability

.checkrefr_check_internet <- function() {
  tryCatch(
    {
      httr2::request("https://www.google.com") |>
        httr2::req_timeout(5L)                 |>
        httr2::req_perform()
      TRUE
    },
    error = function(e) FALSE
  )
}


# Note: port checking delegates to .checkrefr_port_is_free()
# defined in 01_docker.R - no duplication needed.


# Internal Docker helpers


.checkrefr_docker_installed <- function() {
  nchar(Sys.which("docker")) > 0L
}

.checkrefr_docker_running <- function() {
  if (!.checkrefr_docker_installed()) return(FALSE)
  system2("docker", args = "info", stdout = FALSE, stderr = FALSE) == 0L
}


.checkrefr_docker_version <- function() {
  if (!.checkrefr_docker_installed()) return(NA_character_)
  tryCatch(
    {
      out <- suppressWarnings(
        system2(
          "docker",
          args   = c("version", "--format", "{{.Client.Version}}"),
          stdout = TRUE,
          stderr = FALSE
        )
      )
      trimws(paste(out, collapse = ""))
    },
    error = function(e) NA_character_
  )
}

.checkrefr_container_active <- function() {
  container_id <- .checkrefr_env$docker_container_id
  if (is.na(container_id)) return(FALSE)

  result <- suppressWarnings(
    system2(
      "docker",
      args   = c("inspect", "--format", "{{.State.Running}}", container_id),
      stdout = TRUE,
      stderr = FALSE
    )
  )
  identical(trimws(result), "true")
}


# Internal display helper


.checkrefr_status_icon <- function(ok) {
  if (isTRUE(ok)) cli::col_green("\u2713") else cli::col_red("\u2717")
}


# Check if a Docker image is already present locally
.checkrefr_image_exists <- function(image) {
  result <- suppressWarnings(
    system2(
      "docker",
      args   = c("images", "-q", image),
      stdout = TRUE,
      stderr = FALSE
    )
  )
  length(result) > 0L && nzchar(trimws(result[1]))
}

# List of available GROBID Docker versions

#' List available GROBID Docker versions on Docker Hub
#'
#' Queries the Docker Hub API to retrieve the list of available tags
#' for a given GROBID image. Allows identifying usable versions
#' with [grobid_docker_start()] or by modifying the default
#' parameters via [checkrefr_set_defaults()].
#'
#' @param repository `character(1)` or `NULL`. Name of the Docker Hub
#'   repository in the form `"namespace/image"`. If `NULL`, automatically
#'   resolved from `.checkrefr_env$docker_image` (normally `"lfoppiano/grobid"`).
#'   Default: `NULL`.
#' @param page_size `integer(1)` Number of results per queried page
#'   (max allowed by the Docker Hub API: 100). Default: `100L`.
#' @param max_pages `integer(1)` Maximum number of pages to browse, to
#'   avoid infinite pagination. Default: `10L`.
#' @param verbose `logical(1)` Display the formatted list in the console.
#'   Default: `TRUE`.
#'
#' @return `tibble` (invisibly) with columns `name` (tag), `full_size`
#'   (size in bytes), `last_updated` and `digest`. Sorted by `last_updated`
#'   descending.
#'
#' @details
#' Uses the public unauthenticated endpoint:
#' \url{https://hub.docker.com/v2/repositories/lfoppiano/grobid/tags/}
#' (to be adapted according to the requested `repository`).
#'
#' @examples
#' \dontrun{
#' grobid_docker_list_versions()
#' grobid_docker_list_versions(repository = "grobid/grobid")
#' }
#'
#' @seealso [grobid_docker_start()]
#'
#' @importFrom cli cli_abort cli_progress_done cli_warn cli_h1 cli_alert_info cli_ul
#' @importFrom httr2 request req_timeout req_error req_perform resp_status resp_body_json
#' @importFrom tibble tibble
#'
#' @export
grobid_docker_list_versions <- function(
    repository = NULL,
    page_size  = 100L,
    max_pages  = 10L,
    verbose    = TRUE
) {

  # -- Resolve default repository from the configured image
  if (is.null(repository)) {
    # .checkrefr_env$docker_image is e.g. "lfoppiano/grobid:"
    repository <- sub(":$", "", .checkrefr_env$docker_image)
  }

  page_size <- as.integer(page_size)
  max_pages <- as.integer(max_pages)

  base_url <- sprintf(
    "https://hub.docker.com/v2/repositories/%s/tags/",
    repository
  )

  if (verbose) {
    cli::cli_alert_info(
      "Retrieving tags for {.val {repository}}..."
    )
  }

  results   <- list()
  url       <- paste0(base_url, "?page_size=", page_size)
  page_n    <- 0L

  repeat {
    page_n <- page_n + 1L

    resp <- tryCatch(
      httr2::request(url)                      |>
        httr2::req_timeout(10L)                 |>
        httr2::req_error(is_error = \(r) FALSE) |>
        httr2::req_perform(),
      error = function(e) NULL
    )

    if (is.null(resp)) {
      cli::cli_abort(c(
        "Unable to contact Docker Hub.",
        "i" = "Check your Internet connection."
      ))
    }

    status <- httr2::resp_status(resp)

    if (status == 404L) {
      cli::cli_abort(c(
        "Repository not found: {.val {repository}}.",
        "i" = "Check the name in the form {.val namespace/image}."
      ))
    }

    if (status != 200L) {
      cli::cli_abort(
        "Unexpected response from Docker Hub (HTTP {status})."
      )
    }

    body <- httr2::resp_body_json(resp, simplifyVector = FALSE)

    page_results <- body$results
    if (length(page_results) == 0L) break

    results <- c(results, page_results)

    next_url <- body$`next`
    if (is.null(next_url) || page_n >= max_pages) break

    url <- next_url
  }

  if (verbose) cli::cli_progress_done()

  if (length(results) == 0L) {
    cli::cli_warn("No tag found for {.val {repository}}.")
    return(invisible(tibble::tibble(
      name         = character(0),
      full_size    = numeric(0),
      last_updated = character(0),
      digest       = character(0)
    )))
  }

  # -- Building the output tibble
  rows <- lapply(results, function(tag) {
    digest <- NA_character_
    images <- tag$images
    if (!is.null(images) && length(images) > 0L) {
      digest <- images[[1]]$digest %||% NA_character_
    }

    tibble::tibble(
      name         = tag$name %||% NA_character_,
      full_size    = as.numeric(tag$full_size %||% NA_real_),
      last_updated = tag$last_updated %||% NA_character_,
      digest       = digest
    )
  })

  out <- do.call(rbind, rows)
  out <- out[order(out$last_updated, decreasing = TRUE), ]
  rownames(out) <- NULL

  # -- Console display
  if (verbose) {
    cli::cli_h1("Available GROBID Docker versions")
    cli::cli_alert_info("Repository: {.val {repository}}")

    n_show <- min(20L, nrow(out))
    for (i in seq_len(n_show)) {
      size_mb <- if (!is.na(out$full_size[i])) {
        sprintf("%.0f MB", out$full_size[i] / 1e6)
      } else {
        "unknown size"
      }
      cli::cli_ul(sprintf(
        "%-25s | %-15s | %s",
        out$name[i], size_mb, substr(out$last_updated[i], 1, 10)
      ))
    }

    if (nrow(out) > n_show) {
      cli::cli_alert_info(
        "... and {nrow(out) - n_show} additional tag(s). See the return value for the full list."
      )
    }

    cli::cli_alert_info(
      "Use {.fn grobid_docker_start} with {.arg grobid_version} to choose a version."
    )
  }

  invisible(out)
}

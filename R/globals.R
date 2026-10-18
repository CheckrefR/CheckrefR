
# 00_globals.R
# Internal package environment and default values



# Creation of the internal package environment


.checkrefr_env <- new.env(parent = emptyenv())


# Initialization of state variables with their default values


.checkrefr_defaults <- list(
  pkg_name             = "checkrefr",
  pkg_repo             = "https://github.com/checkrefr/checkrefr",
  mode               = NA_character_,
  docker_port        = "8070",
  docker_container_id = NA_character_,
  docker_image        = "lfoppiano/grobid:",
  grobid_version      = "0.9.0",
  grobid_model_type    = NA_character_,
  grobid_email        = NA_character_,
  server_url         = NA_character_,
  remote_default_url = list(
    crf = c(
      "https://grobidorg-grobid.hf.space",
      "https://grobidorg-grobid2.hf.space"
    ),
    full = c(
      "https://grobidorg-grobid-full.hf.space",
      "https://grobidOrg-grobid-full2.hf.space"
    )
  ),
  timeout            = 120L,
  max_workers        = 4L,
  oa_probable_threshold = 0.85,       # "probable" threshold
  oa_min_threshold      = 0.60,       # minimal inclusion threshold
  # oa_author_threshold   = 0.80,       # individual author threshold NOT used, review
  oa_doi_threshold      = 0.90,       # acceptance threshold for DOI article matching
  oa_w_title            = 0.60,       # title weight in global score
  oa_w_authors          = 0.30,       # authors weight in global score
  oa_w_year             = 0.10,       # year weight in global score
  oa_max_candidates     = 3L,         # max number of candidates presented
  oa_api_key              = NA_character_, # API key for the OA
  oa_use_window            = FALSE,   # sliding window for author analysis
  oa_window_size              = 2,       # window size (±k)
  oa_large_author_threshold = 10,      # "large list" threshold
  oa_min_coverage_ratio    = 0.65,    # marginal vs massive truncation threshold
  oa_author_lambda         = 0.4,     # truncation penalty
  oa_sym_max_diff_abs      = 2,       # absolute tolerance for symmetric case
  oa_sym_max_diff_prop     = 0.10,    # proportional tolerance for symmetric case
  doi_email         = NA_character_, # email for polite User-Agent (Crossref)
  doi_max_retries   = 3L,            # max number of attempts in case of 5xx / network error
  doi_retry_backoff = 1               # initial delay (s), doubled at each attempt
)


# (Re)initialization function of the environment


.checkrefr_init_env <- function() {
  for (nm in names(.checkrefr_defaults)) {
    assign(nm, .checkrefr_defaults[[nm]], envir = .checkrefr_env)
  }
  invisible(.checkrefr_env)
}


# Package loading: silent initialization


.onLoad <- function(libname, pkgname) {
  .checkrefr_init_env()
}


#' Reset the CheckrefR environment to its default values
#'
#' @description
#' Resets all or part of the internal variables of the CheckrefR
#' environment (`.checkrefr_env`) to their original default values.
#' Allows a
#' complete reset (default behavior) or a
#' targeted reset of a subset of variables.
#'
#' @param fields `character` or `NULL`. Vector of variable names to
#'   reset. If `NULL` (default), the entire environment is
#'   reset.
#'   Recognized variables, grouped by category:
#'   \describe{
#'     \item{Connection / Docker}{
#'       \itemize{
#'         \item `mode` (`character` or `NA`) — Current connection mode
#'           (`"docker"`, `"remote"` or not configured). Default: `NA`.
#'         \item `docker_port` (`character`) — Local port used for the
#'           GROBID Docker container. Default: `"8070"`.
#'         \item `docker_container_id` (`character` or `NA`) — Identifier
#'           of the active GROBID Docker container. Default: `NA`.
#'         \item `docker_image` (`character`) — Base name of the GROBID
#'           Docker image (before adding the version tag). Default:
#'           `"lfoppiano/grobid:"`.
#'         \item `grobid_version` (`character`) — GROBID version
#'           used for the Docker tag. Default: `"0.9.0"`.
#'         \item `grobid_model_type` (`character` or `NA`) — Variant of
#'           the GROBID model (`"crf"` or `"full"`). Default: `NA`.
#'         \item `server_url` (`character` or `NA`) — URL of the
#'           currently configured GROBID server (local or remote). Default:
#'           `NA`.
#'       }
#'     }
#'     \item{Remote connection}{
#'       \itemize{
#'         \item `remote_default_url` (`list`) — Structure nested by
#'           model type (`"crf"`, `"full"`), each associated with a
#'           `character` vector of default remote server URLs.
#'         \item `timeout` (`integer`) — Default timeout (in seconds)
#'           for HTTP requests to the GROBID API. Default: `120L`.
#'       }
#'     }
#'     \item{Batch processing}{
#'       \itemize{
#'         \item `max_workers` (`integer`) — Number of workers used in
#'           parallel mode by [grobid_process_files()]. Default: `4L`.
#'       }
#'     }
#'     \item{OpenAlex matching — thresholds}{
#'       \itemize{
#'         \item `oa_probable_threshold` (`numeric`) — Global score
#'           threshold above which a candidate is considered as
#'           "probable". Default: `0.85`.
#'         \item `oa_min_threshold` (`numeric`) — Minimal threshold
#'           for including a candidate. Default: `0.60`.
#'         \item `oa_doi_threshold` (`numeric`) — Acceptance threshold for
#'           article matching via DOI. Default: `0.90`.
#'       }
#'     }
#'     \item{OpenAlex matching — weighting}{
#'       \itemize{
#'         \item `oa_w_title` (`numeric`) — Weight of the title in the
#'           global score. Default: `0.60`.
#'         \item `oa_w_authors` (`numeric`) — Weight of the authors in the
#'           global score. Default: `0.30`.
#'         \item `oa_w_year` (`numeric`) — Weight of the year in the
#'           global score. Default: `0.10`.
#'       }
#'     }
#'     \item{OpenAlex queries}{
#'       \itemize{
#'         \item `oa_max_candidates` (`integer`) — Maximum number of
#'           candidates presented per reference. Default: `3L`.
#'         \item `oa_api_key` (`character` or `NA`) — API key used for the
#'           OpenAlex "polite pool". Default: `NA`.
#'       }
#'     }
#'     \item{OpenAlex matching — author analysis}{
#'       \itemize{
#'         \item `oa_use_window` (`logical`) — Enables a sliding window
#'           for author list analysis. Default: `FALSE`.
#'         \item `oa_window_size` (`numeric`) — Size of the sliding
#'           window (±k). Default: `2`.
#'         \item `oa_large_author_threshold` (`numeric`) — Threshold from
#'           which an author list is considered "large".
#'           Default: `10`.
#'         \item `oa_min_coverage_ratio` (`numeric`) — Threshold distinguishing
#'           marginal truncation from massive truncation of the author
#'           list. Default: `0.65`.
#'         \item `oa_author_lambda` (`numeric`) — Penalty factor
#'           applied in case of truncation of the author list. Default:
#'           `0.4`.
#'         \item `oa_sym_max_diff_abs` (`numeric`) — Absolute tolerance
#'           applied in the symmetric case (similar number of authors).
#'           Default: `2`.
#'         \item `oa_sym_max_diff_prop` (`numeric`) — Proportional
#'           tolerance applied in the symmetric case. Default:
#'           `0.10`.
#'       }
#'     }
#'     \item{DOI validation}{
#'       \itemize{
#'         \item `doi_email` (`character` or `NA`) — Email used for the
#'           polite User-Agent when querying Crossref / doi.org.
#'           Default: `NA`.
#'         \item `doi_max_retries` (`integer`) — Maximum number of
#'           attempts in case of network error or 5xx response for
#'           requests to doi.org. Default: `3L`.
#'         \item `doi_retry_backoff` (`numeric`) — Initial delay (in
#'           seconds) before a new attempt, doubled at each additional
#'           attempt (exponential backoff). Default: `1`.
#'       }
#'     }
#'   }
#' @param verbose `logical`. If `TRUE` (default), displays a confirmation
#'   message (or a warning for unknown names).
#'
#' @return Invisibly returns the updated internal environment.
#'
#' @examples
#' # Complete reset of the CheckrefR environment
#' checkrefr_env_reset()
#'
#' # Targeted reset of some OpenAlex parameters
#' checkrefr_env_reset(fields = c("oa_min_threshold", "oa_w_title"))
#'
#' # Silent reset (no console message)
#' checkrefr_env_reset(fields = "timeout", verbose = FALSE)
#'
#' # An unknown variable name is ignored with a warning
#' checkrefr_env_reset(fields = c("timeout", "variable_inexistante"))
#'
#' @seealso [checkrefr_env_status()] to view the currently
#'   configured values, [checkrefr_set_defaults()] to modify these default
#'   values, [grobid_check_requirements()].
#'
#' @importFrom cli cli_alert_success cli_alert_warning cli_abort
#' @export
checkrefr_env_reset <- function(fields = NULL, verbose = TRUE) {

  # -- Default case: complete reset (current behavior) -- #
  if (is.null(fields)) {
    .checkrefr_init_env()
    if (verbose) {
      cli::cli_alert_success("Checkrefr environment fully reset.")
    }
    return(invisible(.checkrefr_env))
  }

  # -- Case of a partial reset ------------------------------ #
  if (!is.character(fields)) {
    if (verbose) {
    cli::cli_abort(
      "{.arg fields} must be a vector of type {.cls character} or {.code NULL}."
    )
    }
  }

  valid_fields   <- ls(envir = .checkrefr_env)
  unknown_fields <- setdiff(fields, valid_fields)

  if (length(unknown_fields) > 0) {
    if (verbose) {
    cli::cli_alert_warning(
      "Unknown parameter(s), ignored: {.val {unknown_fields}}"
    )
    }
  }

  known_fields <- intersect(fields, valid_fields)

  for (nm in known_fields) {
    assign(nm, .checkrefr_defaults[[nm]], envir = .checkrefr_env)
  }

  if (verbose && length(known_fields) > 0) {
    if (verbose) {
    cli::cli_alert_success(
      "Parameter(s) reset: {.val {known_fields}}"
    )
    }
  }

  invisible(.checkrefr_env)
}



#' @title Display the status of the internal checkrefr environment
#' @description Displays in the console a formatted summary of the current
#'   state of the internal package environment (\code{.checkrefr_env}). It is
#'   possible to restrict the display to one or more specific variables
#'   via the \code{var} argument.
#' @param var A vector of type \code{character} containing the name(s)
#'   of the internal variables to display. Default: \code{NULL} (all
#'   variables of the internal environment are displayed).
#'   The available variables are:
#'   \describe{
#'     \item{\code{mode}}{Active GROBID connection mode: \code{"docker"},
#'       \code{"remote"} or \code{NA} if not configured.}
#'     \item{\code{docker_port}}{Local port used by the GROBID Docker
#'       container (character string, e.g. \code{"8070"}).}
#'     \item{\code{docker_container_id}}{Identifier of the currently active
#'       GROBID Docker container, or \code{NA} if none.}
#'     \item{\code{docker_image}}{Name of the default GROBID Docker image
#'       used (e.g. \code{"lfoppiano/grobid:"}).}
#'     \item{\code{grobid_version}}{GROBID version used or detected
#'       (e.g. \code{"0.9.0"}).}
#'     \item{\code{grobid_model_type}}{Variant of the GROBID model
#'       (\code{"crf"}, \code{"full"} or \code{NA} if not specified).}
#'     \item{\code{server_url}}{URL of the currently configured GROBID
#'       server (local or remote).}
#'     \item{\code{remote_default_url}}{Named list (\code{crf}/\code{full})
#'       of default remote GROBID server URLs.}
#'     \item{\code{timeout}}{Maximum timeout (in seconds) for
#'       GROBID network/API calls.}
#'     \item{\code{max_workers}}{Maximum number of parallel processes
#'       used when processing multiple files.}
#'     \item{\code{oa_probable_threshold}}{Global score threshold above
#'       which an OpenAlex candidate is considered "probable".}
#'     \item{\code{oa_min_threshold}}{Minimal global score threshold required
#'       to retain an OpenAlex candidate.}
#'     \item{\code{oa_doi_threshold}}{Title score threshold from which
#'       a match via DOI is considered confirmed.}
#'     \item{\code{oa_w_title}}{Weight of the title score in the
#'       global OpenAlex matching score.}
#'     \item{\code{oa_w_authors}}{Weight of the authors score in the
#'       global OpenAlex matching score.}
#'     \item{\code{oa_w_year}}{Weight of the year score in the global
#'       OpenAlex matching score.}
#'     \item{\code{oa_max_candidates}}{Maximum number of OpenAlex candidates
#'       presented per reference.}
#'     \item{\code{oa_api_key}}{Key used for the OpenAlex API
#'       "polite pool".}
#'     \item{\code{oa_use_window}}{Boolean indicating whether a sliding
#'       window is used for author matching.}
#'     \item{\code{oa_window_size}}{Size (\eqn{\pm k}) of the sliding
#'       window used for author matching.}
#'     \item{\code{oa_large_author_threshold}}{Threshold above which an
#'       author list is considered "large".}
#'     \item{\code{oa_min_coverage_ratio}}{Minimal coverage ratio between
#'       author lists to distinguish marginal from massive truncation.}
#'     \item{\code{oa_author_lambda}}{Penalty factor applied in
#'       case of truncation of the author list.}
#'     \item{\code{oa_sym_max_diff_abs}}{Absolute tolerance for the length
#'       difference between author lists for the symmetric case.}
#'     \item{\code{oa_sym_max_diff_prop}}{Proportional tolerance for the
#'       length difference between author lists for the symmetric
#'       case.}
#'     \item{\code{doi_email}}{Email address used in the
#'       \code{User-Agent} header when making direct requests to \code{doi.org}.}
#'     \item{\code{doi_max_retries}}{Maximum number of attempts in case
#'       of network error or 5xx response for DOI requests.}
#'     \item{\code{doi_retry_backoff}}{Initial delay (in seconds) before
#'       a new attempt, doubled at each successive failure.}
#'   }
#' @return A named list (invisible) containing the values of the
#'   requested variables (or all internal variables if \code{var = NULL}).
#'   This function is mainly called for its side effect of
#'   displaying to the console.
#' @examples
#' \dontrun{
#' # Display the entire state of the environment
#' checkrefr_env_status()
#'
#' # Display only certain variables
#' checkrefr_env_status(var = c("mode", "docker_port", "server_url"))
#' }
#' @seealso \code{\link{checkrefr_env_reset}}, \code{\link{checkrefr_set_defaults}}
#' @importFrom cli cli_abort cli_h1 cli_h3
#' @export
checkrefr_env_status <- function(var = NULL) {

  all_vars <- ls(.checkrefr_env)

  # -- Resolution of requested variables
  if (!is.null(var)) {
    if (!is.character(var)) {
      cli::cli_abort(
        "{.arg var} must be a vector of type {.cls character} or {.code NULL}."
      )
    }

    unknown <- setdiff(var, all_vars)
    if (length(unknown) > 0L) {
      cli::cli_abort(c(
        "Unknown variable(s): {.val {unknown}}",
        "i" = "Available variables: {.val {all_vars}}"
      ))
    }

    vars_to_show <- var
  } else {
    vars_to_show <- all_vars
  }

  out <- setNames(
    lapply(vars_to_show, function(nm) get(nm, envir = .checkrefr_env)),
    vars_to_show
  )

  # -- Generic CLI display
  cli::cli_h1("Checkrefr environment status")

  for (nm in vars_to_show) {
    val <- out[[nm]]
    .checkrefr_print_named_value(nm, val)
  }

  invisible(out)
}

#' Retrieve the package version resiliently
#'
#' @description Attempts to retrieve the installed package version via
#'   utils::packageVersion(). In case of failure (package not installed, loaded
#'   via devtools::load_all(), etc.), returns a fallback value configured
#'   in .checkrefr_defaults$pkg_version_fallback.
#'
#' @return character(1). The package version, or the fallback value.
#'
#' @importFrom utils packageVersion
#' @noRd
.checkrefr_pkg_version <- function() {                                    # >> NEW
  tryCatch(
    as.character(utils::packageVersion(.checkrefr_env$pkg_name)),
    error = function(e) "unknown"
  )
}

# Generic helper for formatting/displaying a state value
# Handles: NULL, scalar NA, simple scalar, vector (named or not),
# list (named or not, including nested)

.checkrefr_print_named_value <- function(label, val, indent = 0L) {

  # cli peut supprimer les espaces de début de ligne dans cli_text(),
  # on utilise donc cli::style_no_wrap ou cat_line pour préserver le préfixe.
  prefix <- strrep("  ", indent)

  # -- NULL case
  if (is.null(val)) {
    line <- cli::format_inline("{prefix}{.field {label}}: {.val NULL}")
    cli::cli_verbatim(line)
    return(invisible(NULL))
  }

  # -- List case (named or not, potentially nested)
  if (is.list(val)) {
    if (length(val) == 0L) {
      line <- cli::format_inline("{prefix}{.field {label}}: (empty list)")
      cli::cli_verbatim(line)
      return(invisible(NULL))
    }

    line <- cli::format_inline("{prefix}{.field {label}}:")
    cli::cli_verbatim(line)

    nms <- names(val)
    has_names <- !is.null(nms) && any(nzchar(nms))

    for (i in seq_along(val)) {
      sub_label <- if (has_names && nzchar(nms[i])) nms[i] else paste0("[[", i, "]]")
      item  <- val[[i]]
      .checkrefr_print_named_value(sub_label, item, indent = indent + 1L)
    }
    return(invisible(NULL))
  }

  # -- Atomic vector case (length 1 or more, named or not)
  formatted <- .checkrefr_format_atomic(val)
  line <- cli::format_inline("{prefix}{.field {label}}: {formatted}")
  cli::cli_verbatim(line)
  invisible(NULL)
}


# Formats an atomic vector (scalar or multi-value, named or not)
# into a readable string for cli display

.checkrefr_format_atomic <- function(x) {

  if (length(x) == 0L) return(cli::col_silver("(empty)"))

  nms <- names(x)
  has_names <- !is.null(nms) && any(nzchar(nms))

  format_one <- function(v, nm = NULL) {
    txt <- if (is.na(v)) {
      cli::col_silver("NA")
    } else if (is.logical(v)) {
      .checkrefr_status_icon(v)
    } else {
      as.character(v)
    }
    if (!is.null(nm) && nzchar(nm)) paste0(nm, " = ", txt) else txt
  }

  if (length(x) == 1L) {
    return(format_one(x[[1]], if (has_names) nms[1] else NULL))
  }

  pieces <- vapply(
    seq_along(x),
    function(i) format_one(x[[i]], if (has_names) nms[i] else NULL),
    character(1)
  )

  paste(pieces, collapse = ", ")
}


#' Modify the default values of the CheckrefR environment

#'
#' @description
#' Modifies one or more internal variables of the CheckrefR environment
#' (`.checkrefr_env`), used as default values by other
#' functions of the package (Docker connection, remote connection, OpenAlex
#' matching parameters, DOI parameters, etc.).
#'
#' @param ... Named arguments corresponding to the variables to modify.
#'   Available variables, grouped by category:
#'   \describe{
#'     \item{Connection / Docker}{
#'       \itemize{
#'         \item `docker_port` (`character`) — Local port used for the
#'           GROBID Docker container. Default: `"8070"`.
#'         \item `docker_image` (`character`) — Base name of the GROBID
#'           Docker image (before adding the version tag). Default:
#'           `"lfoppiano/grobid:"`.
#'         \item `grobid_version` (`character`) — GROBID version to
#'           use for the Docker tag. Default: `"0.9.0"`.
#'         \item `grobid_model_type` (`character` or `NA`) — Variant of
#'           the GROBID model (`"crf"` or `"full"`). An empty string, `NULL`
#'           or `NA` are normalized to `NA_character_`. Default: `NA`.
#'       }
#'     }
#'     \item{Remote connection}{
#'       \itemize{
#'         \item `remote_default_url` (`list`) — Structure nested by
#'           model type. Must be a named list with at most two
#'           keys `"crf"` and `"full"`, each associated with a
#'           `character` vector of URLs, or a `list` named by rank to
#'           control the trial priority. Entries not mentioned
#'           (`crf` or `full`) remain unchanged. Examples:
#'           \itemize{
#'             \item `list(crf = c("https://mon-serveur-crf.example.com"))`
#'             \item `list(full = list("1" = "https://mon-serveur-full.example.com"))`
#'           }
#'         \item `timeout` (`integer`) — Default timeout (in seconds)
#'           for HTTP requests to the GROBID API. Default: `120L`.
#'       }
#'     }
#'     \item{Batch processing}{
#'       \itemize{
#'         \item `max_workers` (`integer`) — Number of workers used in
#'           parallel mode by [grobid_process_files()]. Default: `4L`.
#'       }
#'     }
#'     \item{OpenAlex matching — thresholds}{
#'       \itemize{
#'         \item `oa_probable_threshold` (`numeric`) — Global score
#'           threshold above which a candidate is considered as
#'           "probable". Default: `0.85`.
#'         \item `oa_min_threshold` (`numeric`) — Minimal threshold
#'           for including a candidate. Default: `0.60`.
#'         \item `oa_doi_threshold` (`numeric`) — Acceptance threshold for
#'           article matching via DOI. Default: `0.90`.
#'       }
#'     }
#'     \item{OpenAlex matching — weighting}{
#'       \itemize{
#'         \item `oa_w_title` (`numeric`) — Weight of the title in the
#'           global score. Default: `0.60`.
#'         \item `oa_w_authors` (`numeric`) — Weight of the authors in the
#'           global score. Default: `0.30`.
#'         \item `oa_w_year` (`numeric`) — Weight of the year in the
#'           global score. Default: `0.10`.
#'       }
#'     }
#'     \item{OpenAlex queries}{
#'       \itemize{
#'         \item `oa_max_candidates` (`integer`) — Maximum number of
#'           candidates presented per reference. Default: `3L`.
#'         \item `oa_api_key` (`character` or `NA`) — API key used for the
#'           OpenAlex "polite pool". Default: `NA`.
#'       }
#'     }
#'     \item{OpenAlex matching — author analysis}{
#'       \itemize{
#'         \item `oa_use_window` (`logical`) — Enables a sliding window
#'           for author list analysis. Default: `FALSE`.
#'         \item `oa_window_size` (`numeric`) — Size of the sliding
#'           window (±k). Default: `2`.
#'         \item `oa_large_author_threshold` (`numeric`) — Threshold from
#'           which an author list is considered "large".
#'           Default: `10`.
#'         \item `oa_min_coverage_ratio` (`numeric`) — Threshold distinguishing
#'           marginal truncation from massive truncation of the author
#'           list. Default: `0.65`.
#'         \item `oa_author_lambda` (`numeric`) — Penalty factor
#'           applied in case of truncation of the author list. Default:
#'           `0.4`.
#'         \item `oa_sym_max_diff_abs` (`numeric`) — Absolute tolerance
#'           applied in the symmetric case (similar number of authors).
#'           Default: `2`.
#'         \item `oa_sym_max_diff_prop` (`numeric`) — Proportional
#'           tolerance applied in the symmetric case. Default:
#'           `0.10`.
#'       }
#'     }
#'     \item{DOI validation}{
#'       \itemize{
#'         \item `doi_email` (`character` or `NA`) — Email used for the
#'           polite User-Agent when querying Crossref / doi.org.
#'           Default: `NA`.
#'         \item `doi_max_retries` (`integer`) — Maximum number of
#'           attempts in case of network error or 5xx response for
#'           requests to doi.org. Default: `3L`.
#'         \item `doi_retry_backoff` (`numeric`) — Initial delay (in
#'           seconds) before a new attempt, doubled at each additional
#'           attempt (exponential backoff). Default: `1`.
#'       }
#'     }
#'   }
#'
#' @return Invisibly returns the updated internal environment
#'   (`.checkrefr_env`, an `environment` object).
#'
#' @examples
#' # Modify the default GROBID version used
#' checkrefr_set_defaults(grobid_version = "0.8.1")
#'
#' # Modify several variables simultaneously
#' checkrefr_set_defaults(timeout = 60L, max_workers = 2L)
#'
#' # Adjust the OpenAlex matching thresholds and weights
#' checkrefr_set_defaults(
#'   oa_min_threshold = 0.55,
#'   oa_w_title       = 0.70,
#'   oa_w_authors     = 0.20,
#'   oa_w_year        = 0.10
#' )
#'
#' # Add a priority remote URL for "full" mode
#' checkrefr_set_defaults(
#'   remote_default_url = list(full = list("1" = "https://mon-serveur.example.com"))
#' )
#'
#' # Set an email for OpenAlex and Crossref polite requests
#' checkrefr_set_defaults(oa_api_key = "xxxXXxxyzZ", doi_email = "moi@example.com")
#'
#' @seealso [checkrefr_env_status()] to view the currently
#'   configured values, [checkrefr_env_reset()] to reset these default
#'   values, [grobid_check_requirements()] and
#'   [oa_matching_info()] (OpenAlex matching parameters).
#'
#' @importFrom cli cli_abort cli_alert_info cli_alert_success
#' @export
checkrefr_set_defaults <- function(...) {
  args <- list(...)

  if (length(args) == 0L) {
    cli::cli_alert_info("No value provided. Use {.fn checkrefr_env_status} to see the current status.")
    return(invisible(.checkrefr_env))
  }

  allowed <- names(.checkrefr_defaults)

  protected <- c("docker_container_id", "mode","server_url",
                 "pkg_name", "pkg_repo")
  allowed_user <- setdiff(allowed, protected)

  unknown <- setdiff(names(args), allowed_user)
  if (length(unknown) > 0L) {
    cli::cli_abort(
      c(
        "Unknown or non-modifiable variable(s): {.val {unknown}}",
        "i" = "Allowed variables: {.val {allowed_user}}"
      )
    )
  }

  for (nm in names(args)) {
    val <- args[[nm]]
    default_val <- .checkrefr_defaults[[nm]]

    # -- Specific case: grobid_model_type -------------------------------
    if (nm == "grobid_model_type") {                                # >> NEW
      args[[nm]] <- .checkrefr_normalize_model_type(val)             # >> NEW - accepts NULL/""/NA/"crf"/"full"
      next
    }

    # -- Specific case for the nested structure remote_default_url ---
    if (nm == "remote_default_url") {

      if (!is.list(val) || is.null(names(val)) ||
          !all(names(val) %in% c("crf", "full"))) {
        cli::cli_abort(c(
          "{.arg remote_default_url} must be a named {.cls list} with",
          "only the keys {.val crf} and/or {.val full}.",
          "i" = "Example: {.code list(crf = c('https://...'))}"
        ))
      }

      current_list <- .checkrefr_env$remote_default_url   # existing crf/full list

      for (type_key in names(val)) {

        new_input <- val[[type_key]]

        if (!is.character(new_input) && !is.list(new_input)) {
          cli::cli_abort(
            "{.arg remote_default_url${type_key}} must be a character vector or a named list."
          )
        }

        existing_urls <- current_list[[type_key]]
        if (is.null(existing_urls)) existing_urls <- character(0)

        # -- Case of a rank-named list (explicit priority) ---------------
        if (is.list(new_input)) {
          ranks <- as.numeric(names(new_input))
          if (any(is.na(ranks))) {
            cli::cli_abort("To modify ranks, the list must be named with numbers.")
          }

          order_idx <- order(ranks)
          ranks     <- ranks[order_idx]
          new_input <- new_input[order_idx]

          for (i in seq_along(new_input)) {
            rank <- ranks[i]
            url  <- .checkrefr_normalize_url(new_input[[i]])

            existing_urls <- existing_urls[existing_urls != url]

            if (rank <= 1) {
              existing_urls <- c(url, existing_urls)
            } else if (rank > length(existing_urls)) {
              existing_urls <- c(existing_urls, url)
            } else {
              existing_urls <- append(existing_urls, url, after = rank - 1)
            }
          }

        } else {
          # -- Simple vector case: append at the end of the list --------------------
          new_urls <- vapply(new_input, .checkrefr_normalize_url, character(1))
          new_urls <- setdiff(new_urls, existing_urls)
          existing_urls <- c(existing_urls, new_urls)
        }

        current_list[[type_key]] <- existing_urls
      }

      args[["remote_default_url"]] <- current_list
      next
    }

    # -- Generic validation based on the type of the default value --
    if (is.numeric(default_val) && !is.numeric(val)) {
      cli::cli_abort("The variable {.arg {nm}} must be numeric.")
    }
    if (is.logical(default_val) && !is.logical(val)) {
      cli::cli_abort("The variable {.arg {nm}} must be a boolean (logical).")
    }
    if (is.character(default_val) &&
        !is.character(val) && !is.na(val)) {
      cli::cli_abort("The variable {.arg {nm}} must be a character string.")
    }

    if (is.integer(default_val))
      args[[nm]] <- as.integer(val)
  }

  for (nm in names(args)) {
    assign(nm, args[[nm]], envir = .checkrefr_env)
  }

  cli::cli_alert_success("Variable(s) updated: {.val {names(args)}}")
  invisible(.checkrefr_env)
}








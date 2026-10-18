#' Get OpenAlex matching parameters information
#'
#' Returns a structured summary of the current OpenAlex matching configuration
#' stored in the internal package environment. Parameters are grouped into
#' logical categories for readability and ease of inspection.
#'
#' The function reads values directly from \code{.checkrefr_env} and displays
#' them using \code{cli} formatting. It returns the full parameter list
#' invisibly, allowing programmatic use without triggering side effects.
#'
#' @return A named \code{list} with five sublists grouping the OpenAlex
#'   parameters by functional category:
#'   \describe{
#'     \item{\code{thresholds}}{Numeric score thresholds used for article
#'       matching:
#'       \code{oa_probable_threshold}, \code{oa_min_threshold},
#'       \code{oa_doi_threshold}.}
#'     \item{\code{weights}}{Numeric weights applied to each component of the
#'       global matching score:
#'       \code{oa_w_title}, \code{oa_w_authors}, \code{oa_w_year}.}
#'     \item{\code{query_controls}}{Integer and logical parameters controlling
#'       query behaviour and candidate selection:
#'       \code{oa_max_candidates},
#'       \code{oa_api_key}.}
#'     \item{\code{author_window}}{Parameters governing the sliding window
#'       strategy for author list analysis:
#'       \code{oa_use_window}, \code{oa_window_size},
#'       \code{oa_large_author_threshold}.}
#'     \item{\code{truncation}}{Parameters controlling truncation penalty and
#'       symmetry tolerance in author matching:
#'       \code{oa_min_coverage_ratio}, \code{oa_author_lambda},
#'       \code{oa_sym_max_diff_abs}, \code{oa_sym_max_diff_prop}.}
#'   }
#'
#' @seealso \code{\link{grobid_server_info}} for the equivalent function
#'   reporting GROBID server state.
#'
#' @importFrom cli cli_dl cli_h1 cli_h2
#'
#' @examples
#' # Display and capture current OpenAlex parameters
#' params <- oa_matching_info()
#'
#' # Access a specific subgroup programmatically
#' params$thresholds$oa_probable_threshold
#' params$weights
#'
#' @export
oa_matching_info <- function() {


  # 1. Read raw values from internal environment


  thresholds <- list(
    oa_probable_threshold = .checkrefr_env$oa_probable_threshold,
    oa_min_threshold      = .checkrefr_env$oa_min_threshold,
    oa_doi_threshold      = .checkrefr_env$oa_doi_threshold
  )

  weights <- list(
    oa_w_title   = .checkrefr_env$oa_w_title,
    oa_w_authors = .checkrefr_env$oa_w_authors,
    oa_w_year    = .checkrefr_env$oa_w_year
  )

  query_controls <- list(
    oa_max_candidates  = .checkrefr_env$oa_max_candidates,
    oa_api_key           = .checkrefr_env$oa_api_key
  )

  author_window <- list(
    oa_use_window             = .checkrefr_env$oa_use_window,
    oa_window_size            = .checkrefr_env$oa_window_size,
    oa_large_author_threshold = .checkrefr_env$oa_large_author_threshold
  )

  truncation <- list(
    oa_min_coverage_ratio = .checkrefr_env$oa_min_coverage_ratio,
    oa_author_lambda      = .checkrefr_env$oa_author_lambda,
    oa_sym_max_diff_abs   = .checkrefr_env$oa_sym_max_diff_abs,
    oa_sym_max_diff_prop  = .checkrefr_env$oa_sym_max_diff_prop
  )


  # 2. Assemble structured output


  info <- list(
    thresholds     = thresholds,
    weights        = weights,
    query_controls = query_controls,
    author_window  = author_window,
    truncation     = truncation
  )


  # 3. Display helpers


  .fmt_num  <- function(x) if (is.na(x)) "NA" else as.character(x)
  .fmt_bool <- function(x) if (isTRUE(x)) "TRUE" else "FALSE"
  .fmt_mail <- function(x) if (is.na(x)) "(not set)" else x


  # 4. Formatted CLI output


  cli::cli_h1("OpenAlex Matching Parameters")

  # -- Thresholds
  cli::cli_h2("Score Thresholds")
  cli::cli_dl(c(
    "Probable match (oa_probable_threshold)" =
      .fmt_num(thresholds$oa_probable_threshold),
    "Minimum inclusion (oa_min_threshold)"   =
      .fmt_num(thresholds$oa_min_threshold),
    "DOI acceptance (oa_doi_threshold)"      =
      .fmt_num(thresholds$oa_doi_threshold)
  ))

  # -- Weights
  cli::cli_h2("Scoring Weights")
  cli::cli_dl(c(
    "Title weight (oa_w_title)"     = .fmt_num(weights$oa_w_title),
    "Authors weight (oa_w_authors)" = .fmt_num(weights$oa_w_authors),
    "Year weight (oa_w_year)"       = .fmt_num(weights$oa_w_year)
  ))

  # -- Query controls
  cli::cli_h2("Query Controls")
  cli::cli_dl(c(
    "Max candidates (oa_max_candidates)" =
      .fmt_num(query_controls$oa_max_candidates),
    "API key (oa_api_key)"       =
      .fmt_mail(query_controls$oa_api_key)
  ))

  # -- Author window
  cli::cli_h2("Author Window Strategy")
  cli::cli_dl(c(
    "Use sliding window (oa_use_window)"                      =
      .fmt_bool(author_window$oa_use_window),
    "Window size (oa_window_size)"                            =
      .fmt_num(author_window$oa_window_size),
    "Large author list threshold (oa_large_author_threshold)" =
      .fmt_num(author_window$oa_large_author_threshold)
  ))

  # -- Truncation
  cli::cli_h2("Truncation Penalty & Symmetry")
  cli::cli_dl(c(
    "Min coverage ratio (oa_min_coverage_ratio)"  =
      .fmt_num(truncation$oa_min_coverage_ratio),
    "Truncation lambda (oa_author_lambda)"        =
      .fmt_num(truncation$oa_author_lambda),
    "Sym. abs. tolerance (oa_sym_max_diff_abs)"   =
      .fmt_num(truncation$oa_sym_max_diff_abs),
    "Sym. prop. tolerance (oa_sym_max_diff_prop)" =
      .fmt_num(truncation$oa_sym_max_diff_prop)
  ))

  invisible(info)
}

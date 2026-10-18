# oa_title.R
# Pipeline for validation via title

#' Clean a title string for use in an OpenAlex title search query
#'
#' Removes all punctuation characters from a title string and collapses
#' extra whitespace, producing a clean string suitable for use as a
#' \code{title.search} argument in \code{\link[.checkrefr_oa_get]}.
#'
#' @param title A character string containing the title to clean.
#'
#' @return A character string with punctuation removed and whitespace
#'   normalised.
#'
#' @noRd
.clean_title_for_query <- function(title) {
  title <- gsub("[[:punct:]]", " ", title)
  title <- gsub("\\s+", " ", title)
  title <- trimws(title)
  title
}

#' Validates a reference via its title
#'
#' Called directly if no DOI, or as a fallback after doi_mismatch.
#'
#' @param ref_row  Single row of the refs dataframe
#' @param doi_info Informative string about the DOI (NA if direct title pipeline)
#' @noRd
.validate_by_title <- function(ref_row, doi_info = NA_character_, max_candidates = .checkrefr_env$oa_max_candidates) {

  title <- ref_row$title

  if (is.na(title) || !nzchar(trimws(title))) {
    cli::cli_inform("  [TITLE] Missing title, cannot continue")
    return(list())
  }

  query_title <- .clean_title_for_query(title)
  cli::cli_inform("  [TITLE] Query: \"{substr(query_title, 1L, 70L)}\"")

  .throttle_requests(wait_sec = 0.3)

  # Layer 1 call (Network)
  raw_json <- .checkrefr_oa_get(list(filter = paste0("title.search:", query_title), per_page = 10))

  if (is.null(raw_json)) {
    cli::cli_warn("  [TITLE] OpenAlex request failed after retries")
    return(list())
  }

  # Layer 2 call (Parsing)
  oa_list <- .parse_openalex_results(raw_json)

  if (length(oa_list) == 0) {
    cli::cli_inform("  [TITLE] No OpenAlex result")
    return(list())
  }

  .rank_candidates(
    ref_row        = ref_row,
    oa_results     = oa_list,
    match_status   = "title_search",
    max_candidates = max_candidates
  )
}

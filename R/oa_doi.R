

#' Check the existence of one or more DOIs
#'
#' @description
#' Verifies whether one or more Digital Object Identifiers (DOIs) actually
#' exist, by normalizing the input string(s), validating their syntax, and
#' querying the DOI resolution service (`https://doi.org/api/handles/`).
#' DOIs with an invalid syntax are not queried over the network and
#' immediately return `NA`.
#'
#' @param doi A `character` vector of one or more DOIs. Accepted formats
#'   include raw DOIs (`"10.xxxx/yyyy"`), full URLs
#'   (`"https://doi.org/10.xxxx/yyyy"`), and `"doi:"`-prefixed strings.
#'   `NA` values are allowed and return `NA` in the result.
#' @param named A single `logical` value. If `TRUE`, the returned vector is
#'   named using the normalized DOI strings. Default is `FALSE`.
#'
#' @return A `logical` vector of the same length as `doi`, where each
#'   element is:
#'   \itemize{
#'     \item `NA` if the corresponding DOI is missing or syntactically invalid
#'       (no network call is made in this case) ;
#'     \item `TRUE` if the DOI resolves successfully (HTTP 200 and
#'       `responseCode == 1`) ;
#'     \item `FALSE` if the DOI is syntactically valid but does not resolve,
#'       or if the network request fails.
#'   }
#'   If `named = TRUE`, the vector is named using the normalized DOI values
#'   (see `.normalize_doi()`).
#'
#' @importFrom httr2 req_error req_perform req_timeout request resp_body_json resp_status
#'
#' @examples
#' \donttest{
#' # Single DOI - several input formats accepted
#' check_doi_exists("10.1126/science.169.3946.635")
#' check_doi_exists("https://doi.org/10.1126/science.169.3946.635")
#' check_doi_exists("doi:10.1126/science.169.3946.635")
#'
#' # Multiple DOIs, unnamed result
#' dois <- c(
#'   "10.1126/science.169.3946.635",
#'   "10.9999/this-doi-does-not-exist",
#'   "not_a_doi_at_all",
#'   NA
#' )
#' check_doi_exists(dois)
#'
#' # Named result
#' check_doi_exists(dois, named = TRUE)
#' }
#'
#' @seealso [validate_references()] for the full reference-validation
#'   pipeline that leverages DOI resolution among other matching strategies.
#' @export
check_doi_exists <- function(doi, named = FALSE) {

  # ---- input validation
  if (!is.character(doi)) {
    stop("`doi` must be a character string or character vector.", call. = FALSE)
  }

  if (!is.logical(named) || length(named) != 1L) {
    stop("`named` must be a single logical value (TRUE or FALSE).", call. = FALSE)
  }

  # ---- normalize once
  doi_norm <- vapply(doi, .normalize_doi, character(1))

  # ---- syntactic validity mask
  valid_mask <- !is.na(doi_norm) & vapply(doi_norm, .is_valid_doi_syntax, logical(1))

  # ---- init result
  result <- rep(NA, length(doi))

  # ---- only call .check_single_doi for syntactically valid DOIs
  if (any(valid_mask)) {
    result[valid_mask] <- vapply(doi_norm[valid_mask], .check_single_doi, logical(1))
  }

  # ---- named / unnamed output
  if (named) {
    names(result) <- doi_norm
  } else {
    names(result) <- NULL
  }

  result
}


# ---- private: check a single DOI (not exported)
# Ici, on suppose que doi_norm est déjà normalisé ET syntaxiquement valide
.check_single_doi <- function(doi_norm) {

  url <- paste0("https://doi.org/api/handles/", doi_norm)

  resp <- tryCatch(
    httr2::request(url) |>
      httr2::req_timeout(10) |>
      httr2::req_error(is_error = \(resp) FALSE) |>
      httr2::req_perform(),
    error = function(e) NULL
  )

  if (is.null(resp)) return(FALSE)

  status <- httr2::resp_status(resp)
  if (status != 200L) return(FALSE)

  body <- httr2::resp_body_json(resp)
  isTRUE(body$responseCode == 1L)
}



#' Normalize a DOI for robust comparison
#'
#' Removes common URL prefixes (https://doi.org/, http://dx.doi.org/,
#' doi:, etc.), converts to lowercase and trims whitespace.
#' Should be applied systematically before any DOI matching,
#' whether on Grobid data or OpenAlex results.
#'
#' @param doi character(1)
#' @return character(1) normalized DOI or NA_character_
#' @noRd
.normalize_doi <- function(doi) {
  if (is.na(doi) || !nzchar(trimws(doi))) return(NA_character_)
  doi <- trimws(doi)
  doi <- to_lower_unicode(doi)
  doi <- sub("^https?://(dx\\.)?doi\\.org/", "", doi, perl = TRUE)
  doi <- sub("^doi:", "", doi, perl = TRUE)
  trimws(doi)
}

#' Checks the minimal syntax of a DOI (after normalization)
#' @noRd
.is_valid_doi_syntax <- function(doi) {
  doi_norm <- .normalize_doi(doi)
  if (is.na(doi_norm)) return(FALSE)

  # [POSSIBLE ADJUSTMENT]
  # Regex based on the official DOI specification (doi.org/the-identifier)
  # The suffix accepts all non-space printable characters (except controls).
  # Source: https://www.doi.org/doi_handbook/2_Numbering.html
  grepl("^10\\.[0-9]{4,}/[[:graph:]]+$",doi_norm, perl = TRUE)
}


# Responsibility 1: Identify and prepare valid DOIs


#' Extracts indices and normalized DOIs of references with a valid DOI
#'
#' @param refs Full dataframe of references
#' @return List: idx (indices), dois_raw (originals), dois_norm (normalized)
#' @noRd
.extract_valid_dois <- function(refs) {

  has_doi <- !is.na(refs$doi) &
    nzchar(trimws(refs$doi)) &
    vapply(refs$doi, .is_valid_doi_syntax, logical(1L))

  idx <- which(has_doi)

  list(
    idx       = idx,
    dois_raw  = refs$doi[idx],
    dois_norm = vapply(refs$doi[idx], .normalize_doi, character(1L))
  )
}


# Responsibility 2: Network request + indexing of results


#' Performs batch OpenAlex queries and returns a DOI -> work index
#'
#' @param dois_norm Vector of normalized DOIs to query
#' @return List named by normalized DOI, each element is a structured work
#' @noRd
.fetch_works_by_doi_batch <- function(dois_norm) {

  if (length(dois_norm) == 0) return(list())

  # Dynamic chunking based on URL length
  base_url_len <- 120
  max_url_len  <- 3500

  chunks <- list()
  current_chunk <- character(0)
  current_len <- base_url_len

  for (doi in dois_norm) {
    doi_len <- nchar(doi) + 1
    if ((current_len + doi_len > max_url_len || length(current_chunk) >= 50) && length(current_chunk) > 0) {
      chunks[[length(chunks) + 1]] <- current_chunk
      current_chunk <- doi
      current_len <- base_url_len + doi_len
    } else {
      current_chunk <- c(current_chunk, doi)
      current_len <- current_len + doi_len
    }
  }
  if (length(current_chunk) > 0) {
    chunks[[length(chunks) + 1]] <- current_chunk
  }

  oa_index <- list()

  for (chunk_idx in seq_along(chunks)) {

    chunk_dois <- chunks[[chunk_idx]]

    cli::cli_alert_info(
      "{.strong [DOI]} Batch {chunk_idx}/{length(chunks)} ({length(chunk_dois)} DOI)"
    )
    .throttle_requests()

    filter_str <- paste0("doi:", paste0(chunk_dois, collapse = "|"))

    # Layer 1 call (Network)
    raw_json <- .checkrefr_oa_get(list(
      filter   = filter_str,
      per_page = length(chunk_dois)
    ))

    # Layer 2 call (Parsing)
    works <- .parse_openalex_results(raw_json)
    if (is.null(raw_json)) {
      cli::cli_warn("Batch DOI {chunk_idx}/{length(chunks)} failed after retries - {length(chunk_dois)} DOI(s) will be treated as not found.")
    }

    # Indexing
    for (work in works) {
      doi_key <- .normalize_doi(work$doi)
      if (!is.na(doi_key) && nzchar(doi_key)) {
        oa_index[[doi_key]] <- work
      }
    }
  }

  oa_index
}


# Responsibility 3: Distribution of results to each reference


# DOI orchestrator

#' Builds the User-Agent header for doi.org / Crossref calls
#'
#' @description Builds a standardized User-Agent string for requests
#'   sent to doi.org / Crossref, in accordance with the "polite pool"
#'   best practices (identification via email recommended). Now reuses
#'   the package's common signature (name, version, repo)
#'   to ensure consistency with .build_grobid_user_agent().
#'
#' @return character(1). The final User-Agent string.
#'
#' @noRd
.build_doi_user_agent <- function() {
  pkg_name    <- .checkrefr_env$pkg_name
  pkg_repo    <- .checkrefr_env$pkg_repo
  pkg_version <- .checkrefr_pkg_version()

  base <- sprintf("%s/%s (%s)", pkg_name, pkg_version, pkg_repo)

  email <- .checkrefr_env$doi_email
  if (!is.na(email) && nzchar(trimws(email))) {
    paste0(base, " mailto:", email)
  } else {
    base
  }
}


#' Performs a GET request to doi.org with a given Accept header, with retry
#'
#' @param doi_norm Normalized DOI (without URL prefix)
#' @param accept_header Value of the Accept header
#' @return List: list(status = <int>, body = <character|NULL>, error = <logical>)
#' @importFrom httr2 req_error req_headers req_perform req_user_agent request resp_status
#' @noRd
.doi_org_get <- function(doi_norm, accept_header) {

  url <- paste0("https://doi.org/", doi_norm)
  ua  <- .build_doi_user_agent()

  max_retries <- .checkrefr_env$doi_max_retries
  backoff     <- .checkrefr_env$doi_retry_backoff

  attempt <- 0L

  repeat {
    attempt <- attempt + 1L

    resp <- tryCatch(
      httr2::request(url) |>
        httr2::req_headers(Accept = accept_header) |>
        httr2::req_user_agent(ua) |>
        httr2::req_error(is_error = function(resp) FALSE) |>
        httr2::req_perform(),
      error = function(e) NULL
    )

    if (is.null(resp)) {
      if (attempt >= max_retries) {
        return(list(status = NA_integer_, resp = NULL, error = TRUE))
      }
      Sys.sleep(backoff * (2^(attempt - 1L)))
      next
    }

    status <- httr2::resp_status(resp)

    if (status >= 500L) {
      if (attempt >= max_retries) {
        return(list(status = status, resp = NULL, error = TRUE))
      }
      Sys.sleep(backoff * (2^(attempt - 1L)))
      next
    }

    return(list(status = status, resp = resp, error = FALSE))
  }
}

#' Parses a CSL-JSON object (returned by doi.org) into the internal structure
#'
#' Target structure identical to the one produced by .oa_tibble_to_list:
#' list(id, display_name, doi, publication_year, authorships)
#'
#' @param json_text character(1) raw JSON body
#' @return structured list, or NULL if parsing fails
#' @importFrom httr2 resp_body_json
#' @noRd
.parse_csl_json <- function(resp) {

  parsed <- tryCatch(
    httr2::resp_body_json(resp, simplifyVector = FALSE),
    error = function(e) NULL
  )

  if (is.null(parsed)) return(NULL)

  title <- parsed$title %||% NA_character_

  year <- NA_real_
  date_parts <- parsed$issued$`date-parts`
  if (!is.null(date_parts) && length(date_parts) > 0L) {
    first_date <- date_parts[[1]]
    if (length(first_date) > 0L) {
      year <- suppressWarnings(as.numeric(first_date[[1]]))
    }
  }

  authors_raw <- parsed$author
  authorships <- NA_character_
  if (!is.null(authors_raw) && length(authors_raw) > 0L) {
    authorships <- vapply(authors_raw, function(a) {
      given  <- a$given  %||% ""
      family <- a$family %||% ""
      trimws(paste(given, family))
    }, character(1L))
    authorships <- paste(authorships, collapse = "; ")
  }

  doi <- parsed$DOI %||% NA_character_

  list(
    id               = NA_character_,
    display_name     = title,
    doi              = doi,
    publication_year = year,
    authorships      = authorships
  )
}



#' Retrieves DOI metadata directly via doi.org/Crossref
#'
#' Cascade: CSL-JSON as priority, fallback to APA text if 406 (content negotiation
#' not available in JSON for this DOI). Handles retry/backoff for 5xx errors/network errors.
#'
#' @param doi_norm character(1) already normalized and syntactically valid DOI
#' @return list: list(status = <character>, work = <structured list or NULL>, doi_info = <character>)
#'   possible status values:
#'     "doi_confirmed_pending"  -> metadata obtained (JSON), to be scored by .rank_candidates
#'                                 (the final confirmed/partial/mismatch status will be determined after scoring)
#'     "doi_exists_partial_metadata" -> metadata obtained via APA fallback, to be scored
#'     "doi_does_not_exist"     -> 404
#'     "doi_no_metadata"        -> 406 on both formats
#'     "doi_unreachable"        -> persistent 5xx or persistent network error
#' @importFrom httr2 resp_body_string
#' @noRd
fetch_doi_org_metadata <- function(doi_norm) {

  # ---- Attempt 1: CSL-JSON
  res_json <- .doi_org_get(doi_norm, "application/vnd.citationstyles.csl+json")

  if (res_json$error) {
    return(list(status = "doi_unreachable", work = NULL, doi_info = "doi_org_unreachable"))
  }

  if (res_json$status == 404L) {
    return(list(status = "doi_does_not_exist", work = NULL, doi_info = "doi_org_404"))
  }

  if (res_json$status >= 200L && res_json$status < 300L) {
    work <- .parse_csl_json(res_json$resp)
    if (!is.null(work)) {
      if (is.na(work$doi) || !nzchar(work$doi)) work$doi <- doi_norm
      return(list(status = "doi_confirmed_pending", work = work, doi_info = "doi_org_csl_json"))
    }
    # parsing failed despite a 200: fallback to APA is attempted anyway
  }

  # ---- Attempt 2: APA text fallback (only if 406, or JSON parsing failed)
  if (res_json$status == 406L || res_json$status >= 200L) {

    res_apa <- .doi_org_get(doi_norm, "text/x-bibliography; style=apa")

    if (res_apa$error) {
      return(list(status = "doi_unreachable", work = NULL, doi_info = "doi_org_unreachable"))
    }

    if (res_apa$status >= 200L && res_apa$status < 300L) {
      apa_text <- tryCatch(httr2::resp_body_string(res_apa$resp), error = function(e) NULL)
      work <- .parse_apa_text(apa_text)
      if (!is.null(work)) {
        work$doi <- doi_norm
        return(list(status = "doi_exists_partial_metadata", work = work, doi_info = "doi_org_apa_text"))
      }
    }

    return(list(status = "doi_no_metadata", work = NULL, doi_info = "doi_org_no_metadata"))
  }

  # ---- Other unexpected status (e.g. unfollowed 3xx, 4xx other than 404/406)
  list(status = "doi_no_metadata", work = NULL, doi_info = sprintf("doi_org_status_%s", res_json$status))
}


#' Queries doi.org for valid DOIs missing from the OpenAlex index
#'
#' Called only on the subset not resolved by .fetch_works_by_doi_batch.
#'
#' @param dois_norm_missing Vector of normalized DOIs missing from oa_index
#' @return List named by normalized DOI, each element = output of .fetch_doi_org_metadata
#' @noRd
.fetch_missing_dois_from_doi_org <- function(dois_norm_missing) {

  if (length(dois_norm_missing) == 0L) return(list())

  cli::cli_alert_info(
    "{.strong [DOI]} {length(dois_norm_missing)} DOI not found on OpenAlex, direct doi.org request"
  )

  results <- vector("list", length(dois_norm_missing))
  names(results) <- dois_norm_missing

  for (i in seq_along(dois_norm_missing)) {
    doi_norm <- dois_norm_missing[i]
    cli::cli_alert_info(
      "{.strong [DOI]} doi.org {i}/{length(dois_norm_missing)} : {doi_norm}"
    )
    results[[doi_norm]] <- fetch_doi_org_metadata(doi_norm)
  }

  results
}


#' Distributes OpenAlex + doi.org results to each reference and scores candidates
#'
#' @param refs       Full dataframe of references
#' @param valid_dois Output of .extract_valid_dois()
#' @param oa_index   Output of .fetch_works_by_doi_batch()
#' @param doi_org_index Output of .fetch_missing_dois_from_doi_org() (may be empty)
#' @return List named by ref_n
#' @noRd
.distribute_doi_results <- function(refs, valid_dois, oa_index, doi_org_index = list(), max_candidates = max_candidates) {

  doi_threshold <- .checkrefr_env$oa_doi_threshold
  threshold_min <- .checkrefr_env$oa_min_threshold

  out <- vector("list", nrow(refs))
  names(out) <- refs$ref_n

  for (i in seq_along(valid_dois$idx)) {

    row_idx  <- valid_dois$idx[i]
    ref_row  <- refs[row_idx, ]
    doi_norm <- valid_dois$dois_norm[i]
    ref_name <- ref_row$ref_n

    oa_work  <- oa_index[[doi_norm]]
    doi_info <- NA_character_

    # ---- Case 1: found on OpenAlex (unchanged path)
    if (!is.null(oa_work)) {
      doi_info <- "openalex"

      # ---- Case 2: missing from OpenAlex, checking the doi.org result
    } else if (doi_norm %in% names(doi_org_index)) {

      doi_org_res <- doi_org_index[[doi_norm]]

      if (is.null(doi_org_res$work)) {
        status <- doi_org_res$status
        cli::cli_alert_warning(
          "{.strong [DOI]} {status} : {ref_row$doi}"
        )

        candidates <- list(list(
          match_status  = status,
          oa_id         = NA_character_,
          oa_title      = NA_character_,
          oa_doi        = NA_character_,
          oa_year       = NA_real_,
          oa_authors    = NA_character_,
          score_title   = NA_real_,
          score_authors = NA_real_,
          score_year    = NA_real_,
          score_global  = NA_real_
        ))

        out[[ref_name]] <- list(status = status, candidates = candidates)
        next
      }

      oa_work  <- doi_org_res$work
      doi_info <- doi_org_res$doi_info

      # ---- Case 3: DOI missing from both indexes (should not happen, safety net)
    } else {
      cli::cli_alert_warning(
        "{.strong [DOI]} Not processed (neither OpenAlex nor doi.org) : {ref_row$doi}"
      )
      status <- "doi_not_found"

      candidates <- list(list(
        match_status  = status,
        oa_id         = NA_character_,
        oa_title      = NA_character_,
        oa_doi        = NA_character_,
        oa_year       = NA_real_,
        oa_authors    = NA_character_,
        score_title   = NA_real_,
        score_authors = NA_real_,
        score_year    = NA_real_,
        score_global  = NA_real_
      ))

      out[[ref_name]] <- list(status = status, candidates = candidates)
      next
    }

    # ---- Common scoring (whether the source is OpenAlex or doi.org)
    candidates <- .rank_candidates(
      ref_row      = ref_row,
      oa_results   = list(oa_work),
      match_status = "doi_pending",
      doi_info     = doi_info,
      max_candidates = max_candidates
    )

    score_global <- candidates[[1]]$score_global

    if (score_global < threshold_min) {
      cli::cli_alert_warning(
        "{.strong [DOI]} Metadata mismatch : {ref_row$doi}"
      )
      status <- "doi_mismatch"
      candidates <- lapply(candidates, function(cand) { cand$match_status <- status; cand })
      out[[ref_name]] <- list(status = status, candidates = candidates)
      next
    }

    score_year  <- candidates[[1]]$score_year
    score_title <- candidates[[1]]$score_title
    status <- if (score_year == 1 && score_title >= doi_threshold) "confirmed_with_doi" else "partial_with_doi"

    candidates <- lapply(candidates, function(cand) { cand$match_status <- status; cand })

    out[[ref_name]] <- list(status = status, candidates = candidates)
  }

  out
}


#' Validates all references via DOI, with doi.org fallback for DOIs
#' not found on OpenAlex.
#' @noRd
.validate_batch_doi <- function(refs, max_candidates) {

  valid_dois <- .extract_valid_dois(refs)

  if (length(valid_dois$idx) == 0L) {
    cli::cli_alert_info("{.strong [DOI]} No valid DOI detected")
    out <- vector("list", nrow(refs))
    names(out) <- refs$ref_n
    return(out)
  }

  cli::cli_alert_success(
    "{.strong [DOI]} {length(valid_dois$idx)} valid DOI detected"
  )

  oa_index <- .fetch_works_by_doi_batch(valid_dois$dois_norm)

  missing_dois <- setdiff(valid_dois$dois_norm, names(oa_index))

  doi_org_index <- .fetch_missing_dois_from_doi_org(missing_dois)

  .distribute_doi_results(refs, valid_dois, oa_index, doi_org_index, max_candidates = max_candidates)
}

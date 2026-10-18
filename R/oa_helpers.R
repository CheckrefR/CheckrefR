# Internal utility functions for OpenAlex validation


#' Checks that the passed object is indeed a dataframe/tibble
#' @noRd
.check_references_input <- function(refs) {
  if (!is.data.frame(refs)) {
    cli::cli_abort(c(
      "{.arg refs} must be a {.cls data.frame} or {.cls tibble}.",
      "x" = "Object received: {.cls {class(refs)[1]}}"
    ))
  }
  invisible(TRUE)
}

#' Checks the presence of required columns
#' @noRd
.check_required_columns <- function(refs) {
  required <- c("raw_reference", "title", "authors", "authors_list", "doi", "year", "ref_n", "source_file")
  missing  <- setdiff(required, names(refs))
  if (length(missing) > 0) {
    cli::cli_abort(c(
      "Missing columns in {.arg refs}.",
      "x" = "Missing: {.val {missing}}"
    ))
  }
  invisible(TRUE)
}

#' Normalizes a string for text comparison
#' Lowercase, removes accents, punctuation, multiple spaces
#' @noRd
.normalize_string <- function(x) {
  if (is.na(x) || !nzchar(x)) return(NA_character_)
  x <- to_lower_unicode(x)
  x <- remove_diacritics(x)
  x <- gsub("[^a-z0-9 ]", " ", x)
  x <- gsub("\\s+", " ", x)
  x <- trimws(x)
  x
}

.throttle_requests <- function(wait_sec = 0.3) {
  Sys.sleep(wait_sec)
}

#' Extracts the full names of authors from a Grobid authors_list object
#'
#' Builds a display_name (first name + last name) to be comparable to
#' the display_name returned by OpenAlex.
#'
#' Columns used (if present):
#'   - first_name + last_name → "First Last"
#'   - last_name only         → "Last"
#'   - first_name only        → "First"
#'
#' @param authors_list_item data.frame from the Grobid authors_list column
#' @return Character vector of display_name, NA_character_ if empty
#' @noRd
.extract_grobid_displaynames <- function(authors_list_item) {

  if (is.null(authors_list_item) || !is.data.frame(authors_list_item)) {
    return(NA_character_)
  }

  has_first <- "first_name" %in% names(authors_list_item)
  has_last  <- "last_name"  %in% names(authors_list_item)

  if (!has_first && !has_last) {
    cli::cli_warn(".extract_grobid_displaynames: neither {.val first_name} nor {.val last_name} found")
    return(NA_character_)
  }

  n_rows <- nrow(authors_list_item)

  display_names <- vapply(seq_len(n_rows), function(i) {

    fn <- if (has_first) trimws(authors_list_item$first_name[[i]] %||% "") else ""
    ln <- if (has_last)  trimws(authors_list_item$last_name[[i]]  %||% "") else ""

    # Ignore explicit NA
    fn <- if (is.na(fn)) "" else fn
    ln <- if (is.na(ln)) "" else ln

    parts <- c(fn, ln)
    parts <- parts[nzchar(parts)]

    if (length(parts) == 0L) return(NA_character_)
    paste(parts, collapse = " ")

  }, character(1L))

  display_names <- display_names[!is.na(display_names) & nzchar(display_names)]

  if (length(display_names) == 0L) return(NA_character_)
  display_names
}



#' Builds the output dataframe rows for a reference
#' @param ref_row    Source row of the refs dataframe
#' @param candidates List of scored results (output of .rank_candidates)
#' @importFrom tibble tibble
#' @noRd
.build_output_rows <- function(ref_row, candidates) {

  if (is.null(candidates) || length(candidates) == 0L) {
    return(.build_no_match_row(ref_row))
  }

  rows <- lapply(candidates, function(cand) {
    tibble::tibble(
      source_file        = ref_row$source_file,
      ref_n              = ref_row$ref_n,
      input_title        = ref_row$title,
      input_doi          = ref_row$doi,
      input_year         = ref_row$year,
      input_authors      = ref_row$authors,
      # doi_info           = cand$doi_info,
      oa_id              = cand$oa_id,
      oa_title           = cand$oa_title,
      oa_doi             = cand$oa_doi,
      oa_year            = cand$oa_year,
      oa_authors         = cand$oa_authors,
      score_title        = cand$score_title,
      score_authors      = cand$score_authors,
      score_year         = cand$score_year,
      score_global       = cand$score_global,
      n_candidates       = length(candidates),
      match_status       = cand$match_status,
      raw_reference      = ref_row$raw_reference # <- NEW
    )
  })

  do.call(rbind, rows)
}


#' Output row for total absence of match
#' @importFrom tibble tibble
#' @noRd
.build_no_match_row <- function(ref_row) {
  tibble::tibble(
    source_file        = ref_row$source_file,
    ref_n              = ref_row$ref_n,
    input_title        = ref_row$title,
    input_doi          = ref_row$doi,
    input_year         = ref_row$year,
    input_authors      = ref_row$authors,
    match_status       = "no_match",
    # doi_info           = NA_character_,
    oa_id              = NA_character_,
    oa_title           = NA_character_,
    oa_doi             = NA_character_,
    oa_year            = NA_integer_,
    oa_authors         = NA_character_,
    score_title        = NA_real_,
    score_authors      = NA_real_,
    score_year         = NA_real_,
    score_global       = NA_real_,
    n_candidates       = 0L,
    raw_reference      = ref_row$raw_reference # <- NEW
  )
}


.checkrefr_oa_get <- function(query_params = list()) {

  endpoint <- "https://api.openalex.org/works"

  ua <- .build_doi_user_agent()
  api_key <- .checkrefr_env$oa_api_key
  email <- .checkrefr_env$doi_email

  params <- query_params

  if (is.null(params$select)) {
    params$select <- "id,title,display_name,doi,publication_year,authorships"
  }

  if (!is.na(api_key) && nzchar(trimws(api_key))) params$api_key <- trimws(api_key)


  if (!is.na(email) && nzchar(trimws(email)) && is.null(params$mailto)) {
    params$mailto <- trimws(email)
  }

  req <- httr2::request(endpoint) |>
    httr2::req_user_agent(ua) |>
    httr2::req_url_query(!!!params) |>
    httr2::req_timeout(.checkrefr_env$timeout %||% 30) |>
    httr2::req_error(is_error = \(resp) FALSE) |>   # we handle statuses ourselves
    httr2::req_retry(
      max_tries = 5,
      backoff = function(attempt) 2 ^ (attempt - 1),
      is_transient = function(resp) {
        status <- httr2::resp_status(resp)
        status == 429L || status >= 500L
      },
      retry_on_failure = TRUE   # >> covers timeouts / transient network errors
    )

  resp <- tryCatch(
    httr2::req_perform(req),
    error = function(e) {
      cli::cli_warn("OpenAlex Network Error: {conditionMessage(e)}")
      return(NULL)
    }
  )
  if (is.null(resp)) return(NULL)

  status <- httr2::resp_status(resp)

  if (status == 200L) {
    return(tryCatch(httr2::resp_body_json(resp, simplifyVector = FALSE),
                    error = function(e) NULL))
  }

  if (status == 400L) {
    cli::cli_warn("OpenAlex: request too long (HTTP 400). Reduce max_url_len or chunk size.")
    return(NULL)
  }


  if (status == 503L) {
    cli::cli_warn("OpenAlex: service temporarily unavailable (503).")
    return(NULL)
  }

  if (status == 429L) {
    cli::cli_warn("OpenAlex: 429 Too Many Requests despite retry attempts.")
    return(NULL)
  }

  # generic 4xx: try to retrieve the structured message
  body <- tryCatch(httr2::resp_body_json(resp, simplifyVector = FALSE), error = function(e) NULL)
  cli::cli_warn(c(
    "OpenAlex request failed [HTTP {status}]",
    "x" = body$error %||% "unknown error",
    "i" = body$message %||% ""
  ))
  NULL
}



#' Normalize a raw 'work' object received from the OpenAlex JSON
#'
#' @param item Individual 'work' element from the OpenAlex JSON
#' @return Structured R list containing id, display_name, doi, publication_year, authorships
#' @noRd
.parse_openalex_item <- function(item) {
  if (is.null(item) || !is.list(item))
    return(NULL)


  raw_authorships <- item$authorships
  if (is.null(raw_authorships))
    raw_authorships <- list()

  authors_df <- if (length(raw_authorships) > 0) {
    display_names <- vapply(raw_authorships, function(a) {
      dn <- a$author$display_name
      if (is.null(dn) || length(dn) != 1L)
        NA_character_
      else
        dn
    }, character(1))

    data.frame(display_name = display_names, stringsAsFactors = FALSE)
  } else {
    data.frame(display_name = character(0), stringsAsFactors = FALSE)
  }

  list(
    id               = if (is.null(item$id) ||
                           length(item$id) != 1L)
      NA_character_
    else
      item$id,
    display_name     = if (!is.null(item$title) &&
                           length(item$title) == 1L) {
      item$title
    } else if (!is.null(item$display_name) &&
               length(item$display_name) == 1L) {
      item$display_name
    } else {
      NA_character_
    },
    doi              = if (is.null(item$doi) ||
                           length(item$doi) != 1L)
      NA_character_
    else
      item$doi,
    publication_year = suppressWarnings(as.numeric(if (is.null(item$publication_year) ||
                                                       length(item$publication_year) != 1L)
      NA_real_
      else
        item$publication_year)),
    authorships      = list(authors_df)
  )
}



#' Parse a collection of OpenAlex JSON results
#' @noRd
.parse_openalex_results <- function(raw_json) {
  if (is.null(raw_json) || is.null(raw_json$results)) {
    return(list())
  }

  parsed_list <- lapply(raw_json$results, .parse_openalex_item)
  # Filter out any NULL elements
  Filter(Negate(is.null), parsed_list)
}

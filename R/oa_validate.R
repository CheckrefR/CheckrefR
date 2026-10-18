#' @title Validate a set of bibliographic references via OpenAlex
#'
#' @description
#' Complete pipeline for validating a set of bibliographic references
#' (for example extracted by Grobid) against OpenAlex. For each reference,
#' the function first attempts validation by DOI (batched queries to
#' OpenAlex then, if necessary, to doi.org), then completes or replaces this
#' result with a title search when the DOI is missing, invalid,
#' not found or inconsistent with the returned metadata. Each input reference
#' can result in one or more output rows, one row
#' per retained OpenAlex candidate.
#'
#' @details
#' Processing takes place in two main steps:
#'
#' \strong{Step 1 — Batch DOI validation}:
#' syntactically valid DOIs are extracted and queried in one or
#' several batched requests to OpenAlex. Valid DOIs but absent
#' from OpenAlex are then queried individually against
#' \code{doi.org} (CSL-JSON metadata or, failing that, APA
#' bibliographic text). Each reference then receives a status among:
#' \code{confirmed_with_doi}, \code{partial_with_doi}, \code{doi_mismatch},
#' \code{doi_not_found}, \code{doi_does_not_exist}, \code{doi_unreachable},
#' \code{doi_no_metadata}, or no result if the reference does not have
#' a syntactically valid DOI.
#'
#' \strong{Step 2 — Title validation},
#' applied reference by reference according to the result of step 1:
#' \itemize{
#'   \item If the DOI is \code{confirmed_with_doi}: only the candidates
#'     derived from the DOI are kept.
#'   \item If the DOI is \code{partial_with_doi}, \code{doi_mismatch},
#'     \code{doi_not_found} or \code{doi_does_not_exist}: the candidates
#'     derived from the DOI are combined with those obtained via a
#'     complementary title search.
#'   \item If no DOI result is available (no valid DOI):
#'     only the title search is performed.
#' }
#'
#' \strong{Matching score computation}: for each retained OpenAlex candidate,
#' an overall matching score (\code{score_global}) is
#' computed as a weighted combination of three components:
#' \itemize{
#'   \item a title similarity score (normalized Damerau-Levenshtein
#'     distance);
#'   \item an author similarity score, computed by
#'     \code{\link{compute_author_score}} (which itself relies on
#'     \code{\link{sim_author_pair}} for comparing each pair of
#'     names) — see the documentation of these two functions for details on
#'     the computation rules and associated parameters;
#'   \item a publication year matching score (exact,
#'     tolerance of one year, or zero beyond that).
#' }
#' The weights of this combination as well as the candidate acceptance
#' thresholds can be configured via \code{\link{checkrefr_set_defaults}} and
#' can be viewed via \code{\link{oa_matching_info}}. Only
#' candidates whose overall score exceeds the configured minimum threshold are
#' retained, up to a limit of \code{max_candidates} candidates per reference.
#'
#' @param refs \code{data.frame} or \code{tibble}. Bibliographic references
#'   to validate. Must contain the columns \code{title},
#'   \code{authors_list}, \code{doi}, \code{year}, \code{ref_n} and
#'   \code{source_file} (structure typically produced by
#'   \code{\link{parse_references}}, \code{\link{parse_citation_list}}, or by
#'   \code{\link{process_citation_file}}, \code{\link{grobid_process_file}},
#'   with the `"processReferences"` service and by \code{\link{grobid_process_files}},
#'   for each, with the `output_format = "parsed"` parameter).
#' @param verbose \code{logical}. If \code{TRUE} (default), displays the
#'   processing progress (DOI and title steps) as well as a final summary
#'   of the matching statuses obtained.
#' @param max_candidates \code{integer}. Maximum number of OpenAlex candidates
#'   presented per reference. Default value:
#'   \code{.checkrefr_env$oa_max_candidates}, (initialized to \code{3}).
#'
#' @return A \code{data.frame}/\code{tibble} containing one or more
#'   rows per input reference (one row per retained OpenAlex candidate, or
#'   a single row \code{match_status = "no_match"} if no candidate was
#'   found). Main columns: \code{source_file}, \code{ref_n},
#'   \code{input_title}, \code{input_doi}, \code{input_year},
#'   \code{input_authors}, \code{oa_id}, \code{oa_title}, \code{oa_doi},
#'   \code{oa_year}, \code{oa_authors}, \code{score_title}, \code{score_authors},
#'   \code{score_year}, \code{score_global}, \code{n_candidates} and
#'   \code{match_status}. Use \code{\link{deduplicate_references}} to
#'   keep only the best candidate per reference.
#'
#' @examples
#' \dontrun{
#' # refs must contain at least: title, authors_list, doi, year, ref_n, source_file
#' refs <- parse_references("my_file.tei.xml")
#' results <- validate_references(refs, verbose = TRUE)
#'
#' # Keep only the best candidate per reference
#' dedup_results <- deduplicate_references(results)
#' }
#'
#' @seealso \code{\link{compute_author_score}} and \code{\link{sim_author_pair}}
#'   for details on the computation of the author similarity score;
#'   \code{\link{oa_matching_info}} to view the thresholds and weights
#'   used in the computation of the overall score; \code{\link{deduplicate_references}}
#'   to keep only one candidate per reference;
#'   \code{\link{parse_references}} and \code{\link{parse_citation_list}} to
#'   produce the \code{refs} object expected as input.
#' @export
validate_references <- function(refs, verbose = TRUE, max_candidates = .checkrefr_env$oa_max_candidates) {

  .check_references_input(refs)
  .check_required_columns(refs)

  n_refs <- nrow(refs)

  # STEP 1: Batch DOI

  if (verbose) cli::cli_h2("Step 1: Batch DOI validation")

  doi_results <- .validate_batch_doi(refs, max_candidates = max_candidates)

  # STEP 2: Title pipeline

  if (verbose) cli::cli_h2("Step 2: Title validation")

  results <- vector("list", n_refs)

  for (i in seq_len(n_refs)) {

    ref_row  <- refs[i, ]
    ref_name <- as.character(ref_row$ref_n)
    doi_res  <- doi_results[[ref_name]]

    if (verbose) {
      cli::cli_alert_info(
        "[{i}/{n_refs}] ref_n={ref_name} | {substr(ref_row$title %||% 'title NA', 1L, 55L)}"
      )
    }

    # Case 1: DOI validated with candidates -> final result
    if (!is.null(doi_res) && doi_res$status == "confirmed_with_doi") {
      results[[i]] <- .build_output_rows(ref_row, doi_res$candidates)
      next
    }

    # Case 2: doi_mismatch -> title pipeline with doi_info passed
    if (!is.null(doi_res) && doi_res$status %in% c("partial_with_doi", "doi_mismatch",
                                                   "doi_not_found", "doi_does_not_exist")) {
      candidates_doi <- .build_output_rows(ref_row, doi_res$candidates)
      candidates <- .validate_by_title(ref_row, doi_info = doi_res$doi_info, max_candidates = max_candidates)
      candidates_title <- .build_output_rows(ref_row, candidates)
      results[[i]] <- rbind(candidates_doi, candidates_title)
      next
    }

    # Case 3: no DOI result (NULL) -> standard title pipeline
    candidates   <- .validate_by_title(ref_row, doi_info = NA_character_, max_candidates = max_candidates)
    results[[i]] <- .build_output_rows(ref_row, candidates)
  }

  out <- do.call(rbind, results)
  out$oa_doi <- vapply(out$oa_doi, .normalize_doi, character(1L)) |> as.vector()

  if (verbose) {
    cli::cli_alert_success(
      "Validation completed: {n_refs} references, {nrow(out)} rows produced."
    )
    .print_validation_summary(out)
  }

  return(out)
}



`%||%` <- function(a, b) if (!is.null(a) && !is.na(a)) a else b



.print_validation_summary <- function(out) {
  counts <- table(out$match_status)

  cli::cli_h3("Summary by status")

  summary_items <- setNames(
    as.character(counts),
    names(counts)
  )

  cli::cli_dl(summary_items)
}

#' @title Deduplicate validation results by keeping the best candidate per reference
#'
#' @description
#' Reduces a table of validation results (typically produced by
#' \code{\link{validate_references}}, which may contain several rows -
#' several OpenAlex candidates - per reference) to a single row per
#' reference, keeping for each group \code{(source_file, ref_n)}
#' the candidate with the highest overall score (\code{score_global}).
#'
#' @details
#' Rows are grouped by the combination of the columns
#' \code{source_file} and \code{ref_n}, which uniquely identifies each
#' original bibliographic reference (the same reference may appear
#' on several rows if several OpenAlex candidates were retained during
#' validation).
#'
#'   \strong{Score tie}: in case of a tie in the maximum overall score
#'     within the same group, the \strong{first row encountered}
#'     in the order of the input table is kept.
#'
#' The row order of the input table is preserved in the result: only
#' the rows not retained are removed.
#'
#' @param data \code{data.frame} or \code{tibble}. Validation results to
#'   deduplicate, which must contain the columns
#'   \code{source_file}, \code{ref_n} and \code{score_global} (structure
#'   typically produced by \code{\link{validate_references}}).
#' @param verbose \code{logical}. If \code{TRUE} (default), displays a
#'   summary of the matching statuses (\code{match_status}) of the deduplicated
#'   table, in the same format as displayed at the end of the execution of
#'   \code{\link{validate_references}}.
#'
#' @return An object of the same type as \code{data} (\code{data.frame} or
#'   \code{tibble}), containing a single row per unique pair
#'   \code{(source_file, ref_n)} - the one with the highest
#'   \code{score_global} within that group - and preserving the order of the
#'   rows of the input table.
#'
#' @examples
#' \dontrun{
#' refs <- parse_references("my_file.tei.xml")
#' results <- validate_references(refs, verbose = TRUE)
#'
#' # Keep only the best candidate per reference
#' unique_results <- deduplicate_references(results, verbose = TRUE)
#' }
#'
#' @seealso \code{\link{validate_references}} for producing the multi-candidate
#'   results table expected as input.
#' @export
deduplicate_references <- function(data, verbose = TRUE) {

  required_cols <- c("source_file", "ref_n", "score_global")
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    cli::cli_abort(c(
      "The following required columns are missing:",
      "x" = "{.val {missing_cols}}"
    ))
  }

  if (nrow(data) == 0L) {
    if (verbose) {
      cli::cli_alert_info("No references to deduplicate (empty table).")
    }
    return(data)
  }

  score <- data[["score_global"]]
  score[is.na(score)] <- -Inf

  group_key <- paste(data[["source_file"]], data[["ref_n"]], sep = "\u001f")
  unique_keys <- unique(group_key)

  selected_indices <- vapply(unique_keys, function(key) {
    idx <- which(group_key == key)
    idx[which.max(score[idx])]
  }, integer(1))

  selected_indices <- sort(selected_indices)
  data <- data[selected_indices, ]

  if (verbose) {
    .print_validation_summary(data)
  }

  return(data)
}

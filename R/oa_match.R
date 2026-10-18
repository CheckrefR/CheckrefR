# Scoring logic and candidate selection
# All adjustment points are flagged with [SCORING - AJUSTEMENT POSSIBLE]

#' Title similarity score

#'
#' Method: Damerau-Levenshtein on normalized titles.
#'
#' @noRd
#' @importFrom stringdist stringsim
.compute_title_score <- function(title_grobid, title_oa) {
  t1 <- .normalize_string(title_grobid)
  t2 <- .normalize_string(title_oa)
  if (is.na(t1) || is.na(t2)) return(0)
  stringdist::stringsim(t1, t2, method = "dl")
}


# OpenAlex name extraction

#' Extracts author display_names from the authorships structure
#'
#'
#' @param oa_authorships authorships column of an OpenAlex work
#' @return Character vector of display_name, NA_character_ if empty
#' @noRd
.extract_oa_displaynames <- function(oa_authorships) {

  if (is.null(oa_authorships) || length(oa_authorships) == 0L) {
    return(NA_character_)
  }

  # doi.org case — already concatenated string "Name1; Name2; ..."
  if (is.character(oa_authorships) && !is.list(oa_authorships)) {

    if (length(oa_authorships) == 1L && is.na(oa_authorships)) {
      return(NA_character_)
    }

    names_raw <- unlist(strsplit(oa_authorships, ";\\s*"))
    names_raw <- trimws(names_raw)
    names_raw <- names_raw[nzchar(names_raw)]

    if (length(names_raw) == 0L) return(NA_character_)
    return(names_raw)
  }

  # OpenAlex case (tibble/list structure) — original behavior
  tryCatch({


    if (is.data.frame(oa_authorships[[1]])) {
      auth_df <- oa_authorships[[1]]
    } else {

      auth_df <- do.call(rbind, lapply(oa_authorships, as.data.frame))
    }

    if (!"display_name" %in% names(auth_df)) {
      cli::cli_warn(".extract_oa_displaynames: {.val display_name} column missing")
      return(NA_character_)
    }

    names_raw <- auth_df$display_name
    names_raw <- names_raw[!is.na(names_raw) & nzchar(trimws(names_raw))]

    if (length(names_raw) == 0L) return(NA_character_)
    names_raw

  }, error = function(e) {
    cli::cli_warn(c(
      ".extract_oa_displaynames failed.",
      "x" = "{conditionMessage(e)}"
    ))
    NA_character_
  })
}


#' Year matching score
#'
#' Degressive score based on the gap between the two years:
#' - 1 if equal
#' - 0.5 if |delta| == 1 (useful for preprints whose year may shift)
#' - 0 if |delta| > 1
#'
#' @noRd
.compute_year_score <- function(year_grobid, year_oa) {
  if (is.na(year_grobid) || is.na(year_oa)) return(0)
  delta <- abs(as.integer(year_grobid) - as.integer(year_oa))
  if (delta == 0) return(1)
  if (delta == 1) return(0.5)
  return(0)
}



#' Normalized global score
#'
#' Formula: weighted sum of the 3 component scores.
#' Default weights: title 0.60, authors 0.30, year 0.10.
#' Weights are retrieved from the package options.
#' The score is already within (0, 1) by construction (if weights sum to 1).
#'
#' @noRd
.compute_global_score <- function(score_title, score_authors, score_year) {

  w_title   <- .checkrefr_env$oa_w_title
  w_authors <- .checkrefr_env$oa_w_authors
  w_year    <- .checkrefr_env$oa_w_year

  # [SCORING - AJUSTEMENT POSSIBLE]
  # Check that the weights sum to 1 (fails silently otherwise)
  # We normalize automatically to avoid configuration errors
  total_w <- w_title + w_authors + w_year
  if (abs(total_w - 1) > 1e-6) {
    w_title   <- w_title   / total_w
    w_authors <- w_authors / total_w
    w_year    <- w_year    / total_w
  }

  (score_title * w_title) + (score_authors * w_authors) + (score_year * w_year)
}

#' Evaluate and rank OpenAlex candidates for a reference
#'
#' Returns a list of at most `max_candidates` retained candidates,
#' sorted by decreasing score_global, filtered by minimum threshold.
#'
#' @param ref_row        Source row
#' @param oa_results     List of raw OpenAlex results
#' @param match_status   Initial status ("doi_confirmed", "doi_mismatch", "title_search")
#' @param doi_info       Informative message about the DOI
#' @noRd
.rank_candidates <- function(ref_row,
                             oa_results,
                             match_status,
                             doi_info = NA_character_,
                             max_candidates
) {

  threshold_min  <- .checkrefr_env$oa_min_threshold
  threshold_prob <- .checkrefr_env$oa_probable_threshold
  max_cand       <- max_candidates

  ln_grobid <- .extract_grobid_displaynames(ref_row$authors_list[[1]])

  # [NEW] Truncation marker detection — done once per reference, reused
  # for every candidate (the raw reference does not depend on oa)
  trunc_info <- .detect_truncation_marker(ref_row$raw_reference)

  scored <- lapply(oa_results, function(oa) {

    ln_oa <- .extract_oa_displaynames(oa$authorships)

    s_title   <- .compute_title_score(ref_row$title, oa$display_name)
    s_authors <- compute_author_score(
      ln_grobid, ln_oa,
      truncation_detected = trunc_info$detected
    )
    s_year    <- .compute_year_score(ref_row$year, oa$publication_year)
    s_global  <- .compute_global_score(s_title, s_authors, s_year)

    list(
      match_status      = match_status,
      oa_id             = oa$id,
      oa_title          = oa$display_name,
      oa_doi            = oa$doi,
      oa_year           = oa$publication_year,
      oa_authors        = paste(ln_oa, collapse = "; "),
      score_title       = s_title,
      score_authors     = s_authors,
      score_year        = s_year,
      score_global      = s_global,
      raw_reference     = ref_row$raw_reference,
      truncation_marker = trunc_info$marker   # <- NEW, exposed for user inspection
    )
  })

  if (match_status != "doi_pending"){
    scored <- Filter(function(x) x$score_global >= threshold_min, scored)
  }

  if (length(scored) == 0L) return(list())

  scored <- scored[order(sapply(scored, `[[`, "score_global"), decreasing = TRUE)]

  best <- scored[[1]]
  rest <- if (length(scored) > 1L) scored[-1] else list()

  retained <- list(best)
  for (cand in rest) {
    if (length(retained) >= max_cand) break
    if (cand$score_global >= threshold_prob) {
      retained <- c(retained, list(cand))
    }
  }

  retained
}



.normalize_author_name <- function(name) {

  x <- trimws(name)
  x <- .strip_control_format_chars(x)   # Cc + Cf, exhaustif via UCD
  x <- .recompose_nfc(x)           # recomposition canonique
  x <- to_lower_unicode(x)                             # ton mapping existant

  x <- gsub("[,;]", " ", x)

  tiret <- "[\u002D\u05BE\u1806\u2010\u2011\u2012\u2013\u2014\u2015\u2E3A\u2E3B\uFE58\uFE63\uFF0D\u2212]+"
  x <- gsub(tiret, " ", x, perl = TRUE)

  x <- gsub("(?<=\\p{L})\\.(?=\\p{L})", ". ", x, perl = TRUE)
  x <- gsub("\\.(?!\\s|$)", ". ", x, perl = TRUE)

  x <- gsub("\\s+", " ", x)
  x <- trimws(x)

  tokens <- unlist(strsplit(x, "\\s+"))
  tokens <- tokens[tokens != ""]

  is_initial         <- grepl("^\\p{L}\\.?$", tokens, perl = TRUE)
  initials           <- gsub("\\.", "", tokens[is_initial])
  non_initial_tokens <- gsub("\\.$", "", tokens[!is_initial])

  reduced <- paste(c(initials, non_initial_tokens), collapse = " ")

  list(
    full        = x,
    tokens      = tokens,
    initials    = initials,
    non_initial = non_initial_tokens,
    reduced     = reduced
  )
}


# Multiset Jaccard: |A ∩ B| / |A ∪ B|
.jaccard_multiset <- function(a, b) {
  if (length(a) == 0 && length(b) == 0) return(1)
  if (length(a) == 0 || length(b) == 0) return(0)

  # Multiset intersection
  ta <- table(a)
  tb <- table(b)
  common_keys <- intersect(names(ta), names(tb))
  inter <- sum(pmin(ta[common_keys], tb[common_keys]))

  # Multiset union = |A| + |B| - |intersection|
  union_ <- length(a) + length(b) - inter

  inter / union_
}



#' @title Compute a global similarity score between two lists of authors
#'
#' @description
#' Aggregates pairwise similarity scores (computed by
#' \code{\link{sim_author_pair}}) between lists of authors,
#' in order to produce a
#' single score representing the degree of correspondence between the two
#' author lists, presumably from the same bibliographic reference. The
#' calculation mode automatically adapts depending on whether the two lists
#' have a similar length (symmetric comparison) or very different lengths
#' (truncation, with conditional penalization).
#'
#' @details
#' The calculation proceeds through three mutually exclusive regimes:
#'
#' \strong{1. Indeterminate case}
#'
#' If \code{length(ng) <= 2} and \code{length(no) >= oa_large_author_threshold}
#' (default \code{10}), the comparison is deemed unreliable (too few
#' Grobid authors against a very long OpenAlex list) and the function
#' returns \code{0} without further calculation.
#'
#' \strong{2. Symmetric case}
#'
#' The two lists are treated as "of comparable length" if:
#' \deqn{|n_g - n_o| \le \code{oa\_sym\_max\_diff\_abs}}
#' \strong{or}
#' \deqn{\frac{\min(n_g, n_o)}{\max(n_g, n_o)} \ge 1 - \code{oa\_sym\_max\_diff\_prop}}
#' with \eqn{n_g = length(ng)}, \eqn{n_o = length(no)}, and by default
#' \code{oa_sym_max_diff_abs = 2}, \code{oa_sym_max_diff_prop = 0.10}. Note
#' that as soon as \code{n_g == n_o}, this condition is automatically true
#' (zero gap), so this case systematically covers lists of the same
#' length. The \eqn{n = \min(n_g, n_o)} first authors of each list
#' are then compared term by term with
#' \code{sim_author_pair(ng[i], no[i], same_position = TRUE)}, and the final
#' score is their arithmetic mean:
#' \deqn{score = \frac{1}{n} \sum_{i=1}^{n} sim\_author\_pair(ng_i, no_i)}
#'
#' \strong{3. Asymmetric case (truncation of one of the two lists)}
#'
#' If the lists are deemed too different in length for the symmetric
#' case, a coverage rate is calculated:
#' \deqn{coverage = \min(n_g, n_o) / \max(n_g, n_o)}
#' Two matching strategies for the \code{min(n_g, n_o)} authors of the
#' shorter list are possible:
#' \itemize{
#'   \item \code{oa_use_window = FALSE} (default): direct matching
#'     position by position, \code{sim_author_pair(..., same_position = TRUE)}.
#'   \item \code{oa_use_window = TRUE}: for each author \eqn{i} of the
#'     shorter list, the best score is retained among the authors of the
#'     longer list located within a window of
#'     \eqn{\pm} \code{oa_window_size} positions (default \code{2}) around
#'     rank \eqn{i}, using
#'     \code{sim_author_pair(..., same_position = FALSE)} (F1-type score,
#'     consistent with the lack of strict positional alignment induced by
#'     the window).
#' }
#'
#' A multiplicative penalization is then applied \strong{only
#' if coverage remains sufficient} (\code{coverage >= oa_min_coverage_ratio},
#' default \code{0.65}):
#' \deqn{\lambda_{cov} = 1 - coverage}
#' \deqn{score = mean(pairs) \times (1 - \lambda_{cov} \times \code{oa\_author\_lambda})}
#' where \code{oa_author_lambda} (default \code{0.4}) is a fixed factor that
#' modulates the intensity of the penalization related to truncation: the
#' lower the coverage (thus the higher \eqn{\lambda_{cov}}), the more the
#' average score is reduced, proportionally to \code{oa_author_lambda}.
#'
#' In case of insufficient coverage (\code{coverage < oa_min_coverage_ratio}),
#' no penalization is applied and the raw score \code{mean(pairs)} is
#' returned as is. This design choice is motivated by the
#' fact that author lists extracted from bibliographic references
#' (parameter \code{ng}) are structurally limited by citation norms
#' (truncation via "et al." beyond a few authors), while
#' lists from OpenAlex (\code{no}) tend to be exhaustive. Very low
#' coverage in the \code{n_g < n_o} case could therefore reflect
#' a bibliographic format artifact rather than genuine matching
#' uncertainty.
#'
#' @param ng Character vector. Full names of the authors
#'   (extracted by Grobid for a given reference).
#' @param no Character vector. Full names of the authors
#'   (returned by OpenAlex for the compared candidate).
#' @param truncation_detected Logical. Indicates whether an explicit
#'   truncation marker (e.g. "et al.") was detected in the raw
#'   bibliographic reference associated with \code{ng}, typically obtained
#'   via \code{.detect_truncation_marker(raw_reference)$detected}. This
#'   parameter is only taken into account in the asymmetric case where
#'   \code{ng} is the shorter list (\code{n_g < n_o}), i.e. when the
#'   Grobid-extracted author list is itself potentially truncated. If
#'   \code{TRUE} in that situation, the coverage-based penalization is
#'   bypassed entirely and the raw score \code{mean(pairs)} is returned,
#'   regardless of the coverage value: a detected marker is taken as
#'   evidence that the shortness of \code{ng} results from an editorial
#'   convention rather than from an unreliable match, making the
#'   truncation penalty unwarranted. It has no effect in the symmetric
#'   case, in the indeterminate case, or in the mirror case where
#'   \code{no} is the shorter list. Default value: \code{FALSE}.
#' @param oa_large_author_threshold Integer. Length threshold of \code{no}
#'   beyond which the indeterminate case applies when \code{ng} is very
#'   short (\code{length(ng) <= 2}). Default value:
#'   \code{.checkrefr_env$oa_large_author_threshold} (initialized to \code{10}).
#' @param oa_min_coverage_ratio Numeric between 0 and 1. Coverage
#'   threshold (\code{min(n_g,n_o)/max(n_g,n_o)}) below which the truncation
#'   penalization is \strong{not} applied (see Details for reservations
#'   about this behavior). Default value:
#'   \code{.checkrefr_env$oa_min_coverage_ratio} (initialized to \code{0.65}).
#' @param oa_use_window Logical. If \code{TRUE}, enables sliding-window
#'   matching (\code{same_position = FALSE}) instead of
#'   position-by-position matching in case of truncation. Default
#'   value: \code{.checkrefr_env$oa_use_window} (initialized to \code{FALSE}).
#' @param oa_window_size Integer. Half-width (in number of positions) of the
#'   sliding window used when \code{oa_use_window = TRUE}. Default
#'   value: \code{.checkrefr_env$oa_window_size} (initialized to \code{2}).
#' @param oa_sym_max_diff_abs Integer. Maximum absolute gap between
#'   \code{length(ng)} and \code{length(no)} below which the two lists
#'   are treated as symmetric. Default value:
#'   \code{.checkrefr_env$oa_sym_max_diff_abs} (initialized to \code{2}).
#' @param oa_sym_max_diff_prop Numeric between 0 and 1. Maximum relative
#'   length difference proportion tolerated for the symmetric case. Default
#'   value: \code{.checkrefr_env$oa_sym_max_diff_prop} (initialized to
#'   \code{0.10}).
#' @param oa_author_lambda Numeric. Fixed factor (independent of
#'   coverage) that modulates the intensity of the truncation penalization:
#'   \code{score = mean(pairs) * (1 - (1 - coverage) * oa_author_lambda)}.
#'   Default value: \code{.checkrefr_env$oa_author_lambda} (initialized
#'   to \code{0.4}).
#'
#' @return A single number (\code{numeric}) between 0 and 1 (except for
#'   rounding effects) representing the global similarity score between the
#'   two author lists:
#'   \itemize{
#'     \item \code{0} in the indeterminate case;
#'     \item the average of pairwise scores in the symmetric case or in
#'       case of insufficient coverage;
#'     \item the average of pairwise scores penalized by the factor
#'       \code{(1 - (1 - coverage) * oa_author_lambda)} in case of truncation
#'       with sufficient coverage.
#'   }
#'
#' @examples
#' # Symmetric case: lists of the same length
#' ng <- c("Jean Dupont", "Marie Curie")
#' no <- c("J. Dupont", "M. Curie")
#' compute_author_score(ng, no)
#'
#' # Slight truncation with sufficient coverage (0.67 >= 0.65) -> penalized
#' ng2 <- c("Jean Dupont", "Marie Curie", "Paul Martin")
#' no2 <- c("J. Dupont", "M. Curie")
#' compute_author_score(ng2, no2)
#'
#' # Severe truncation with insufficient coverage -> no penalization
#' ng3 <- c("Jean Dupont", "Marie Curie", "Paul Martin", "Alice Bernard")
#' no3 <- c("J. Dupont")
#' compute_author_score(ng3, no3)
#'
#' # Using the sliding-window mode for matching
#' compute_author_score(ng2, no2, oa_use_window = TRUE, oa_window_size = 1)
#'
#' @seealso \code{\link{sim_author_pair}} for the underlying pairwise
#'   similarity calculation.
#' @export
compute_author_score <- function(
    ng, no,
    truncation_detected       = FALSE,   # <- NEW: from .detect_truncation_marker()$detected
    oa_large_author_threshold = .checkrefr_env$oa_large_author_threshold,
    oa_min_coverage_ratio     = .checkrefr_env$oa_min_coverage_ratio,
    oa_use_window             = .checkrefr_env$oa_use_window,
    oa_window_size            = .checkrefr_env$oa_window_size,
    oa_sym_max_diff_abs       = .checkrefr_env$oa_sym_max_diff_abs,
    oa_sym_max_diff_prop      = .checkrefr_env$oa_sym_max_diff_prop,
    oa_author_lambda          = .checkrefr_env$oa_author_lambda
) {
  n_g <- length(ng)
  n_o <- length(no)

  # --- Indeterminate case ---
  if (n_g <= 2  && n_o >= oa_large_author_threshold) return(0)

  # --- Symmetric case (unchanged) ---
  is_symmetric <- abs(n_g - n_o) <= oa_sym_max_diff_abs ||
    (min(n_g, n_o) / max(n_g, n_o)) >= 1 - oa_sym_max_diff_prop

  if (is_symmetric) {
    n_min <- min(n_g, n_o)
    pairs <- mapply(
      function(a, b) sim_author_pair(a, b, same_position = TRUE),
      ng[seq_len(n_min)],
      no[seq_len(n_min)],
      SIMPLIFY = TRUE
    )
    return(mean(pairs))
  }

  # --- Truncation: n_o < n_g ---
  # NOTE: truncation_detected is NOT applicable here — see rationale above.
  if (n_o < n_g) {
    coverage <- n_o / n_g

    if (!oa_use_window) {
      pairs <- mapply(
        function(a, b) sim_author_pair(a, b, same_position = TRUE),
        ng[seq_len(n_o)],
        no[seq_len(n_o)],
        SIMPLIFY = TRUE
      )
    } else {
      pairs <- vapply(seq_len(n_o), function(i) {
        window_idx <- seq(max(1, i - oa_window_size), min(n_g, i + oa_window_size))
        max(vapply(window_idx, function(j) sim_author_pair(ng[j], no[i], same_position = FALSE), numeric(1)))
      }, numeric(1))
    }

    if (coverage >= oa_min_coverage_ratio) {
      lambda <- 1 - coverage
      score  <- mean(pairs) * (1 - lambda * oa_author_lambda)
    } else {
      score <- mean(pairs)
    }

    return(score)
  }

  # --- Mirror case: n_g < n_o (Grobid list truncated) ---
  if (n_g < n_o) {
    coverage <- n_g / n_o

    if (!oa_use_window) {
      pairs <- mapply(
        function(a, b) sim_author_pair(a, b, same_position = TRUE),
        ng[seq_len(n_g)],
        no[seq_len(n_g)],
        SIMPLIFY = TRUE
      )
    } else {
      pairs <- vapply(seq_len(n_g), function(i) {
        window_idx <- seq(max(1, i - oa_window_size), min(n_o, i + oa_window_size))
        max(vapply(window_idx, function(j) sim_author_pair(ng[i], no[j], same_position = FALSE), numeric(1)))
      }, numeric(1))
    }

    # [SCORING - AJUSTEMENT] Marker-based override:
    # if a truncation marker was found in the raw reference AND ng is
    # indeed the shorter list, the coverage-based penalty is bypassed
    # entirely regardless of the coverage value.
    if (isTRUE(truncation_detected)) {
      score <- mean(pairs)
    } else if (coverage >= oa_min_coverage_ratio) {
      lambda <- 1 - coverage
      score  <- mean(pairs) * (1 - lambda * oa_author_lambda)
    } else {
      score <- mean(pairs)
    }

    return(score)
  }
}




#' @title Compute a similarity score between two author names
#'
#' @description
#' Compares two author names (typically a name extracted by Grobid and a
#' name from OpenAlex) by decomposing them into two categories of tokens:
#' "full" tokens (words of the name written in full, e.g.
#' "dupont", "jean") and "initials" (tokens reduced to a single letter,
#' e.g. "j"). A similarity score between 0 and 1 is then calculated
#' according to one of the two available modes.
#'
#' @details
#' \strong{Important — no tolerance for typos}: the
#' comparison of full tokens relies on an \strong{exact string
#' match} (after normalization: lowercase,
#' removal of accents, hyphens and punctuation.
#' There is \strong{no tolerance
#' for typos or spelling variants}: "Dupont" and
#' "Dupond" are considered two completely different tokens, with no
#' partial match.
#'
#' \strong{Common step: matching of full tokens}
#'
#' The full tokens common to both names are extracted via multiset
#' intersection, i.e. an intersection that accounts for repetitions
#' internal to each name (for example if the same token appears twice
#' in \code{id1} and at least twice in \code{id2}, both
#' occurrences are counted as common). This is in no way
#' an approximate similarity: only strict equality between two
#' tokens counts as "common".
#'
#' Full tokens that have not been matched are then reduced to
#' their first letter and added to the initials already present in the name,
#' forming a set of "residual initials" for each name.
#'
#' If one of the two names contains \strong{no full token} (for
#' example a name reduced to initials only), the function returns
#' \code{0} (degenerate case), regardless of \code{same_position}.
#'
#' \strong{Mode \code{same_position = TRUE} (positional comparison)}
#'
#' Used when the two names are supposed to occupy the same rank in two
#' aligned author lists. If there is no common full token
#' (exact match), the score equals \code{0}. Otherwise:
#'
#' \deqn{score = 0.8 + 0.2 \times J(I_1, I_2)}
#'
#' where \eqn{J(I_1, I_2) = |I_1 \cap I_2| / |I_1 \cup I_2|} is the
#' multiset Jaccard index computed on the residual initials sets \eqn{I_1}
#' and \eqn{I_2}. Special case: if both names consist only of
#' full tokens that all match exactly (no residual initial
#' on either side, i.e. \eqn{I_1 = I_2 = \emptyset}), the Jaccard index
#' is conventionally set to \code{1},
#' so that the final score equals exactly \code{1.0} in this case of
#' perfect match. Outside of this special case, the resulting score
#' belongs to the interval \code{(0.8, 1]} as soon as at least one full token
#' is shared.
#'
#' \strong{Mode \code{same_position = FALSE} (free comparison, F1-type)}
#'
#' Used when no positional alignment is assumed (e.g. comparison
#' via a sliding window). We compute:
#'
#' \deqn{precision = covered / total_2, \quad recall = covered / total_1}
#'
#' where \code{covered} is the total number of tokens matched by
#' exact correspondence (common full tokens + common initials), and
#' \code{total_1}/\code{total_2} are the total numbers of tokens (full
#' + initials) of \code{id1} and \code{id2} respectively. The final score
#' is the harmonic mean (F1-score):
#'
#' \deqn{score = \frac{2 \times precision \times recall}{precision + recall}}
#'
#' If \code{precision + recall == 0}, the function returns \code{0}.
#'
#' @param id1 \code{character}. Full name of the first author to compare
#'   (for example a name extracted by Grobid), in "First Last" format.
#' @param id2 \code{character}. Full name of the second author to compare
#'   (for example a name from OpenAlex), same format as \code{id1}.
#' @param same_position \code{logical}. If \code{TRUE} (default), the two names
#'   are assumed to occupy the same position in two aligned author lists
#'   and the score is calculated according to the formula anchored on the
#'   common full tokens (\code{0.8 + 0.2 * Jaccard}). If \code{FALSE}, no
#'   positional alignment is assumed and an F1 score (precision/recall
#'   on covered tokens) is used instead.
#'
#' @return A single number (\code{numeric}) between 0 and 1 representing
#'   the degree of similarity between the two author names, based solely
#'   on exact token matches (no tolerance for typos). Returns \code{0}
#'   in degenerate cases (absence of a full token or zero
#'   precision/recall), and \code{1} in case of perfect match of the
#'   full tokens with no residual initial.
#'
#' @examples
#' # Perfect match of full tokens -> score = 1
#' sim_author_pair("Jean Dupont", "Jean Dupont", same_position = TRUE)
#'
#' # Same last name, one initial instead of the full first name
#' sim_author_pair("Jean Dupont", "J. Dupont", same_position = TRUE)
#'
#' # Typo in the name -> NO tolerance, penalized score
#' sim_author_pair("Jean Dupont", "Jean Dupond", same_position = TRUE)
#'
#' # Clearly different authors -> no common full token
#' sim_author_pair("Marie Curie", "Albert Einstein", same_position = TRUE)
#'
#' # Free comparison (no positional alignment), F1-type score
#' sim_author_pair("Jean-Baptiste Martin", "J.B. Martin", same_position = FALSE)
#'
#' @seealso \code{\link{compute_author_score}} for the aggregation of this
#'   score at the level of a complete list of authors.
#' @export
sim_author_pair <- function(id1, id2, same_position = TRUE) {

  n1 <- .normalize_author_name(id1)
  n2 <- .normalize_author_name(id2)

  # --- Internal function: common tokens (multiset) ---
  .common_tokens <- function(t1, t2) {
    tbl1 <- table(t1)
    tbl2 <- table(t2)
    common_keys <- intersect(names(tbl1), names(tbl2))
    if (length(common_keys) == 0) return(list(n_common = 0L,
                                              per_key  = integer(0),
                                              keys     = character(0)))
    per_key <- pmin(tbl1[common_keys], tbl2[common_keys])
    list(n_common = sum(per_key), per_key = per_key, keys = common_keys)
  }

  # --- Internal function: removal of common tokens (multiset) ---
  .remove_common <- function(tokens, common_keys, counts) {
    remaining <- tokens
    for (k in common_keys) {
      n_to_remove <- counts[k]
      idx <- which(remaining == k)
      remaining <- remaining[-idx[seq_len(n_to_remove)]]
    }
    remaining
  }

  # --- Block common to both branches ---

  t1 <- n1$non_initial
  t2 <- n2$non_initial

  # --- Degenerate case: one of the two authors has no non-initial token ---
  if (length(t1) == 0 || length(t2) == 0) return(0)

  # Common non-initial tokens (multiset)
  ct <- .common_tokens(t1, t2)

  # Residuals after removing common tokens
  rest1 <- .remove_common(t1, ct$keys, ct$per_key)
  rest2 <- .remove_common(t2, ct$keys, ct$per_key)

  # Residual initials: known initials + 1st letter of remaining tokens
  init1 <- c(n1$initials, substr(rest1, 1, 1))
  init2 <- c(n2$initials, substr(rest2, 1, 1))

  # Common initials (multiset)
  ct_init <- .common_tokens(init1, init2)

  if (same_position) {

    # --- Minimal condition: no non-initial token in common ---
    if (ct$n_common == 0) return(0)

    # --- Final score: 0.8 anchored on common tokens, 0.2 modulated by Jaccard on residual initials ---
    score <- 0.8 + 0.2 * .jaccard_multiset(init1, init2)
    return(score)

  } else {

    total1 <- length(t1) + length(n1$initials)
    total2 <- length(t2) + length(n2$initials)

    # --- Covered tokens: non-initial common + common initials ---
    covered <- ct$n_common + ct_init$n_common

    # --- F1 on coverage ---
    precision <- covered / total2
    recall    <- covered / total1

    if (precision + recall == 0) return(0)
    return(2 * precision * recall / (precision + recall))
  }
}


#' @title Detect a truncation marker in a raw bibliographic reference
#'
#' @description
#' Searches a raw (unparsed) bibliographic reference string for a marker
#' indicating that the author list has been truncated by editorial
#' convention (e.g. "et al."). The search proceeds in two steps:
#' first an attempt to isolate the APA-style author block (text preceding
#' a parenthesized year, e.g. "(2020)"), searched in priority because it
#' is the most reliable and unambiguous zone; if a marker is found there,
#' it is returned immediately. Otherwise (whether the APA-style year
#' pattern is absent, or present but no marker was found within the
#' author block), a fallback pass searches the full raw string using
#' the same list of markers, covering other citation styles as well as
#' cases where the marker might appear outside the isolated author block.
#'
#' @details
#' Rationale for the two-step approach: in APA-style references, the
#' pattern `Authors (Year).` is virtually unambiguous — the author block
#' is delimited on its right by the first parenthesized 4-digit year,
#' which almost never appears inside author names. Restricting the
#' first search to this block reduces the risk of false positives that
#' could arise from "et al." (or equivalent) appearing elsewhere in the
#' reference (e.g. within a title or a publisher note). However, unlike
#' a stricter variant of this function, here the absence of a marker in
#' the APA author block is **not** treated as conclusive: the function
#' always falls back to a global search on the full raw string if no
#' marker was found in the author block (or if no APA-like
#' year-parenthesis pattern was found at all), using patterns adapted to
#' other styles (MLA, Chicago, Harvard, Vancouver, IEEE, AIP, OSCOLA, and
#' French-language equivalents). This trades some risk of false positives
#' (marker matched outside the true author list) for a lower risk of
#' false negatives (missed truncation marker due to unusual formatting).
#'
#' @param raw_reference character. Raw, unparsed reference string
#'   (typically obtained via Grobid's `includeRawCitations` option).
#'
#' @return A list with three elements:
#'   \itemize{
#'     \item \code{detected}: logical, \code{TRUE} if a marker was found.
#'     \item \code{marker}: character, the matched marker text (or
#'       \code{NA_character_} if none found).
#'     \item \code{source}: character, \code{"apa_block"} if the marker
#'       was found within the isolated APA author block,
#'       \code{"fallback_global"} if found via the global fallback search
#'       (whether or not an APA-style year pattern was present),
#'       or \code{NA_character_} if not found.
#'   }
#'
#' @noRd
.detect_truncation_marker <- function(raw_reference) {

  na_result <- list(detected = FALSE, marker = NA_character_, source = NA_character_)

  if (is.null(raw_reference) || is.na(raw_reference) || !nzchar(trimws(raw_reference))) {
    return(na_result)
  }

  x <- raw_reference

  # --- Marker patterns ---
  # Ordered from most to least ambiguous is not critical here since we
  # return on first match; kept broad and case-insensitive.
  marker_patterns <- c(
    "et\\s*al\\.?",            # "et al.", "et al", "etal."
    "et\\s*coll\\.?",          # French: "et coll."
    "et\\s*autres",            # French: "et autres"
    "and\\s*others",           # "and others"
    "u\\.\\s*a\\.",            # German: "u. a." (und andere)
    "y\\s*otros",              # Spanish: "y otros"
    "e\\s*altri",              # Italian: "e altri"
    "\\bm\\.\\s*fl\\.",        # Scandinavian: "m. fl."
    "\\[?\\.\\.\\.\\]?",       # ellipsis "..." or "[...]"
    "\u2026"                  # unicode ellipsis "…"
  )
  combined_pattern <- paste(marker_patterns, collapse = "|")

  # --- Step 1: attempt APA-style author block isolation ---
  # Author block = everything before the first "(YYYY" occurrence.
  apa_match <- regexpr("\\(\\d{4}[a-z]?\\)", x, perl = TRUE)

  if (apa_match[1] != -1) {
    author_block <- substr(x, 1, apa_match[1] - 1)

    m <- regexpr(combined_pattern, author_block, ignore.case = TRUE, perl = TRUE)
    if (m[1] != -1) {
      matched_text <- regmatches(author_block, m)
      return(list(detected = TRUE, marker = matched_text, source = "apa_block"))
    }
  }

  # --- Step 2: fallback global search (non-APA styles) ---
  m <- regexpr(combined_pattern, x, ignore.case = TRUE, perl = TRUE)
  if (m[1] != -1) {
    matched_text <- regmatches(x, m)
    return(list(detected = TRUE, marker = matched_text, source = "fallback_global"))
  }

  na_result
}


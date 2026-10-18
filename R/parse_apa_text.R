#' Parse one or several references in APA 7 format
#'
#' Extracts metadata (authors, year, title, DOI) from one or several
#' bibliographic references in APA 7 format, from free text.
#'
#' @param input One of the following formats:
#'   \itemize{
#'     \item a path to a text file (character(1) ending with
#'       ".txt"), one reference per line ;
#'     \item a character vector, one reference per element ;
#'     \item a single-column data.frame or tibble, one reference per line.
#'   }
#' @param as_ref_df Logical. If `TRUE`, returns a data frame formatted specifically
#'   for use with [validate_references()]. This adds columns `ref_n`, `source_file`,
#'   and converts `authorships` into a list column `authors_list` compatible with
#'   the validation pipeline. Defaults to `FALSE`.
#' @param source_file_label Character string. Used only if `as_ref_df = TRUE`.
#'   Sets the value for the `source_file` column in the output. Defaults to `"APA_Input"`.
#'
#' @return Depending on `as_ref_df`:
#' \describe{
#'   \item{If `FALSE` (default)}{A `data.frame` with one row per reference and the columns:
#'   \describe{
#'     \item{`title`}{`character`. Title extracted from the reference, or `NA`
#'       if the splitting pattern could not be identified.}
#'     \item{`doi`}{`character`. Normalized DOI (lowercase, without URL
#'       prefix), extracted only if it appears as a
#'       `https://doi.org/...` URL at the very end of the reference ; `NA` otherwise.}
#'     \item{`publication_year`}{`numeric`. Publication year extracted from the
#'       `(YYYY)` pattern ; `NA` if absent or malformed.}
#'     \item{`authorships`}{`character`. Concatenated string of authors in the
#'       format `"Last name, First name; Last name, First name; ..."`, or `NA` if no author
#'       could be identified before the year.}
#'     \item{`authorships_list`}{`list` of `data.frame`. For each
#'       reference, a two-column data.frame (`first_name`,
#'       `last_name`), one row per detected author (empty data.frame with
#'       0 rows if no author could be extracted).}
#'   }}
#'   \item{If `TRUE`}{A `tibble` compatible with [validate_references()], containing:
#'   \describe{
#'     \item{`source_file`}{`character`. The label provided via `source_file_label`.}
#'     \item{`ref_n`}{`integer`. Sequential reference number.}
#'     \item{`title`}{`character`. Extracted title.}
#'     \item{`doi`}{`character`. Extracted DOI.}
#'     \item{`year`}{`numeric`. Extracted publication year.}
#'     \item{`authors`}{`character`. String of authors (same as `authorships` above).}
#'     \item{`authors_list`}{`list`. List of data.frames with `first_name` and `last_name` columns.}
#'   }}
#' }
#'
#' @section Limitations of the approach:
#' This function relies on an extraction by regular expressions
#' based on the expected structure of an APA 7 reference
#' (`Authors (Year). Title. Journal, ...`). It does not rely on any
#' robust grammatical parser and **assumes that references are
#' correctly and strictly formatted**:
#' \itemize{
#'   \item non-standard punctuation (missing or misplaced comma or period,
#'     extra space) may prevent the correct extraction
#'     of a field (authors, title, year) ;
#'   \item the year must appear explicitly in the form
#'     `(YYYY)` or `(YYYYa)` ; any other form (e.g. "n.d.", "in press",
#'     year range) will not be recognized and will return `NA` ;
#'   \item the title is split at the first period following the year: a
#'     title containing an abbreviation, an internal period, or preceded
#'     by an atypical author structure may be truncated or incorrectly extracted ;
#'   \item the DOI is only recognized as a `doi.org` URL placed at
#'     the very end of the string ; a DOI mentioned in another form
#'     (e.g. "DOI: 10.xxxx/...", DOI in the middle of the text) will not be detected ;
#'   \item authors are extracted via a `Last name, Initials` pattern ; non-standard
#'     formats (ambiguous compound names, initials without a period,
#'     first name-last name order) may produce incomplete or erroneous results.
#' }
#' In case of non-compliance with the expected format, the function generally
#' does not generate an explicit error: the affected fields are
#' silently set to `NA` or partially extracted. It is
#' therefore recommended to visually check the results rather than
#' assuming 100% reliable extraction, especially on heterogeneous
#' or variable-quality corpora of references.
#'
#' @examples
#' # Nominal case: well-formatted reference
#' parse_apa_text("Smith, J. (2020). Title of paper. Journal, 12(3), 45-67.
#' https://doi.org/10.1234/xyz")
#'
#' refs <- c(
#'   "Smith, J. (2020). Title one. Journal, 12(3), 45-67.",
#'   "Doe, J., & Roe, R. (2019). Title two. Journal, 5(1), 1-10."
#' )
#' parse_apa_text(refs)
#'
#' # Directly format for validation pipeline
#' parse_apa_text(refs, as_ref_df = TRUE)
#'
#' # Edge case: non-compliant format (missing year) -> partial extraction
#' parse_apa_text("Smith J Title of paper without proper APA formatting")
#'
#' @seealso [check_doi_exists()] to validate the existence of an extracted DOI,
#'   [validate_references()] for the full reference validation pipeline via
#'   OpenAlex/DOI, [format_apa_for_validation()] to convert existing results.
#'
#' @export
parse_apa_text <- function(input, as_ref_df = FALSE, source_file_label = "APA_Input") {

  refs <- .resolve_apa_input(input)

  parsed_list <- lapply(refs, .parse_apa_single, extract_doi = TRUE)

  result_df <- .build_apa_dataframe(parsed_list, authors_as_list = TRUE)

  # If user requests the validation-compatible format, apply the public formatter
  if (isTRUE(as_ref_df)) {
    return(format_apa_for_validation(result_df, source_file = source_file_label))
  }

  # Default behavior: return the standard APA parsed dataframe
  return(result_df)
}



#' Parse a single APA reference (elementary block, no format detection)
#'
#' @param apa_text character(1) a single APA reference
#' @param extract_doi logical(1) if TRUE, attempts to extract a DOI from the text
#' @return List with fields: display_name, doi, publication_year,
#'   authorships (character(1) raw, untransformed).
#' @noRd
.parse_apa_single <- function(apa_text, extract_doi = FALSE) {

  if (is.null(apa_text) || is.na(apa_text) || !nzchar(trimws(apa_text))) {
    return(list(
      id               = NA_character_,
      raw_reference    = apa_text, # <- NEW
      display_name     = NA_character_,
      doi              = NA_character_,
      publication_year = NA_real_,
      authorships      = NA_character_
    ))
  }

  txt <- trimws(apa_text)

  # ---- DOI: optional extraction, search for a doi.org URL at the end of the text
  doi <- NA_character_
  if (isTRUE(extract_doi)) {
    doi_match <- regmatches(
      txt,
      regexpr("https?://(dx\\.)?doi\\.org/10\\.[[:digit:]]+/[[:graph:]]+$", txt, perl = TRUE)
    )
    if (length(doi_match) > 0L && nzchar(doi_match)) {
      doi <- .normalize_doi(doi_match)
      # remove the DOI from the text so it doesn't pollute title parsing
      txt <- trimws(sub("https?://(dx\\.)?doi\\.org/10\\.[[:digit:]]+/[[:graph:]]+$", "", txt, perl = TRUE))
    }
  }

  # ---- year: search for the first "(YYYY)"
  year_match <- regmatches(txt, regexpr("\\((\\d{4})[a-z]?\\)", txt))
  year <- NA_real_
  if (length(year_match) > 0L && nzchar(year_match)) {
    year <- suppressWarnings(as.numeric(gsub("[^0-9]", "", year_match)))
  }

  # ---- authors: everything before "(YYYY)"
  authors_part <- sub("\\(\\d{4}[a-z]?\\).*$", "", txt)

  authors_df <- .parse_authors_block(authors_part)
  authorships <- if (nrow(authors_df) > 0L) {
    paste(paste(authors_df$last_name, authors_df$first_name, sep = ", "), collapse = "; ")
  } else {
    NA_character_
  }

  # ---- title
  # [POSSIBLE ADJUSTMENT] The precise splitting of the title is fragile, to be refined later.
  title <- NA_character_
  after_year <- sub("^.*\\(\\d{4}[a-z]?\\)\\.\\s*", "", txt)
  title_match <- regmatches(after_year, regexpr("^[^.]+\\.", after_year))
  if (length(title_match) > 0L && nzchar(title_match)) {
    title <- trimws(sub("\\.$", "", title_match))
  }

  list(
    id               = NA_character_,
    raw_reference    = apa_text,  # <- NEW
    display_name     = title,
    doi              = doi,
    publication_year = year,
    authorships      = authorships
  )
}


#' Parse an APA reference — internal pipeline usage
#'
#' Strictly equivalent to the historical implementation: no DOI
#' extraction, no format detection, returns a single list.
#'
#' @param apa_text character(1) a single APA reference
#' @return list() — unchanged historical format
#' @noRd
.parse_apa_text <- function(apa_text) {
  .parse_apa_single(apa_text, extract_doi = FALSE)
}


#' Detect and validate the input format for standalone usage
#'
#' @param input See `parse_apa_text()`
#' @return character(1) vector of references (one per element), after
#'   validation. Explicit error if the format is invalid.
#' @importFrom readr guess_encoding
#' @noRd
.resolve_apa_input <- function(input) {

  # ---- Case 1: single-column data.frame / tibble
  if (is.data.frame(input)) {
    if (ncol(input) != 1L) {
      cli::cli_abort(c(
        "{.arg input} must be a {.cls data.frame} or {.cls tibble} with a single column containing the APA references.",
        "x" = "Columns found: {.val {names(input)}}"
      ))
    }
    refs <- as.character(input[[1L]])
    if (!length(refs) || all(!nzchar(trimws(refs)))) {
      cli::cli_abort(
        "The provided {.cls data.frame} does not contain any usable reference."
      )
    }
    return(refs)
  }

  # ---- Case 2: not a character -> explicit error
  if (!is.character(input)) {
    cli::cli_abort(c(
      "{.arg input} must be: a path to a {.val .txt} file, a character vector containing one or more APA references, or a {.cls data.frame}/{.cls tibble} with a single column.",
      "x" = "Type received: {.cls {class(input)[1]}}"
    ))
  }

  # ---- Case 3: .txt file path
  if (length(input) == 1L && grepl("\\.txt$", input, ignore.case = TRUE)) {
    if (!file.exists(input)) {
      cli::cli_abort("The specified file does not exist: {.path {input}}")
    }

    # Handle empty file case BEFORE calling guess_encoding,
    # which crashes on empty files (stringi::stri_enc_isascii issue)
    if (file.info(input)$size == 0) {
      cli::cli_abort(
        "The specified file does not contain any usable reference: {.path {input}}"
      )
    }

    enc <- readr::guess_encoding(input)$encoding[1]
    if (is.na(enc)) enc <- "UTF-8"  # safety fallback

    refs <- readLines(input, warn = FALSE, encoding = enc)
    refs <- refs[nzchar(trimws(refs))]  # remove empty lines

    if (!length(refs)) {
      cli::cli_abort(
        "The specified file does not contain any usable reference: {.path {input}}"
      )
    }
    return(refs)
  }

  # ---- Case 4: character vector (one or more references)
  if (all(!nzchar(trimws(input)))) {
    cli::cli_abort("{.arg input} does not contain any usable reference (empty strings).")
  }

  input
}


#' Build the output data.frame for standalone usage
#'
#' @param parsed_list List of lists (one per reference), from
#'   `.parse_apa_single()`
#' @param authors_as_list logical(1) — if TRUE, the `authorships` column is
#'   a list (list-column) ; if FALSE, a concatenated string (default).
#' @return data.frame
#' @noRd
.build_apa_dataframe <- function(parsed_list, authors_as_list = FALSE) {

  n <- length(parsed_list)

  display_name     <- vapply(parsed_list, function(x) x$display_name %||% NA_character_, character(1))
  doi               <- vapply(parsed_list, function(x) x$doi %||% NA_character_, character(1))
  publication_year  <- vapply(parsed_list, function(x) x$publication_year %||% NA_real_, numeric(1))
  raw_references <- vapply(parsed_list, function(x) x$raw_reference %||% NA_character_, character(1))

  authorships_concat <- vapply(
    parsed_list,
    function(x) x$authorships %||% NA_character_,
    character(1)
  )

  out <- data.frame(
    raw_reference = raw_references,
    title     = display_name,
    doi               = doi,
    publication_year  = publication_year,
    authorships       = authorships_concat,
    stringsAsFactors  = FALSE
  )

  if (isTRUE(authors_as_list)) {
    out$authorships_list <- lapply(authorships_concat, function(a) {
      if (is.na(a)) {
        return(data.frame(
          first_name = character(0),
          last_name  = character(0),
          stringsAsFactors = FALSE
        ))
      }
      authors <- strsplit(a, ";\\s*")[[1]]
      first_name <- character(0)
      last_name  <- character(0)
      for (au in authors) {
        pieces <- strsplit(au, ",\\s*")[[1]]
        last_name  <- c(last_name, trimws(pieces[1]))
        first_name <- c(first_name, if (length(pieces) > 1L) trimws(pieces[2]) else NA_character_)
      }
      data.frame(first_name = first_name, last_name = last_name, stringsAsFactors = FALSE)
    })
  }

  out
}


#' Parse a raw block of APA authors into individualized authors
#'
#' @param authors_raw character(1) raw portion of the text containing the
#'   authors (before the year), potentially with standard APA punctuation.
#' @return data.frame with columns `first_name` and `last_name`, one row
#'   per individualized author. Empty data.frame (0 rows) if nothing usable.
#' @noRd
.parse_authors_block <- function(authors_raw) {
  empty_df <- data.frame(
    first_name = character(0),
    last_name  = character(0),
    stringsAsFactors = FALSE
  )

  if (is.null(authors_raw) || is.na(authors_raw) || !nzchar(trimws(authors_raw))) {
    return(empty_df)
  }

  txt <- trimws(authors_raw)

  # ---- remove "et al." (with or without period, case-insensitive)
  txt <- gsub("(,)?\\s*et al\\.?\\s*$", "", txt, ignore.case = TRUE, perl = TRUE)
  txt <- trimws(txt)
  if (!nzchar(txt)) return(empty_df)

  # ---- normalization of connectors: "&", "and" -> ","
  txt <- gsub("\\s*&\\s*", ", ", txt)
  # txt <- gsub("\\s*\\band\\b\\s*", ", ", txt, ignore.case = TRUE)

  # ---- cleanup of residual multiple commas/spaces
  txt <- gsub(",\\s*,", ",", txt)
  txt <- gsub(",\\s*$", "", txt)
  if (!nzchar(txt)) return(empty_df)

  # ---- extraction of (Last name(s), Initials) pairs
  # Last name: one or more words (handles compound names: "Van Der Berg")
  # Initials: uppercase letters, periods, dashes (e.g. "J.-M.", "R", "A.")
  pattern <- pattern <- "([\\p{L}'\\-]+(?:\\s+[\\p{L}'\\-]+)*),\\s*((?:\\p{Lu}\\.?-?)+)\\.?"

  matches <- gregexpr(pattern, txt, perl = TRUE)
  extracted <- regmatches(txt, matches)[[1]]

  if (!length(extracted)) return(empty_df)

  last_names  <- character(0)
  first_names <- character(0)

  for (m in extracted) {
    parts <- regmatches(m, regexec(pattern, m, perl = TRUE))[[1]]
    last  <- trimws(parts[2])
    first <- trimws(parts[3])
    first <- gsub("\\.$", "", first)   # remove trailing period if any
    first <- gsub("\\.", "", first)    # remove internal periods (e.g. "J.-M." -> "J-M")
    # dash is properly kept if present, without surrounding periods
    last_names  <- c(last_names, last)
    first_names <- c(first_names, first)
  }

  data.frame(
    first_name = first_names,
    last_name  = last_names,
    stringsAsFactors = FALSE
  )
}


#' Format APA results for validation pipeline
#'
#' Converts the output of [parse_apa_text()] into a data frame structure
#' compatible with [validate_references()]. It adds necessary columns
#' such as ref_n, source_file, and authors_list (parsed from the string).
#'
#' @param apa_data A data frame returned by [parse_apa_text()].
#' @param source_file Optional character string indicating the source file name.
#'   Defaults to "APA_Input".
#' @seealso [check_doi_exists()] to validate the existence of an extracted DOI,
#'   [validate_references()] for the full reference validation pipeline via
#'   OpenAlex/DOI.
#'
#' @return A tibble/data.frame with columns: title, doi, year, authors,
#'   authors_list, ref_n, source_file.
#' @export
format_apa_for_validation <- function(apa_data, source_file = "APA_Input") {

  if (!is.data.frame(apa_data) || nrow(apa_data) == 0) {
    return(tibble::tibble())
  }

  # Construct the output compatible with validate_references requirements
  out <- tibble::tibble(
    raw_reference = apa_data$raw_reference,
    source_file = source_file,
    ref_n       = seq_len(nrow(apa_data)),
    title       = apa_data$title,
    doi         = apa_data$doi,
    year        = apa_data$publication_year,
    authors     = apa_data$authorships,
    authors_list = lapply(apa_data$authorships, .parse_authors_string_to_list)
  )

  return(out)
}

# Helper to parse "Last, First; Last2, First2" into a list of data.frames
.parse_authors_string_to_list <- function(auth_str) {
  if (is.na(auth_str) || !nzchar(trimws(auth_str))) {
    return(data.frame(first_name = character(0), last_name = character(0), stringsAsFactors = FALSE))
  }

  # Split by semicolon
  authors_vec <- strsplit(auth_str, ";\\s*")[[1]]

  first_names <- character(0)
  last_names <- character(0)

  for (au in authors_vec) {
    parts <- strsplit(trimws(au), ",\\s*")[[1]]
    if (length(parts) >= 2) {
      last_names <- c(last_names, trimws(parts[1]))
      first_names <- c(first_names, trimws(parts[2]))
    } else if (length(parts) == 1) {
      # Handle case where only one name is present or format is different
      last_names <- c(last_names, trimws(parts[1]))
      first_names <- c(first_names, NA_character_)
    }
  }

  data.frame(
    first_name = first_names,
    last_name = last_names,
    stringsAsFactors = FALSE
  )
}

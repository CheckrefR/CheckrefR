# parse_citations.R
# Parsing citations from TEI XML returned by processCitationList



# Parsing function


#' Parse the GROBID XML output of a citation list
#'
#' @description
#' Parses the TEI XML returned by the GROBID `processCitationList`
#' service used with [grobid_process_file()] or directly via
#' [process_citation_file()] and transforms it into a structured tibble,
#' with one row per parsed citation. Optionally allows attaching
#' the raw original citation strings to the extracted metadata.
#'
#' @param xml_content A character string containing raw
#'   TEI XML, a path to an XML file, or an
#'   `xml2::xml_document` object, as returned by [grobid_process_file()]
#'   with `service = "processCitationList"`.
#' @param raw_references An optional `character` vector containing the
#'   raw citation strings submitted to GROBID, in the same order as
#'   the `<biblStruct>` nodes of `xml_content`. If provided and its
#'   length does not match the number of parsed citations, a
#'   `warning()` is issued and `raw_reference` is set to `NA` for
#'   unmatched entries. Default `NULL`.
#'
#' @return A `tibble` with one row per parsed citation and the following
#'   columns: `ref_n` (integer, position of the citation in the entry),
#'   `raw_reference` (original citation string, or `NA`), `title`,
#'   `authors` (character, concatenated `"Last name, First name"` pairs),
#'   `authors_list` (list-column of data frames with `first_name` /
#'   `last_name`), `year` (integer), `journal`, `publisher`, `volume`,
#'   `issue`, `pages`, `doi`, `pmid`, `url`, `ref_type` (character, inferred
#'   reference type), and `parse_confidence` (numeric, from the
#'   GROBID `confidence` attribute, `NA` if absent). If no citation
#'   is found in `xml_content`, a zero-row tibble with the
#'   same schema is returned and a message is displayed.
#'
#' @importFrom xml2 xml_find_all xml_find_first xml_attr
#' @importFrom tibble tibble
#'
#' @examples
#' \dontrun{
#' # Typical usage via the high-level wrapper
#' txt_file <- system.file("extdata", package = "CheckrefR") |>
#'   list.files(pattern = "\\.txt$", full.names = TRUE) |>
#'   (\(x) x[1])()
#' citations_xml <- process_citation_file(txt_file, output_format = "raw")
#' parse_citation_list(citations_xml)
#'}
#'
#' # Direct usage on a raw TEI XML fragment
#' xml <- paste0(
#'   "<TEI xmlns='http://www.tei-c.org/ns/1.0'>",
#'   "<text><body><listBibl>",
#'   "<biblStruct confidence='0.9'>",
#'   "<analytic><title level='a'>A sample title</title></analytic>",
#'   "</biblStruct>",
#'   "</listBibl></body></text></TEI>"
#' )
#' parse_citation_list(xml)
#'
#' @seealso [process_citation_file()], [parse_references()],
#'   [parse_header()], [parse_fulltext()]
#' @export
parse_citation_list <- function(xml_content, raw_references = NULL) {
  tei_root <- .parse_tei_input(xml_content)

  # processCitationList returns a flat list of <biblStruct>
  # directly under the root or under <TEI>/<text>/<body>
  bib_nodes <- xml2::xml_find_all(
    tei_root, ".//tei:biblStruct", .tei_ns
  )

  if (length(bib_nodes) == 0L) {
    message("No citation found.")
    return(
      tibble::tibble(
        ref_n      = integer(),
        raw_reference    = character(),
        title           = character(),
        authors         = character(),
        authors_list    = list(),
        year            = integer(),
        journal         = character(),
        publisher       = character(),
        volume          = character(),
        issue           = character(),
        pages           = character(),
        doi             = character(),
        pmid            = character(),
        url             = character(),
        ref_type        = character(),
        parse_confidence= numeric()
      )
    )
  }

  # Consistency check raw_references / number of nodes
  if (!is.null(raw_references) && length(raw_references) != length(bib_nodes)) {
    warning(sprintf(
      "Number of raw citations (%d) != number of <biblStruct> (%d). raw_reference will be NA for unmatched entries.",
      length(raw_references), length(bib_nodes)
    ))
  }

  rows <- lapply(seq_along(bib_nodes), function(i) {
    node <- bib_nodes[[i]]

    raw_reference_xml <- .tei_text(
      xml2::xml_find_first(node, ".//tei:note[@type='raw_reference']", .tei_ns)
    )

    # Original raw citation
    raw_reference <- if (!is.na(raw_reference_xml)) {
      raw_reference_xml
    } else if (!is.null(raw_references) && i <= length(raw_references)) {
      raw_references[i]
    } else {
      NA_character_
    }

    # Confidence score — GROBID may set a @confidence attribute
    confidence_raw <- xml2::xml_attr(node, "confidence")
    parse_confidence <- suppressWarnings(as.numeric(confidence_raw))

    # Metadata via shared helpers
    bib      <- .parse_biblstruct(node)
    ref_type <- .parse_ref_type(node)

    url <- xml2::xml_attr(
      xml2::xml_find_first(node, ".//tei:ptr[@type='web']", .tei_ns),
      "target"
    )

    tibble::tibble(
      ref_n      = as.integer(i),
      raw_reference    = raw_reference,
      title           = bib$title,
      authors         = bib$authors_str,
      authors_list    = list(bib$authors_df),
      year            = bib$year,
      journal         = bib$journal,
      publisher       = bib$publisher,
      volume          = bib$volume,
      issue           = bib$issue,
      pages           = bib$pages,
      doi             = bib$doi,
      pmid            = bib$pmid,
      url             = if (is.na(url)) NA_character_ else url,
      ref_type        = ref_type,
      parse_confidence= parse_confidence
    )
  })

  do.call(rbind, rows)
}


# High-level function


#' Process a text file of citations via GROBID
#'
#' @description
#' Specialized function for the GROBID
#' `"processCitationList"` service. Reads a text file containing one
#' raw citation per line, then
#' returns either the raw XML/TEI, or a structured tibble.
#'
#' Unlike [grobid_process_file()] (which accepts, for the
#' `"processCitationList"` service, either a file path or a vector of
#' raw text citations), `process_citation_file()` only accepts
#' a **single path to an existing `.txt` file** on disk.
#' To directly process a vector of citations without an
#' intermediate file, use [grobid_process_file()] with
#' `service = "processCitationList"`.
#'
#' @param file `character` Path to an existing text file,
#'   containing one raw citation per line. Empty lines are
#'   ignored.
#' @param params `list` Additional parameters passed to the HTTP form
#'   of the GROBID API (e.g. `list(consolidateCitations = 1)`).
#'   See [grobid_process_file()] for details. Default: `list()`.
#' @param output_format `character` Format of the returned result:
#'   \itemize{
#'     \item `"parsed"` — structured result (`tibble`), via
#'       [parse_citation_list()]
#'     \item `"raw"` — raw XML/TEI string
#'   }
#'   Default: `"parsed"`.
#' @param model_type `character` or `NA`. GROBID model variant to
#'   use for extracting bibliographic citations. Two
#'   values are possible:
#'   \itemize{
#'     \item `"crf"` — model based solely on a CRF (Conditional
#'       Random Field). Faster, but generally less accurate than
#'       the `"full"` model.
#'     \item `"full"` — model combining CRF and a neural
#'       (deep learning) model. More accurate, but slower and more
#'       resource-intensive.
#'   }
#'   This parameter corresponds to the `model.name` /
#'   `citation` configuration of the GROBID YAML configuration
#'   file (see the official documentation for details [HERE](https://grobid.readthedocs.io/en/latest/Grobid-docker/#configure-using-the-yaml-config-file)).
#'   If `NA` (default value), in `docker` mode the model without extension is used,
#'   see the [GROBID dockerHub documentation](https://hub.docker.com/r/grobid/grobid/tags)
#'   for details or use the [grobid_docker_list_versions()] function.
#'   In `remote` mode a `crf` model is used by default.
#'   Default: `.checkrefr_env$grobid_model_type`, i.e. `NA`.
#' @param verbose `logical` If `TRUE`, displays progress
#'   messages in the console (number of citations sent, etc.).
#'   Default: `TRUE`.
#'
#' @return
#' \itemize{
#'   \item `output_format = "parsed"` → structured `tibble` with one row
#'     per citation (see [parse_citation_list()] for column details)
#'   \item `output_format = "raw"` → `character` containing the raw
#'     XML/TEI returned by GROBID
#' }
#'
#' @seealso [grobid_process_file()], [parse_citation_list()],
#'   [grobid_docker_start()], [grobid_remote_connect()],
#'   [checkrefr_set_defaults()]
#'
#' @examples
#' \dontrun{
#' # Retrieving a sample citation file provided with the package
#' txt_file <- system.file("extdata", package = "CheckrefR") |>
#'   list.files(pattern = "\\.txt$", full.names = TRUE)
#' txt_file <- txt_file[1]
#'
#' # Processing with structured return (tibble)
#' citations_df <- process_citation_file(txt_file)
#'
#' # Processing with raw XML return
#' citations_xml <- process_citation_file(txt_file, output_format = "raw")
#' }
#'
#' @export
process_citation_file <- function(file,
                                  params        = list(),
                                  output_format = "parsed",
                                  model_type    = .checkrefr_env$grobid_model_type,
                                  verbose       = TRUE) {
  output_format <- match.arg(output_format, c("parsed", "raw"))

  if (!file.exists(file)) {
    stop("File not found: ", file)
  }

  # Reading raw citations (one per line, empty lines ignored)
  raw_references <- readLines(file, warn = FALSE)
  raw_references <- raw_references[nzchar(trimws(raw_references))]

  if (length(raw_references) == 0L) {
    cli::cli_abort(c(
      "The citation file {.path {file}} is empty or contains only blank lines.",
      "x" = "Cannot process an empty citation list."
    ))
  }

  if (verbose) {
    message(sprintf("Sending %d citation(s) to GROBID...", length(raw_references)))
  }

  xml_content <- grobid_process_file(
    file    = file,
    service = "processCitationList",
    params  = params,
    output_format = "raw",
    verbose = verbose,
    model_type = model_type
  )

  if (is.na(xml_content)) {
    return(invisible(NA_character_))
  }

  if (output_format == "raw") return(xml_content)

  parse_citation_list(xml_content, raw_references = raw_references)
}

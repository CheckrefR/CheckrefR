# Extract bibliographic references from a GROBID TEI XML



#' Infer the reference type from a <biblStruct> node
#' @noRd
.parse_ref_type <- function(node) {
  # GROBID sometimes sets a type attribute on <biblStruct>
  type_attr <- xml2::xml_attr(node, "type")
  if (!is.na(type_attr)) {
    return(switch(type_attr,
                  "journal"    = "article",
                  "book"       = "book",
                  "conference" = "conference",
                  "report"     = "report",
                  "web"        = "web",
                  "unknown"
    ))
  }

  # Otherwise, infer from the structure
  has_analytic  <- !inherits(
    xml2::xml_find_first(node, "tei:analytic", .tei_ns), "xml_missing"
  )
  has_journal   <- !inherits(
    xml2::xml_find_first(node, ".//tei:monogr/tei:title[@level='j']", .tei_ns), "xml_missing"
  )
  has_book      <- !inherits(
    xml2::xml_find_first(node, ".//tei:monogr/tei:title[@level='m']", .tei_ns), "xml_missing"
  )
  has_conf      <- !inherits(
    xml2::xml_find_first(node, ".//tei:monogr/tei:title[@level='s']", .tei_ns), "xml_missing"
  )
  has_url       <- !inherits(
    xml2::xml_find_first(node, ".//tei:ptr[@type='web']", .tei_ns), "xml_missing"
  )

  if (has_analytic && has_journal)  return("article")
  if (has_conf)                     return("conference")
  if (has_book && !has_analytic)    return("book")
  if (has_book && has_analytic)     return("book_chapter")
  if (has_url)                      return("web")
  "unknown"
}


# Main function


#' Parse the GROBID XML output of bibliographic references
#'
#' @description
#' Parses the TEI XML produced by the GROBID `processReferences` service
#' and transforms it into a structured tibble, with one row per
#' bibliographic reference.
#'
#' @param xml_content An
#'   `xml2::xml_document` object, as returned by [grobid_process_file()]
#'   with `service = "processReferences"`.
#' @param source_file Name of the source file associated with the xml.
#'
#' @return A `tibble` with one row per reference and the following
#'   columns: `source_file`, `ref_id` (character, GROBID `xml:id` if
#'   present), `ref_n` (integer, sequential position), `raw_reference`
#'   (character, raw text of the reference if available), `title`,
#'   `authors` (character, concatenated `"Last name, First name"` pairs),
#'   `authors_list` (list-column of data frames with `first_name` /
#'   `last_name`), `year` (integer), `journal`, `publisher`, `volume`,
#'   `issue`, `pages`, `doi`, `pmid`, and `url`. If no reference is
#'   found in `xml_content`, a zero-row tibble with the same
#'   schema is returned and a message is displayed.
#'
#' @importFrom tibble tibble
#' @importFrom xml2 xml_attr xml_find_all xml_find_first
#'
#' @examples
#' \dontrun{
#' xml_result <- grobid_process_file("paper.pdf",
#'                                    service = "processReferences",
#'                                    output_format = "raw")
#' parse_references(xml_result)
#' }
#'
#' @seealso [grobid_process_file()], [parse_header()],
#'   [parse_citation_list()], [parse_fulltext()]
#' @export
parse_references <- function(xml_content, source_file = NULL) {
  tei_root <- .parse_tei_input(xml_content)

  ref_nodes <- xml2::xml_find_all(
    tei_root, ".//tei:listBibl/tei:biblStruct", .tei_ns
  )

  if (length(ref_nodes) == 0L) {
    message("No reference found.")
    return(
      tibble::tibble(
        source_file  = character(),
        ref_id       = character(),
        ref_n        = integer(),
        raw_reference= character(),
        title        = character(),
        authors      = character(),
        authors_list = list(),
        year         = integer(),
        journal      = character(),
        publisher    = character(),
        volume       = character(),
        issue        = character(),
        pages        = character(),
        doi          = character(),
        pmid         = character(),
        url          = character()#,
        # ref_type     = character()
      )
    )
  }

  rows <- lapply(seq_along(ref_nodes), function(i) {
    node <- ref_nodes[[i]]

    # ref_id <- xml2::xml_attr(node, "xml:id")
    ref_id <- xml2::xml_attr(node, "id")
    ref_n   <- i

    # Raw reference
    raw_reference <- .tei_text(
      xml2::xml_find_first(node, ".//tei:note[@type='raw_reference']", .tei_ns)
    )

    # Metadata via .parse_biblstruct()
    bib <- .parse_biblstruct(node)

    # URL
    url <- xml2::xml_attr(
      xml2::xml_find_first(node, ".//tei:ptr[@type='web']", .tei_ns),
      "target"
    )

    # Reference type
    # ref_type <- .parse_ref_type(node)

    tibble::tibble(
      source_file  = if (is.null(source_file)) NA_character_ else source_file,
      ref_id       = if (is.na(ref_id)) NA_character_ else ref_id,
      ref_n        = as.integer(ref_n),
      raw_reference= raw_reference,
      title        = bib$title,
      authors      = bib$authors_str,
      authors_list = list(bib$authors_df),
      year         = bib$year,
      journal      = bib$journal,
      publisher    = bib$publisher,
      volume       = bib$volume,
      issue        = bib$issue,
      pages        = bib$pages,
      doi          = bib$doi,
      pmid         = bib$pmid,
      url          = if (is.na(url)) NA_character_ else url#,
      # ref_type     = ref_type
    )
  })

  do.call(rbind, rows)
}

#' Extract an identifier by type from a TEI node
#' @noRd
.parse_idno <- function(node, type) {
  xpath <- sprintf(".//tei:idno[@type='%s']", type)
  .tei_text(xml2::xml_find_first(node, xpath, .tei_ns))
}

#' Extract authors from a TEI node
#' @noRd
.parse_authors <- function(node) {
  authors <- xml2::xml_find_all(node, ".//tei:author", .tei_ns)

  if (length(authors) == 0L) return(NULL)

  rows <- lapply(authors, function(a) {
    first <- .tei_text(xml2::xml_find_first(a, ".//tei:forename", .tei_ns))
    last  <- .tei_text(xml2::xml_find_first(a, ".//tei:surname",  .tei_ns))
    affil <- .tei_text(xml2::xml_find_first(a, ".//tei:affiliation//tei:orgName", .tei_ns))

    data.frame(
      first_name  = first,
      last_name   = last,
      affiliation = affil,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}

#' Parse a complete <biblStruct> node
#' @noRd
.parse_biblstruct <- function(node) {
  # Priority: analytic (article) > monogr level=m (book/report)
  title <- .tei_text(
    xml2::xml_find_first(node, ".//tei:analytic/tei:title", .tei_ns)
  )
  if (is.na(title) || title == "") {
    title <- .tei_text(
      xml2::xml_find_first(node, ".//tei:monogr/tei:title[@level='m']", .tei_ns)
    )
  }


  # Authors
  authors_df  <- .parse_authors(node)
  authors_str <- if (is.null(authors_df)) {
    NA_character_
  } else {
    paste(
      paste(authors_df$last_name, authors_df$first_name, sep = ", "),
      collapse = "; "
    )
  }

  # Journal
  journal <- .tei_text(
    xml2::xml_find_first(node, ".//tei:monogr/tei:title[@level='j']", .tei_ns)
  )

  # Publisher
  publisher <- .tei_text(
    xml2::xml_find_first(node, ".//tei:monogr/tei:imprint/tei:publisher", .tei_ns)
  )

  # Year
  year_raw <- xml2::xml_attr(
    xml2::xml_find_first(node, ".//tei:date[@type='published']", .tei_ns),
    "when"
  )
  year <- suppressWarnings(as.integer(substr(year_raw, 1L, 4L)))

  # Volume / issue / pages
  volume <- .tei_text(
    xml2::xml_find_first(node, ".//tei:monogr/tei:imprint/tei:biblScope[@unit='volume']", .tei_ns)
  )
  issue  <- .tei_text(
    xml2::xml_find_first(node, ".//tei:monogr/tei:imprint/tei:biblScope[@unit='issue']", .tei_ns)
  )

  page_node <- xml2::xml_find_first(
    node, ".//tei:monogr/tei:imprint/tei:biblScope[@unit='page']", .tei_ns
  )
  pages <- if (!inherits(page_node, "xml_missing")) {
    from <- xml2::xml_attr(page_node, "from")
    to   <- xml2::xml_attr(page_node, "to")
    if (!is.na(from) && !is.na(to)) paste(from, to, sep = "-") else .tei_text(page_node)
  } else {
    NA_character_
  }

  # Identifiers
  doi    <- .parse_idno(node, "DOI")
  pmid   <- .parse_idno(node, "PMID")
  arxiv  <- .parse_idno(node, "arxiv")

  list(
    title        = title,
    authors_str  = authors_str,
    authors_df   = authors_df,
    journal      = journal,
    publisher    = publisher,
    year         = year,
    volume       = volume,
    issue        = issue,
    pages        = pages,
    doi          = doi,
    pmid         = pmid,
    arxiv_id     = arxiv
  )
}


# Main function


#' Parse the GROBID header XML output of the document
#'
#' @description
#' Parses the TEI XML produced by the GROBID service
#' `processHeaderDocument` via [grobid_process_file()] and transforms it into a single-row tibble
#' containing the document header metadata: bibliographic
#' information, abstract, keywords, language and reference count.
#'
#' @param xml_content An
#'   `xml2::xml_document` object, as returned by [grobid_process_file()]
#'   with `service = "processHeaderDocument"`.
#' @param source_file Name of the source file associated with the xml.
#'
#' @return A single-row `tibble` with the following columns:
#'   `source_file`, `title`, `authors` (character, concatenated
#'   `"Last name, First name"` pairs), `authors_list` (list-column
#'   of data frames with `first_name` / `last_name` / `affiliation`), `journal`,
#'   `publisher`, `year` (integer), `volume`, `issue`, `pages`, `doi`,
#'   `pmid`, `arxiv_id`, `abstract`, `keywords` (character, separated by
#'   `"; "`), `language` (character, ISO code derived from `xml:lang`), and
#'   `n_references` (integer, number of bibliographic references
#'   detected in the document).
#'
#' @importFrom tibble tibble
#' @importFrom xml2 xml_find_first xml_find_all xml_attr xml_text
#'
#' @examples
#' \dontrun{
#' xml_result <- grobid_process_file("paper.pdf",
#'                                    service = "processHeaderDocument",
#'                                    output_format = "raw")
#' parse_header(xml_result)
#' }
#'
#' @seealso [grobid_process_file()], [parse_references()],
#'   [parse_fulltext()], [parse_citation_list()]
#' @export
parse_header <- function(xml_content, source_file = NULL) {
  tei_root <- .parse_tei_input(xml_content)

  header <- xml2::xml_find_first(tei_root, ".//tei:teiHeader", .tei_ns)

  bib <- .parse_biblstruct(header)

  # Abstract
  abstract <- .tei_text(
    xml2::xml_find_first(header, ".//tei:abstract//tei:p", .tei_ns)
  )

  # Keywords
  kw_nodes <- xml2::xml_find_all(
    header, ".//tei:keywords/tei:term", .tei_ns
  )
  keywords <- if (length(kw_nodes) > 0L) {
    paste(vapply(kw_nodes, xml2::xml_text, character(1L)), collapse = "; ")
  } else {
    NA_character_
  }

  # Language
  # language <- xml2::xml_attr(
  #   xml2::xml_find_first(tei_root, "tei:text", .tei_ns),
  #   "xml:lang"
  # )
  language <- xml2::xml_attr(
    xml2::xml_find_first(tei_root, ".//tei:text", .tei_ns),
    "lang"
  )

  # Reference count
  n_references <- length(
    xml2::xml_find_all(tei_root, ".//tei:listBibl/tei:biblStruct", .tei_ns)
  )

  tibble::tibble(
    source_file  = if (is.null(source_file)) NA_character_ else source_file,
    title        = bib$title,
    authors      = bib$authors_str,
    authors_list = list(bib$authors_df),
    journal      = bib$journal,
    publisher    = bib$publisher,
    year         = bib$year,
    volume       = bib$volume,
    issue        = bib$issue,
    pages        = bib$pages,
    doi          = bib$doi,
    pmid         = bib$pmid,
    arxiv_id     = bib$arxiv_id,
    abstract     = abstract,
    keywords     = keywords,
    language     = language,
    n_references = as.integer(n_references)
  )
}

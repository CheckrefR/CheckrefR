# 06_parse_fulltext.R
# Parsing of the TEI XML produced by processFulltextDocument



# Internal helpers


.tei_children_text <- function(node, xpath) {
  nodes <- xml2::xml_find_all(node, xpath, .tei_ns)
  if (length(nodes) == 0L) return(NA_character_)
  trimws(paste(xml2::xml_text(nodes), collapse = "\n"))
}

.count_words <- function(text) {
  if (is.na(text) || nchar(trimws(text)) == 0L) return(0L)
  length(strsplit(trimws(text), "\\s+")[[1L]])
}

.count_paragraphs <- function(node, xpath = ".//tei:p") {
  length(xml2::xml_find_all(node, xpath, .tei_ns))
}


# Extractors by section type


.extract_title <- function(tei_root, section_n) {
  node <- xml2::xml_find_first(
    tei_root,
    ".//tei:titleStmt/tei:title[@level='a'][@type='main']",
    .tei_ns
  )
  text <- .tei_text(node)
  tibble::tibble(
    source_file   = NA_character_,
    section_type  = "title",
    section_n     = section_n,
    section_title = NA_character_,
    section_level = NA_integer_,
    content       = text,
    n_words       = .count_words(text),
    n_paragraphs  = 0L
  )
}

.extract_abstract <- function(tei_root, section_n) {
  node <- xml2::xml_find_first(tei_root, ".//tei:abstract", .tei_ns)
  text <- if (is.na(xml2::xml_find_first(node, "self::*", .tei_ns))) {
    NA_character_
  } else {
    .tei_children_text(node, ".//tei:p")
  }
  tibble::tibble(
    source_file   = NA_character_,
    section_type  = "abstract",
    section_n     = section_n,
    section_title = NA_character_,
    section_level = NA_integer_,
    content       = text,
    n_words       = .count_words(text),
    n_paragraphs  = .count_paragraphs(node)
  )
}

.extract_body_sections <- function(tei_root, section_n_start) {
  # Only first-level divs within body
  divs <- xml2::xml_find_all(
    tei_root,
    ".//tei:body/tei:div",
    .tei_ns
  )

  if (length(divs) == 0L) return(NULL)

  rows <- vector("list", length(divs))
  for (i in seq_along(divs)) {
    node  <- divs[[i]]
    title <- .tei_text(xml2::xml_find_first(node, "tei:head", .tei_ns))
    # .//tei:p retrieves all paragraphs, including those in sub-divs
    text  <- .tei_children_text(node, ".//tei:p")

    rows[[i]] <- tibble::tibble(
      source_file   = NA_character_,
      section_type  = "body",
      section_n     = section_n_start + i - 1L,
      section_title = title,
      section_level = 1L,
      content       = text,
      n_words       = .count_words(text),
      n_paragraphs  = .count_paragraphs(node, ".//tei:p")
    )
  }

  do.call(rbind, rows)
}


.extract_acknowledgment <- function(tei_root, section_n) {
  node <- xml2::xml_find_first(
    tei_root,
    ".//tei:back//tei:div[@type='acknowledgement']",
    .tei_ns
  )
  if (inherits(node, "xml_missing")) return(NULL)

  text <- .tei_children_text(node, ".//tei:p")
  tibble::tibble(
    source_file   = NA_character_,
    section_type  = "acknowledgment",
    section_n     = section_n,
    section_title = NA_character_,
    section_level = 1L,
    content       = text,
    n_words       = .count_words(text),
    n_paragraphs  = .count_paragraphs(node)
  )
}

.extract_appendices <- function(tei_root, section_n_start) {
  nodes <- xml2::xml_find_all(
    tei_root,
    ".//tei:back//tei:div[@type='annex']//tei:div",
    .tei_ns
  )
  if (length(nodes) == 0L) return(NULL)

  rows <- vector("list", length(nodes))

  for (i in seq_along(nodes)) {
    node  <- nodes[[i]]
    head  <- xml2::xml_find_first(node, "tei:head", .tei_ns)
    title <- .tei_text(head)
    text  <- .tei_children_text(node, "tei:p")

    rows[[i]] <- tibble::tibble(
      source_file   = NA_character_,
      section_type  = "appendix",
      section_n     = section_n_start + i - 1L,
      section_title = title,
      section_level = 1L,
      content       = text,
      n_words       = .count_words(text),
      n_paragraphs  = .count_paragraphs(node, "tei:p")
    )
  }

  do.call(rbind, rows)
}


# Main function


#' Parse the GROBID full-text XML output
#'
#' @description
#' Parses the TEI XML produced by the GROBID service
#' `processFulltextDocument` via [grobid_process_file()] and transforms it into a structured
#' tibble describing the sections of the document: title, abstract,
#' body divisions, acknowledgments and appendices.
#'
#' @param xml_content A character string (`character`) containing raw
#'   TEI XML, a path to an existing XML file, or an
#'   `xml2::xml_document` object, as returned by [grobid_process_file()]
#'   with `service = "processFulltextDocument"`.
#'
#' @return A `tibble` with one row per extracted section and the
#'   following columns: `source_file` (character, base name of the
#'   file if `xml_content` was a file path, `NA` otherwise), `section_type`
#'   (one of `"title"`, `"abstract"`, `"body"`,
#'   `"acknowledgment"`, `"appendix"`), `section_n` (integer,
#'   sequential position among all sections), `section_title` (character,
#'   section title if applicable), `section_level` (integer, nesting
#'   level), `content` (character, extracted text), `n_words`
#'   (integer) and `n_paragraphs` (integer).
#'
#' @importFrom cli cli_abort
#' @importFrom tibble tibble
#' @importFrom xml2 read_xml xml_find_all xml_find_first xml_root xml_text
#'
#' @examples
#' \dontrun{
#' xml_result <- grobid_process_file("paper.pdf",
#'                                    service = "processFulltextDocument",
#'                                    output_format = "raw")
#' parse_fulltext(xml_result)
#' }
#'
#' @seealso [grobid_process_file()], [parse_header()], [parse_references()],
#'   [parse_citation_list()]
#' @export
parse_fulltext <- function(xml_content) {

  # -- Source resolution
  source_label <- NA_character_    #Similar to the .parse_tei_input function, see about
  if (is.character(xml_content)) { #adapting one and the other into a single one
    if (file.exists(xml_content)) {
      source_label <- basename(xml_content)
      tei <- xml2::read_xml(xml_content)
    } else {
      tei <- xml2::read_xml(xml_content)
    }
  } else if (inherits(xml_content, "xml_document")) {
    tei <- xml_content
  } else {
    cli::cli_abort(
      "{.arg xml_content} must be a `character` (raw XML or path) or an `xml2::xml_document`."
    )
  }

  tei_root <- xml2::xml_root(tei)

  # -- Sequential extraction
  parts <- list(
    .extract_title(tei_root, 1L),
    .extract_abstract(tei_root, 2L)
  )

  body <- .extract_body_sections(tei_root, 3L)
  next_n <- 3L + if (!is.null(body)) nrow(body) else 0L

  ack  <- .extract_acknowledgment(tei_root, next_n)
  next_n <- next_n + if (!is.null(ack)) 1L else 0L

  app  <- .extract_appendices(tei_root, next_n)

  parts <- c(parts, list(body, ack, app))
  parts <- Filter(Negate(is.null), parts)

  result <- do.call(rbind, parts)
  result$source_file <- source_label

  result
}

# TEI namespace used by GROBID
.tei_ns <- c(tei = "http://www.tei-c.org/ns/1.0")

.tei_text <- function(node) {
  if (is.null(node) || inherits(node, "xml_missing")) return(NA_character_)
  txt <- trimws(paste(xml2::xml_text(node), collapse = " "))
  if (!nzchar(txt)) return(NA_character_)
  txt
}


#' Normalize TEI XML input
#'
#' Accepts either an already parsed XML object, an XML string, or a path
#' to an XML file and always returns an `xml_document` object.
#'
#' @param xml_content `character(1)` or XML object
#' @return `xml_document`
#' @importFrom xml2 read_xml
#' @noRd
.parse_tei_input <- function(xml_content) {
  if (inherits(xml_content, c("xml_document", "xml_node"))) {
    return(xml_content)
  }

  if (is.character(xml_content) && length(xml_content) == 1L) {

    if (file.exists(xml_content)) {
      return(xml2::read_xml(xml_content))
    }

    return(xml2::read_xml(charToRaw(
      enc2utf8(xml_content)  # ensure encoding
    )))
  }

  stop(
    "xml_content must be an XML object, an XML string or a file path."
  )
}

# Parse the GROBID header XML output of the document

Parses the TEI XML produced by the GROBID service
`processHeaderDocument` via
[`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md)
and transforms it into a single-row tibble containing the document
header metadata: bibliographic information, abstract, keywords, language
and reference count.

## Usage

``` r
parse_header(xml_content, source_file = NULL)
```

## Arguments

- xml_content:

  An `xml2::xml_document` object, as returned by
  [`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md)
  with `service = "processHeaderDocument"`.

- source_file:

  Name of the source file associated with the xml.

## Value

A single-row `tibble` with the following columns: `source_file`,
`title`, `authors` (character, concatenated `"Last name, First name"`
pairs), `authors_list` (list-column of data frames with `first_name` /
`last_name` / `affiliation`), `journal`, `publisher`, `year` (integer),
`volume`, `issue`, `pages`, `doi`, `pmid`, `arxiv_id`, `abstract`,
`keywords` (character, separated by `"; "`), `language` (character, ISO
code derived from `xml:lang`), and `n_references` (integer, number of
bibliographic references detected in the document).

## See also

[`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md),
[`parse_references()`](https://CheckrefR.github.io/CheckrefR/reference/parse_references.md),
[`parse_fulltext()`](https://CheckrefR.github.io/CheckrefR/reference/parse_fulltext.md),
[`parse_citation_list()`](https://CheckrefR.github.io/CheckrefR/reference/parse_citation_list.md)

## Examples

``` r
if (FALSE) { # \dontrun{
xml_result <- grobid_process_file("paper.pdf",
                                   service = "processHeaderDocument",
                                   output_format = "raw")
parse_header(xml_result)
} # }
```

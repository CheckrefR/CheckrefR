# Parse the GROBID full-text XML output

Parses the TEI XML produced by the GROBID service
`processFulltextDocument` via
[`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md)
and transforms it into a structured tibble describing the sections of
the document: title, abstract, body divisions, acknowledgments and
appendices.

## Usage

``` r
parse_fulltext(xml_content)
```

## Arguments

- xml_content:

  A character string (`character`) containing raw TEI XML, a path to an
  existing XML file, or an `xml2::xml_document` object, as returned by
  [`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md)
  with `service = "processFulltextDocument"`.

## Value

A `tibble` with one row per extracted section and the following columns:
`source_file` (character, base name of the file if `xml_content` was a
file path, `NA` otherwise), `section_type` (one of `"title"`,
`"abstract"`, `"body"`, `"acknowledgment"`, `"appendix"`), `section_n`
(integer, sequential position among all sections), `section_title`
(character, section title if applicable), `section_level` (integer,
nesting level), `content` (character, extracted text), `n_words`
(integer) and `n_paragraphs` (integer).

## See also

[`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md),
[`parse_header()`](https://CheckrefR.github.io/CheckrefR/reference/parse_header.md),
[`parse_references()`](https://CheckrefR.github.io/CheckrefR/reference/parse_references.md),
[`parse_citation_list()`](https://CheckrefR.github.io/CheckrefR/reference/parse_citation_list.md)

## Examples

``` r
if (FALSE) { # \dontrun{
xml_result <- grobid_process_file("paper.pdf",
                                   service = "processFulltextDocument",
                                   output_format = "raw")
parse_fulltext(xml_result)
} # }
```

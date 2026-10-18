# Parse the GROBID XML output of bibliographic references

Parses the TEI XML produced by the GROBID `processReferences` service
and transforms it into a structured tibble, with one row per
bibliographic reference.

## Usage

``` r
parse_references(xml_content, source_file = NULL)
```

## Arguments

- xml_content:

  An `xml2::xml_document` object, as returned by
  [`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md)
  with `service = "processReferences"`.

- source_file:

  Name of the source file associated with the xml.

## Value

A `tibble` with one row per reference and the following columns:
`source_file`, `ref_id` (character, GROBID `xml:id` if present), `ref_n`
(integer, sequential position), `raw_reference` (character, raw text of
the reference if available), `title`, `authors` (character, concatenated
`"Last name, First name"` pairs), `authors_list` (list-column of data
frames with `first_name` / `last_name`), `year` (integer), `journal`,
`publisher`, `volume`, `issue`, `pages`, `doi`, `pmid`, and `url`. If no
reference is found in `xml_content`, a zero-row tibble with the same
schema is returned and a message is displayed.

## See also

[`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md),
[`parse_header()`](https://CheckrefR.github.io/CheckrefR/reference/parse_header.md),
[`parse_citation_list()`](https://CheckrefR.github.io/CheckrefR/reference/parse_citation_list.md),
[`parse_fulltext()`](https://CheckrefR.github.io/CheckrefR/reference/parse_fulltext.md)

## Examples

``` r
if (FALSE) { # \dontrun{
xml_result <- grobid_process_file("paper.pdf",
                                   service = "processReferences",
                                   output_format = "raw")
parse_references(xml_result)
} # }
```

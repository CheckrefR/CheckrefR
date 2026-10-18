# Parse the GROBID XML output of a citation list

Parses the TEI XML returned by the GROBID `processCitationList` service
used with
[`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md)
or directly via
[`process_citation_file()`](https://CheckrefR.github.io/CheckrefR/reference/process_citation_file.md)
and transforms it into a structured tibble, with one row per parsed
citation. Optionally allows attaching the raw original citation strings
to the extracted metadata.

## Usage

``` r
parse_citation_list(xml_content, raw_references = NULL)
```

## Arguments

- xml_content:

  A character string containing raw TEI XML, a path to an XML file, or
  an `xml2::xml_document` object, as returned by
  [`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md)
  with `service = "processCitationList"`.

- raw_references:

  An optional `character` vector containing the raw citation strings
  submitted to GROBID, in the same order as the `<biblStruct>` nodes of
  `xml_content`. If provided and its length does not match the number of
  parsed citations, a [`warning()`](https://rdrr.io/r/base/warning.html)
  is issued and `raw_reference` is set to `NA` for unmatched entries.
  Default `NULL`.

## Value

A `tibble` with one row per parsed citation and the following columns:
`ref_n` (integer, position of the citation in the entry),
`raw_reference` (original citation string, or `NA`), `title`, `authors`
(character, concatenated `"Last name, First name"` pairs),
`authors_list` (list-column of data frames with `first_name` /
`last_name`), `year` (integer), `journal`, `publisher`, `volume`,
`issue`, `pages`, `doi`, `pmid`, `url`, `ref_type` (character, inferred
reference type), and `parse_confidence` (numeric, from the GROBID
`confidence` attribute, `NA` if absent). If no citation is found in
`xml_content`, a zero-row tibble with the same schema is returned and a
message is displayed.

## See also

[`process_citation_file()`](https://CheckrefR.github.io/CheckrefR/reference/process_citation_file.md),
[`parse_references()`](https://CheckrefR.github.io/CheckrefR/reference/parse_references.md),
[`parse_header()`](https://CheckrefR.github.io/CheckrefR/reference/parse_header.md),
[`parse_fulltext()`](https://CheckrefR.github.io/CheckrefR/reference/parse_fulltext.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Typical usage via the high-level wrapper
txt_file <- system.file("extdata", package = "CheckrefR") |>
  list.files(pattern = "\\.txt$", full.names = TRUE) |>
  (\(x) x[1])()
citations_xml <- process_citation_file(txt_file, output_format = "raw")
parse_citation_list(citations_xml)
} # }

# Direct usage on a raw TEI XML fragment
xml <- paste0(
  "<TEI xmlns='http://www.tei-c.org/ns/1.0'>",
  "<text><body><listBibl>",
  "<biblStruct confidence='0.9'>",
  "<analytic><title level='a'>A sample title</title></analytic>",
  "</biblStruct>",
  "</listBibl></body></text></TEI>"
)
parse_citation_list(xml)
#> # A tibble: 1 × 16
#>   ref_n raw_reference title  authors authors_list  year journal publisher volume
#>   <int> <chr>         <chr>  <chr>   <list>       <int> <chr>   <chr>     <chr> 
#> 1     1 NA            A sam… NA      <NULL>          NA NA      NA        NA    
#> # ℹ 7 more variables: issue <chr>, pages <chr>, doi <chr>, pmid <chr>,
#> #   url <chr>, ref_type <chr>, parse_confidence <dbl>
```

# Format APA results for validation pipeline

Converts the output of
[`parse_apa_text()`](https://CheckrefR.github.io/CheckrefR/reference/parse_apa_text.md)
into a data frame structure compatible with
[`validate_references()`](https://CheckrefR.github.io/CheckrefR/reference/validate_references.md).
It adds necessary columns such as ref_n, source_file, and authors_list
(parsed from the string).

## Usage

``` r
format_apa_for_validation(apa_data, source_file = "APA_Input")
```

## Arguments

- apa_data:

  A data frame returned by
  [`parse_apa_text()`](https://CheckrefR.github.io/CheckrefR/reference/parse_apa_text.md).

- source_file:

  Optional character string indicating the source file name. Defaults to
  "APA_Input".

## Value

A tibble/data.frame with columns: title, doi, year, authors,
authors_list, ref_n, source_file.

## See also

[`check_doi_exists()`](https://CheckrefR.github.io/CheckrefR/reference/check_doi_exists.md)
to validate the existence of an extracted DOI,
[`validate_references()`](https://CheckrefR.github.io/CheckrefR/reference/validate_references.md)
for the full reference validation pipeline via OpenAlex/DOI.

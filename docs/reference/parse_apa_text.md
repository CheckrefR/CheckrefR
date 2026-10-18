# Parse one or several references in APA 7 format

Extracts metadata (authors, year, title, DOI) from one or several
bibliographic references in APA 7 format, from free text.

## Usage

``` r
parse_apa_text(input, as_ref_df = FALSE, source_file_label = "APA_Input")
```

## Arguments

- input:

  One of the following formats:

  - a path to a text file (character(1) ending with ".txt"), one
    reference per line ;

  - a character vector, one reference per element ;

  - a single-column data.frame or tibble, one reference per line.

- as_ref_df:

  Logical. If `TRUE`, returns a data frame formatted specifically for
  use with
  [`validate_references()`](https://CheckrefR.github.io/CheckrefR/reference/validate_references.md).
  This adds columns `ref_n`, `source_file`, and converts `authorships`
  into a list column `authors_list` compatible with the validation
  pipeline. Defaults to `FALSE`.

- source_file_label:

  Character string. Used only if `as_ref_df = TRUE`. Sets the value for
  the `source_file` column in the output. Defaults to `"APA_Input"`.

## Value

Depending on `as_ref_df`:

- If `FALSE` (default):

  A `data.frame` with one row per reference and the columns:

  `title`

  :   `character`. Title extracted from the reference, or `NA` if the
      splitting pattern could not be identified.

  `doi`

  :   `character`. Normalized DOI (lowercase, without URL prefix),
      extracted only if it appears as a `https://doi.org/...` URL at the
      very end of the reference ; `NA` otherwise.

  `publication_year`

  :   `numeric`. Publication year extracted from the `(YYYY)` pattern ;
      `NA` if absent or malformed.

  `authorships`

  :   `character`. Concatenated string of authors in the format
      `"Last name, First name; Last name, First name; ..."`, or `NA` if
      no author could be identified before the year.

  `authorships_list`

  :   `list` of `data.frame`. For each reference, a two-column
      data.frame (`first_name`, `last_name`), one row per detected
      author (empty data.frame with 0 rows if no author could be
      extracted).

- If `TRUE`:

  A `tibble` compatible with
  [`validate_references()`](https://CheckrefR.github.io/CheckrefR/reference/validate_references.md),
  containing:

  `source_file`

  :   `character`. The label provided via `source_file_label`.

  `ref_n`

  :   `integer`. Sequential reference number.

  `title`

  :   `character`. Extracted title.

  `doi`

  :   `character`. Extracted DOI.

  `year`

  :   `numeric`. Extracted publication year.

  `authors`

  :   `character`. String of authors (same as `authorships` above).

  `authors_list`

  :   `list`. List of data.frames with `first_name` and `last_name`
      columns.

## Limitations of the approach

This function relies on an extraction by regular expressions based on
the expected structure of an APA 7 reference
(`Authors (Year). Title. Journal, ...`). It does not rely on any robust
grammatical parser and **assumes that references are correctly and
strictly formatted**:

- non-standard punctuation (missing or misplaced comma or period, extra
  space) may prevent the correct extraction of a field (authors, title,
  year) ;

- the year must appear explicitly in the form `(YYYY)` or `(YYYYa)` ;
  any other form (e.g. "n.d.", "in press", year range) will not be
  recognized and will return `NA` ;

- the title is split at the first period following the year: a title
  containing an abbreviation, an internal period, or preceded by an
  atypical author structure may be truncated or incorrectly extracted ;

- the DOI is only recognized as a `doi.org` URL placed at the very end
  of the string ; a DOI mentioned in another form (e.g. "DOI:
  10.xxxx/...", DOI in the middle of the text) will not be detected ;

- authors are extracted via a `Last name, Initials` pattern ;
  non-standard formats (ambiguous compound names, initials without a
  period, first name-last name order) may produce incomplete or
  erroneous results.

In case of non-compliance with the expected format, the function
generally does not generate an explicit error: the affected fields are
silently set to `NA` or partially extracted. It is therefore recommended
to visually check the results rather than assuming 100% reliable
extraction, especially on heterogeneous or variable-quality corpora of
references.

## See also

[`check_doi_exists()`](https://CheckrefR.github.io/CheckrefR/reference/check_doi_exists.md)
to validate the existence of an extracted DOI,
[`validate_references()`](https://CheckrefR.github.io/CheckrefR/reference/validate_references.md)
for the full reference validation pipeline via OpenAlex/DOI,
[`format_apa_for_validation()`](https://CheckrefR.github.io/CheckrefR/reference/format_apa_for_validation.md)
to convert existing results.

## Examples

``` r
# Nominal case: well-formatted reference
parse_apa_text("Smith, J. (2020). Title of paper. Journal, 12(3), 45-67.
https://doi.org/10.1234/xyz")
#>                                                                           raw_reference
#> 1 Smith, J. (2020). Title of paper. Journal, 12(3), 45-67.\nhttps://doi.org/10.1234/xyz
#>            title         doi publication_year authorships authorships_list
#> 1 Title of paper 10.1234/xyz             2020    Smith, J         J, Smith

refs <- c(
  "Smith, J. (2020). Title one. Journal, 12(3), 45-67.",
  "Doe, J., & Roe, R. (2019). Title two. Journal, 5(1), 1-10."
)
parse_apa_text(refs)
#>                                                raw_reference     title  doi
#> 1        Smith, J. (2020). Title one. Journal, 12(3), 45-67. Title one <NA>
#> 2 Doe, J., & Roe, R. (2019). Title two. Journal, 5(1), 1-10. Title two <NA>
#>   publication_year    authorships authorships_list
#> 1             2020       Smith, J         J, Smith
#> 2             2019 Doe, J; Roe, R   J, R, Doe, Roe

# Directly format for validation pipeline
parse_apa_text(refs, as_ref_df = TRUE)
#> # A tibble: 2 × 8
#>   raw_reference         source_file ref_n title doi    year authors authors_list
#>   <chr>                 <chr>       <int> <chr> <chr> <dbl> <chr>   <list>      
#> 1 Smith, J. (2020). Ti… APA_Input       1 Titl… NA     2020 Smith,… <df [1 × 2]>
#> 2 Doe, J., & Roe, R. (… APA_Input       2 Titl… NA     2019 Doe, J… <df [2 × 2]>

# Edge case: non-compliant format (missing year) -> partial extraction
parse_apa_text("Smith J Title of paper without proper APA formatting")
#>                                          raw_reference title  doi
#> 1 Smith J Title of paper without proper APA formatting  <NA> <NA>
#>   publication_year authorships authorships_list
#> 1               NA        <NA>                 
```

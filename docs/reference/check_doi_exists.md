# Check the existence of one or more DOIs

Verifies whether one or more Digital Object Identifiers (DOIs) actually
exist, by normalizing the input string(s), validating their syntax, and
querying the DOI resolution service (`https://doi.org/api/handles/`).
DOIs with an invalid syntax are not queried over the network and
immediately return `NA`.

## Usage

``` r
check_doi_exists(doi, named = FALSE)
```

## Arguments

- doi:

  A `character` vector of one or more DOIs. Accepted formats include raw
  DOIs (`"10.xxxx/yyyy"`), full URLs (`"https://doi.org/10.xxxx/yyyy"`),
  and `"doi:"`-prefixed strings. `NA` values are allowed and return `NA`
  in the result.

- named:

  A single `logical` value. If `TRUE`, the returned vector is named
  using the normalized DOI strings. Default is `FALSE`.

## Value

A `logical` vector of the same length as `doi`, where each element is:

- `NA` if the corresponding DOI is missing or syntactically invalid (no
  network call is made in this case) ;

- `TRUE` if the DOI resolves successfully (HTTP 200 and
  `responseCode == 1`) ;

- `FALSE` if the DOI is syntactically valid but does not resolve, or if
  the network request fails.

If `named = TRUE`, the vector is named using the normalized DOI values
(see `.normalize_doi()`).

## See also

[`validate_references()`](https://CheckrefR.github.io/CheckrefR/reference/validate_references.md)
for the full reference-validation pipeline that leverages DOI resolution
among other matching strategies.

## Examples

``` r
# \donttest{
# Single DOI - several input formats accepted
check_doi_exists("10.1126/science.169.3946.635")
#> [1] TRUE
check_doi_exists("https://doi.org/10.1126/science.169.3946.635")
#> [1] TRUE
check_doi_exists("doi:10.1126/science.169.3946.635")
#> [1] TRUE

# Multiple DOIs, unnamed result
dois <- c(
  "10.1126/science.169.3946.635",
  "10.9999/this-doi-does-not-exist",
  "not_a_doi_at_all",
  NA
)
check_doi_exists(dois)
#> [1]  TRUE FALSE    NA    NA

# Named result
check_doi_exists(dois, named = TRUE)
#>    10.1126/science.169.3946.635 10.9999/this-doi-does-not-exist 
#>                            TRUE                           FALSE 
#>                not_a_doi_at_all                            <NA> 
#>                              NA                              NA 
# }
```

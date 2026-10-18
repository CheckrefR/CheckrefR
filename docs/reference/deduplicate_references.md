# Deduplicate validation results by keeping the best candidate per reference

Reduces a table of validation results (typically produced by
[`validate_references`](https://CheckrefR.github.io/CheckrefR/reference/validate_references.md),
which may contain several rows - several OpenAlex candidates - per
reference) to a single row per reference, keeping for each group
`(source_file, ref_n)` the candidate with the highest overall score
(`score_global`).

## Usage

``` r
deduplicate_references(data, verbose = TRUE)
```

## Arguments

- data:

  `data.frame` or `tibble`. Validation results to deduplicate, which
  must contain the columns `source_file`, `ref_n` and `score_global`
  (structure typically produced by
  [`validate_references`](https://CheckrefR.github.io/CheckrefR/reference/validate_references.md)).

- verbose:

  `logical`. If `TRUE` (default), displays a summary of the matching
  statuses (`match_status`) of the deduplicated table, in the same
  format as displayed at the end of the execution of
  [`validate_references`](https://CheckrefR.github.io/CheckrefR/reference/validate_references.md).

## Value

An object of the same type as `data` (`data.frame` or `tibble`),
containing a single row per unique pair `(source_file, ref_n)` - the one
with the highest `score_global` within that group - and preserving the
order of the rows of the input table.

## Details

Rows are grouped by the combination of the columns `source_file` and
`ref_n`, which uniquely identifies each original bibliographic reference
(the same reference may appear on several rows if several OpenAlex
candidates were retained during validation).

**Score tie**: in case of a tie in the maximum overall score within the
same group, the **first row encountered** in the order of the input
table is kept.

The row order of the input table is preserved in the result: only the
rows not retained are removed.

## See also

[`validate_references`](https://CheckrefR.github.io/CheckrefR/reference/validate_references.md)
for producing the multi-candidate results table expected as input.

## Examples

``` r
if (FALSE) { # \dontrun{
refs <- parse_references("my_file.tei.xml")
results <- validate_references(refs, verbose = TRUE)

# Keep only the best candidate per reference
unique_results <- deduplicate_references(results, verbose = TRUE)
} # }
```

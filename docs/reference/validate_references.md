# Validate a set of bibliographic references via OpenAlex

Complete pipeline for validating a set of bibliographic references (for
example extracted by Grobid) against OpenAlex. For each reference, the
function first attempts validation by DOI (batched queries to OpenAlex
then, if necessary, to doi.org), then completes or replaces this result
with a title search when the DOI is missing, invalid, not found or
inconsistent with the returned metadata. Each input reference can result
in one or more output rows, one row per retained OpenAlex candidate.

## Usage

``` r
validate_references(
  refs,
  verbose = TRUE,
  max_candidates = .checkrefr_env$oa_max_candidates
)
```

## Arguments

- refs:

  `data.frame` or `tibble`. Bibliographic references to validate. Must
  contain the columns `title`, `authors_list`, `doi`, `year`, `ref_n`
  and `source_file` (structure typically produced by
  [`parse_references`](https://CheckrefR.github.io/CheckrefR/reference/parse_references.md),
  [`parse_citation_list`](https://CheckrefR.github.io/CheckrefR/reference/parse_citation_list.md),
  or by
  [`process_citation_file`](https://CheckrefR.github.io/CheckrefR/reference/process_citation_file.md),
  [`grobid_process_file`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md),
  with the `"processReferences"` service and by
  [`grobid_process_files`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_files.md),
  for each, with the `output_format = "parsed"` parameter).

- verbose:

  `logical`. If `TRUE` (default), displays the processing progress (DOI
  and title steps) as well as a final summary of the matching statuses
  obtained.

- max_candidates:

  `integer`. Maximum number of OpenAlex candidates presented per
  reference. Default value: `.checkrefr_env$oa_max_candidates`,
  (initialized to `3`).

## Value

A `data.frame`/`tibble` containing one or more rows per input reference
(one row per retained OpenAlex candidate, or a single row
`match_status = "no_match"` if no candidate was found). Main columns:
`source_file`, `ref_n`, `input_title`, `input_doi`, `input_year`,
`input_authors`, `oa_id`, `oa_title`, `oa_doi`, `oa_year`, `oa_authors`,
`score_title`, `score_authors`, `score_year`, `score_global`,
`n_candidates` and `match_status`. Use
[`deduplicate_references`](https://CheckrefR.github.io/CheckrefR/reference/deduplicate_references.md)
to keep only the best candidate per reference.

## Details

Processing takes place in two main steps:

**Step 1 — Batch DOI validation**: syntactically valid DOIs are
extracted and queried in one or several batched requests to OpenAlex.
Valid DOIs but absent from OpenAlex are then queried individually
against `doi.org` (CSL-JSON metadata or, failing that, APA bibliographic
text). Each reference then receives a status among:
`confirmed_with_doi`, `partial_with_doi`, `doi_mismatch`,
`doi_not_found`, `doi_does_not_exist`, `doi_unreachable`,
`doi_no_metadata`, or no result if the reference does not have a
syntactically valid DOI.

**Step 2 — Title validation**, applied reference by reference according
to the result of step 1:

- If the DOI is `confirmed_with_doi`: only the candidates derived from
  the DOI are kept.

- If the DOI is `partial_with_doi`, `doi_mismatch`, `doi_not_found` or
  `doi_does_not_exist`: the candidates derived from the DOI are combined
  with those obtained via a complementary title search.

- If no DOI result is available (no valid DOI): only the title search is
  performed.

**Matching score computation**: for each retained OpenAlex candidate, an
overall matching score (`score_global`) is computed as a weighted
combination of three components:

- a title similarity score (normalized Damerau-Levenshtein distance);

- an author similarity score, computed by
  [`compute_author_score`](https://CheckrefR.github.io/CheckrefR/reference/compute_author_score.md)
  (which itself relies on
  [`sim_author_pair`](https://CheckrefR.github.io/CheckrefR/reference/sim_author_pair.md)
  for comparing each pair of names) — see the documentation of these two
  functions for details on the computation rules and associated
  parameters;

- a publication year matching score (exact, tolerance of one year, or
  zero beyond that).

The weights of this combination as well as the candidate acceptance
thresholds can be configured via
[`checkrefr_set_defaults`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_set_defaults.md)
and can be viewed via
[`oa_matching_info`](https://CheckrefR.github.io/CheckrefR/reference/oa_matching_info.md).
Only candidates whose overall score exceeds the configured minimum
threshold are retained, up to a limit of `max_candidates` candidates per
reference.

## See also

[`compute_author_score`](https://CheckrefR.github.io/CheckrefR/reference/compute_author_score.md)
and
[`sim_author_pair`](https://CheckrefR.github.io/CheckrefR/reference/sim_author_pair.md)
for details on the computation of the author similarity score;
[`oa_matching_info`](https://CheckrefR.github.io/CheckrefR/reference/oa_matching_info.md)
to view the thresholds and weights used in the computation of the
overall score;
[`deduplicate_references`](https://CheckrefR.github.io/CheckrefR/reference/deduplicate_references.md)
to keep only one candidate per reference;
[`parse_references`](https://CheckrefR.github.io/CheckrefR/reference/parse_references.md)
and
[`parse_citation_list`](https://CheckrefR.github.io/CheckrefR/reference/parse_citation_list.md)
to produce the `refs` object expected as input.

## Examples

``` r
if (FALSE) { # \dontrun{
# refs must contain at least: title, authors_list, doi, year, ref_n, source_file
refs <- parse_references("my_file.tei.xml")
results <- validate_references(refs, verbose = TRUE)

# Keep only the best candidate per reference
dedup_results <- deduplicate_references(results)
} # }
```

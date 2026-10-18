# Get OpenAlex matching parameters information

Returns a structured summary of the current OpenAlex matching
configuration stored in the internal package environment. Parameters are
grouped into logical categories for readability and ease of inspection.

## Usage

``` r
oa_matching_info()
```

## Value

A named `list` with five sublists grouping the OpenAlex parameters by
functional category:

- `thresholds`:

  Numeric score thresholds used for article matching:
  `oa_probable_threshold`, `oa_min_threshold`, `oa_doi_threshold`.

- `weights`:

  Numeric weights applied to each component of the global matching
  score: `oa_w_title`, `oa_w_authors`, `oa_w_year`.

- `query_controls`:

  Integer and logical parameters controlling query behaviour and
  candidate selection: `oa_max_candidates`, `oa_api_key`.

- `author_window`:

  Parameters governing the sliding window strategy for author list
  analysis: `oa_use_window`, `oa_window_size`,
  `oa_large_author_threshold`.

- `truncation`:

  Parameters controlling truncation penalty and symmetry tolerance in
  author matching: `oa_min_coverage_ratio`, `oa_author_lambda`,
  `oa_sym_max_diff_abs`, `oa_sym_max_diff_prop`.

## Details

The function reads values directly from `.checkrefr_env` and displays
them using `cli` formatting. It returns the full parameter list
invisibly, allowing programmatic use without triggering side effects.

## See also

[`grobid_server_info`](https://CheckrefR.github.io/CheckrefR/reference/grobid_server_info.md)
for the equivalent function reporting GROBID server state.

## Examples

``` r
# Display and capture current OpenAlex parameters
params <- oa_matching_info()
#> 
#> ── OpenAlex Matching Parameters ────────────────────────────────────────────────
#> 
#> ── Score Thresholds ──
#> 
#> Probable match (oa_probable_threshold): 0.85
#> Minimum inclusion (oa_min_threshold): 0.55
#> DOI acceptance (oa_doi_threshold): 0.9
#> 
#> ── Scoring Weights ──
#> 
#> Title weight (oa_w_title): 0.7
#> Authors weight (oa_w_authors): 0.2
#> Year weight (oa_w_year): 0.1
#> 
#> ── Query Controls ──
#> 
#> Max candidates (oa_max_candidates): 3
#> API key (oa_api_key): xxxXXxxyzZ
#> 
#> ── Author Window Strategy ──
#> 
#> Use sliding window (oa_use_window): FALSE
#> Window size (oa_window_size): 2
#> Large author list threshold (oa_large_author_threshold): 10
#> 
#> ── Truncation Penalty & Symmetry ──
#> 
#> Min coverage ratio (oa_min_coverage_ratio): 0.65
#> Truncation lambda (oa_author_lambda): 0.4
#> Sym. abs. tolerance (oa_sym_max_diff_abs): 2
#> Sym. prop. tolerance (oa_sym_max_diff_prop): 0.1

# Access a specific subgroup programmatically
params$thresholds$oa_probable_threshold
#> [1] 0.85
params$weights
#> $oa_w_title
#> [1] 0.7
#> 
#> $oa_w_authors
#> [1] 0.2
#> 
#> $oa_w_year
#> [1] 0.1
#> 
```

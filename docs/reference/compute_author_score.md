# Compute a global similarity score between two lists of authors

Aggregates pairwise similarity scores (computed by
[`sim_author_pair`](https://CheckrefR.github.io/CheckrefR/reference/sim_author_pair.md))
between lists of authors, in order to produce a single score
representing the degree of correspondence between the two author lists,
presumably from the same bibliographic reference. The calculation mode
automatically adapts depending on whether the two lists have a similar
length (symmetric comparison) or very different lengths (truncation,
with conditional penalization).

## Usage

``` r
compute_author_score(
  ng,
  no,
  truncation_detected = FALSE,
  oa_large_author_threshold = .checkrefr_env$oa_large_author_threshold,
  oa_min_coverage_ratio = .checkrefr_env$oa_min_coverage_ratio,
  oa_use_window = .checkrefr_env$oa_use_window,
  oa_window_size = .checkrefr_env$oa_window_size,
  oa_sym_max_diff_abs = .checkrefr_env$oa_sym_max_diff_abs,
  oa_sym_max_diff_prop = .checkrefr_env$oa_sym_max_diff_prop,
  oa_author_lambda = .checkrefr_env$oa_author_lambda
)
```

## Arguments

- ng:

  Character vector. Full names of the authors (extracted by Grobid for a
  given reference).

- no:

  Character vector. Full names of the authors (returned by OpenAlex for
  the compared candidate).

- truncation_detected:

  Logical. Indicates whether an explicit truncation marker (e.g. "et
  al.") was detected in the raw bibliographic reference associated with
  `ng`, typically obtained via
  `.detect_truncation_marker(raw_reference)$detected`. This parameter is
  only taken into account in the asymmetric case where `ng` is the
  shorter list (`n_g < n_o`), i.e. when the Grobid-extracted author list
  is itself potentially truncated. If `TRUE` in that situation, the
  coverage-based penalization is bypassed entirely and the raw score
  `mean(pairs)` is returned, regardless of the coverage value: a
  detected marker is taken as evidence that the shortness of `ng`
  results from an editorial convention rather than from an unreliable
  match, making the truncation penalty unwarranted. It has no effect in
  the symmetric case, in the indeterminate case, or in the mirror case
  where `no` is the shorter list. Default value: `FALSE`.

- oa_large_author_threshold:

  Integer. Length threshold of `no` beyond which the indeterminate case
  applies when `ng` is very short (`length(ng) <= 2`). Default value:
  `.checkrefr_env$oa_large_author_threshold` (initialized to `10`).

- oa_min_coverage_ratio:

  Numeric between 0 and 1. Coverage threshold
  (`min(n_g,n_o)/max(n_g,n_o)`) below which the truncation penalization
  is **not** applied (see Details for reservations about this behavior).
  Default value: `.checkrefr_env$oa_min_coverage_ratio` (initialized to
  `0.65`).

- oa_use_window:

  Logical. If `TRUE`, enables sliding-window matching
  (`same_position = FALSE`) instead of position-by-position matching in
  case of truncation. Default value: `.checkrefr_env$oa_use_window`
  (initialized to `FALSE`).

- oa_window_size:

  Integer. Half-width (in number of positions) of the sliding window
  used when `oa_use_window = TRUE`. Default value:
  `.checkrefr_env$oa_window_size` (initialized to `2`).

- oa_sym_max_diff_abs:

  Integer. Maximum absolute gap between `length(ng)` and `length(no)`
  below which the two lists are treated as symmetric. Default value:
  `.checkrefr_env$oa_sym_max_diff_abs` (initialized to `2`).

- oa_sym_max_diff_prop:

  Numeric between 0 and 1. Maximum relative length difference proportion
  tolerated for the symmetric case. Default value:
  `.checkrefr_env$oa_sym_max_diff_prop` (initialized to `0.10`).

- oa_author_lambda:

  Numeric. Fixed factor (independent of coverage) that modulates the
  intensity of the truncation penalization:
  `score = mean(pairs) * (1 - (1 - coverage) * oa_author_lambda)`.
  Default value: `.checkrefr_env$oa_author_lambda` (initialized to
  `0.4`).

## Value

A single number (`numeric`) between 0 and 1 (except for rounding
effects) representing the global similarity score between the two author
lists:

- `0` in the indeterminate case;

- the average of pairwise scores in the symmetric case or in case of
  insufficient coverage;

- the average of pairwise scores penalized by the factor
  `(1 - (1 - coverage) * oa_author_lambda)` in case of truncation with
  sufficient coverage.

## Details

The calculation proceeds through three mutually exclusive regimes:

**1. Indeterminate case**

If `length(ng) <= 2` and `length(no) >= oa_large_author_threshold`
(default `10`), the comparison is deemed unreliable (too few Grobid
authors against a very long OpenAlex list) and the function returns `0`
without further calculation.

**2. Symmetric case**

The two lists are treated as "of comparable length" if: \$\$\|n_g -
n_o\| \le \code{oa\\sym\\max\\diff\\abs}\$\$ **or** \$\$\frac{\min(n_g,
n_o)}{\max(n_g, n_o)} \ge 1 - \code{oa\\sym\\max\\diff\\prop}\$\$ with
\\n_g = length(ng)\\, \\n_o = length(no)\\, and by default
`oa_sym_max_diff_abs = 2`, `oa_sym_max_diff_prop = 0.10`. Note that as
soon as `n_g == n_o`, this condition is automatically true (zero gap),
so this case systematically covers lists of the same length. The \\n =
\min(n_g, n_o)\\ first authors of each list are then compared term by
term with `sim_author_pair(ng[i], no[i], same_position = TRUE)`, and the
final score is their arithmetic mean: \$\$score = \frac{1}{n}
\sum\_{i=1}^{n} sim\\author\\pair(ng_i, no_i)\$\$

**3. Asymmetric case (truncation of one of the two lists)**

If the lists are deemed too different in length for the symmetric case,
a coverage rate is calculated: \$\$coverage = \min(n_g, n_o) / \max(n_g,
n_o)\$\$ Two matching strategies for the `min(n_g, n_o)` authors of the
shorter list are possible:

- `oa_use_window = FALSE` (default): direct matching position by
  position, `sim_author_pair(..., same_position = TRUE)`.

- `oa_use_window = TRUE`: for each author \\i\\ of the shorter list, the
  best score is retained among the authors of the longer list located
  within a window of \\\pm\\ `oa_window_size` positions (default `2`)
  around rank \\i\\, using `sim_author_pair(..., same_position = FALSE)`
  (F1-type score, consistent with the lack of strict positional
  alignment induced by the window).

A multiplicative penalization is then applied **only if coverage remains
sufficient** (`coverage >= oa_min_coverage_ratio`, default `0.65`):
\$\$\lambda\_{cov} = 1 - coverage\$\$ \$\$score = mean(pairs) \times
(1 - \lambda\_{cov} \times \code{oa\\author\\lambda})\$\$ where
`oa_author_lambda` (default `0.4`) is a fixed factor that modulates the
intensity of the penalization related to truncation: the lower the
coverage (thus the higher \\\lambda\_{cov}\\), the more the average
score is reduced, proportionally to `oa_author_lambda`.

In case of insufficient coverage (`coverage < oa_min_coverage_ratio`),
no penalization is applied and the raw score `mean(pairs)` is returned
as is. This design choice is motivated by the fact that author lists
extracted from bibliographic references (parameter `ng`) are
structurally limited by citation norms (truncation via "et al." beyond a
few authors), while lists from OpenAlex (`no`) tend to be exhaustive.
Very low coverage in the `n_g < n_o` case could therefore reflect a
bibliographic format artifact rather than genuine matching uncertainty.

## See also

[`sim_author_pair`](https://CheckrefR.github.io/CheckrefR/reference/sim_author_pair.md)
for the underlying pairwise similarity calculation.

## Examples

``` r
# Symmetric case: lists of the same length
ng <- c("Jean Dupont", "Marie Curie")
no <- c("J. Dupont", "M. Curie")
compute_author_score(ng, no)
#> [1] 1

# Slight truncation with sufficient coverage (0.67 >= 0.65) -> penalized
ng2 <- c("Jean Dupont", "Marie Curie", "Paul Martin")
no2 <- c("J. Dupont", "M. Curie")
compute_author_score(ng2, no2)
#> [1] 1

# Severe truncation with insufficient coverage -> no penalization
ng3 <- c("Jean Dupont", "Marie Curie", "Paul Martin", "Alice Bernard")
no3 <- c("J. Dupont")
compute_author_score(ng3, no3)
#> [1] 1

# Using the sliding-window mode for matching
compute_author_score(ng2, no2, oa_use_window = TRUE, oa_window_size = 1)
#> [1] 1
```

# Modify the default values of the CheckrefR environment

Modifies one or more internal variables of the CheckrefR environment
(`.checkrefr_env`), used as default values by other functions of the
package (Docker connection, remote connection, OpenAlex matching
parameters, DOI parameters, etc.).

## Usage

``` r
checkrefr_set_defaults(...)
```

## Arguments

- ...:

  Named arguments corresponding to the variables to modify. Available
  variables, grouped by category:

  Connection / Docker

  :   - `docker_port` (`character`) — Local port used for the GROBID
        Docker container. Default: `"8070"`.

      - `docker_image` (`character`) — Base name of the GROBID Docker
        image (before adding the version tag). Default:
        `"lfoppiano/grobid:"`.

      - `grobid_version` (`character`) — GROBID version to use for the
        Docker tag. Default: `"0.9.0"`.

      - `grobid_model_type` (`character` or `NA`) — Variant of the
        GROBID model (`"crf"` or `"full"`). An empty string, `NULL` or
        `NA` are normalized to `NA_character_`. Default: `NA`.

  Remote connection

  :   - `remote_default_url` (`list`) — Structure nested by model type.
        Must be a named list with at most two keys `"crf"` and `"full"`,
        each associated with a `character` vector of URLs, or a `list`
        named by rank to control the trial priority. Entries not
        mentioned (`crf` or `full`) remain unchanged. Examples:

        - `list(crf = c("https://mon-serveur-crf.example.com"))`

        - `list(full = list("1" = "https://mon-serveur-full.example.com"))`

      - `timeout` (`integer`) — Default timeout (in seconds) for HTTP
        requests to the GROBID API. Default: `120L`.

  Batch processing

  :   - `max_workers` (`integer`) — Number of workers used in parallel
        mode by
        [`grobid_process_files()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_files.md).
        Default: `4L`.

  OpenAlex matching — thresholds

  :   - `oa_probable_threshold` (`numeric`) — Global score threshold
        above which a candidate is considered as "probable". Default:
        `0.85`.

      - `oa_min_threshold` (`numeric`) — Minimal threshold for including
        a candidate. Default: `0.60`.

      - `oa_doi_threshold` (`numeric`) — Acceptance threshold for
        article matching via DOI. Default: `0.90`.

  OpenAlex matching — weighting

  :   - `oa_w_title` (`numeric`) — Weight of the title in the global
        score. Default: `0.60`.

      - `oa_w_authors` (`numeric`) — Weight of the authors in the global
        score. Default: `0.30`.

      - `oa_w_year` (`numeric`) — Weight of the year in the global
        score. Default: `0.10`.

  OpenAlex queries

  :   - `oa_max_candidates` (`integer`) — Maximum number of candidates
        presented per reference. Default: `3L`.

      - `oa_api_key` (`character` or `NA`) — API key used for the
        OpenAlex "polite pool". Default: `NA`.

  OpenAlex matching — author analysis

  :   - `oa_use_window` (`logical`) — Enables a sliding window for
        author list analysis. Default: `FALSE`.

      - `oa_window_size` (`numeric`) — Size of the sliding window (±k).
        Default: `2`.

      - `oa_large_author_threshold` (`numeric`) — Threshold from which
        an author list is considered "large". Default: `10`.

      - `oa_min_coverage_ratio` (`numeric`) — Threshold distinguishing
        marginal truncation from massive truncation of the author list.
        Default: `0.65`.

      - `oa_author_lambda` (`numeric`) — Penalty factor applied in case
        of truncation of the author list. Default: `0.4`.

      - `oa_sym_max_diff_abs` (`numeric`) — Absolute tolerance applied
        in the symmetric case (similar number of authors). Default: `2`.

      - `oa_sym_max_diff_prop` (`numeric`) — Proportional tolerance
        applied in the symmetric case. Default: `0.10`.

  DOI validation

  :   - `doi_email` (`character` or `NA`) — Email used for the polite
        User-Agent when querying Crossref / doi.org. Default: `NA`.

      - `doi_max_retries` (`integer`) — Maximum number of attempts in
        case of network error or 5xx response for requests to doi.org.
        Default: `3L`.

      - `doi_retry_backoff` (`numeric`) — Initial delay (in seconds)
        before a new attempt, doubled at each additional attempt
        (exponential backoff). Default: `1`.

## Value

Invisibly returns the updated internal environment (`.checkrefr_env`, an
`environment` object).

## See also

[`checkrefr_env_status()`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_env_status.md)
to view the currently configured values,
[`checkrefr_env_reset()`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_env_reset.md)
to reset these default values,
[`grobid_check_requirements()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_check_requirements.md)
and
[`oa_matching_info()`](https://CheckrefR.github.io/CheckrefR/reference/oa_matching_info.md)
(OpenAlex matching parameters).

## Examples

``` r
# Modify the default GROBID version used
checkrefr_set_defaults(grobid_version = "0.8.1")
#> ✔ Variable(s) updated: "grobid_version"

# Modify several variables simultaneously
checkrefr_set_defaults(timeout = 60L, max_workers = 2L)
#> ✔ Variable(s) updated: "timeout" and "max_workers"

# Adjust the OpenAlex matching thresholds and weights
checkrefr_set_defaults(
  oa_min_threshold = 0.55,
  oa_w_title       = 0.70,
  oa_w_authors     = 0.20,
  oa_w_year        = 0.10
)
#> ✔ Variable(s) updated: "oa_min_threshold", "oa_w_title", "oa_w_authors", and "oa_w_year"

# Add a priority remote URL for "full" mode
checkrefr_set_defaults(
  remote_default_url = list(full = list("1" = "https://mon-serveur.example.com"))
)
#> ✔ Variable(s) updated: "remote_default_url"

# Set an email for OpenAlex and Crossref polite requests
checkrefr_set_defaults(oa_api_key = "xxxXXxxyzZ", doi_email = "moi@example.com")
#> ✔ Variable(s) updated: "oa_api_key" and "doi_email"
```

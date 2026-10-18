# Reset the CheckrefR environment to its default values

Resets all or part of the internal variables of the CheckrefR
environment (`.checkrefr_env`) to their original default values. Allows
a complete reset (default behavior) or a targeted reset of a subset of
variables.

## Usage

``` r
checkrefr_env_reset(fields = NULL, verbose = TRUE)
```

## Arguments

- fields:

  `character` or `NULL`. Vector of variable names to reset. If `NULL`
  (default), the entire environment is reset. Recognized variables,
  grouped by category:

  Connection / Docker

  :   - `mode` (`character` or `NA`) — Current connection mode
        (`"docker"`, `"remote"` or not configured). Default: `NA`.

      - `docker_port` (`character`) — Local port used for the GROBID
        Docker container. Default: `"8070"`.

      - `docker_container_id` (`character` or `NA`) — Identifier of the
        active GROBID Docker container. Default: `NA`.

      - `docker_image` (`character`) — Base name of the GROBID Docker
        image (before adding the version tag). Default:
        `"lfoppiano/grobid:"`.

      - `grobid_version` (`character`) — GROBID version used for the
        Docker tag. Default: `"0.9.0"`.

      - `grobid_model_type` (`character` or `NA`) — Variant of the
        GROBID model (`"crf"` or `"full"`). Default: `NA`.

      - `server_url` (`character` or `NA`) — URL of the currently
        configured GROBID server (local or remote). Default: `NA`.

  Remote connection

  :   - `remote_default_url` (`list`) — Structure nested by model type
        (`"crf"`, `"full"`), each associated with a `character` vector
        of default remote server URLs.

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

- verbose:

  `logical`. If `TRUE` (default), displays a confirmation message (or a
  warning for unknown names).

## Value

Invisibly returns the updated internal environment.

## See also

[`checkrefr_env_status()`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_env_status.md)
to view the currently configured values,
[`checkrefr_set_defaults()`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_set_defaults.md)
to modify these default values,
[`grobid_check_requirements()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_check_requirements.md).

## Examples

``` r
# Complete reset of the CheckrefR environment
checkrefr_env_reset()
#> ✔ Checkrefr environment fully reset.

# Targeted reset of some OpenAlex parameters
checkrefr_env_reset(fields = c("oa_min_threshold", "oa_w_title"))
#> ✔ Parameter(s) reset: "oa_min_threshold" and "oa_w_title"

# Silent reset (no console message)
checkrefr_env_reset(fields = "timeout", verbose = FALSE)

# An unknown variable name is ignored with a warning
checkrefr_env_reset(fields = c("timeout", "variable_inexistante"))
#> ! Unknown parameter(s), ignored: "variable_inexistante"
#> ✔ Parameter(s) reset: "timeout"
```

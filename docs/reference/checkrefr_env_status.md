# Display the status of the internal checkrefr environment

Displays in the console a formatted summary of the current state of the
internal package environment (`.checkrefr_env`). It is possible to
restrict the display to one or more specific variables via the `var`
argument.

## Usage

``` r
checkrefr_env_status(var = NULL)
```

## Arguments

- var:

  A vector of type `character` containing the name(s) of the internal
  variables to display. Default: `NULL` (all variables of the internal
  environment are displayed). The available variables are:

  `mode`

  :   Active GROBID connection mode: `"docker"`, `"remote"` or `NA` if
      not configured.

  `docker_port`

  :   Local port used by the GROBID Docker container (character string,
      e.g. `"8070"`).

  `docker_container_id`

  :   Identifier of the currently active GROBID Docker container, or
      `NA` if none.

  `docker_image`

  :   Name of the default GROBID Docker image used (e.g.
      `"lfoppiano/grobid:"`).

  `grobid_version`

  :   GROBID version used or detected (e.g. `"0.9.0"`).

  `grobid_model_type`

  :   Variant of the GROBID model (`"crf"`, `"full"` or `NA` if not
      specified).

  `server_url`

  :   URL of the currently configured GROBID server (local or remote).

  `remote_default_url`

  :   Named list (`crf`/`full`) of default remote GROBID server URLs.

  `timeout`

  :   Maximum timeout (in seconds) for GROBID network/API calls.

  `max_workers`

  :   Maximum number of parallel processes used when processing multiple
      files.

  `oa_probable_threshold`

  :   Global score threshold above which an OpenAlex candidate is
      considered "probable".

  `oa_min_threshold`

  :   Minimal global score threshold required to retain an OpenAlex
      candidate.

  `oa_doi_threshold`

  :   Title score threshold from which a match via DOI is considered
      confirmed.

  `oa_w_title`

  :   Weight of the title score in the global OpenAlex matching score.

  `oa_w_authors`

  :   Weight of the authors score in the global OpenAlex matching score.

  `oa_w_year`

  :   Weight of the year score in the global OpenAlex matching score.

  `oa_max_candidates`

  :   Maximum number of OpenAlex candidates presented per reference.

  `oa_api_key`

  :   Key used for the OpenAlex API "polite pool".

  `oa_use_window`

  :   Boolean indicating whether a sliding window is used for author
      matching.

  `oa_window_size`

  :   Size (\\\pm k\\) of the sliding window used for author matching.

  `oa_large_author_threshold`

  :   Threshold above which an author list is considered "large".

  `oa_min_coverage_ratio`

  :   Minimal coverage ratio between author lists to distinguish
      marginal from massive truncation.

  `oa_author_lambda`

  :   Penalty factor applied in case of truncation of the author list.

  `oa_sym_max_diff_abs`

  :   Absolute tolerance for the length difference between author lists
      for the symmetric case.

  `oa_sym_max_diff_prop`

  :   Proportional tolerance for the length difference between author
      lists for the symmetric case.

  `doi_email`

  :   Email address used in the `User-Agent` header when making direct
      requests to `doi.org`.

  `doi_max_retries`

  :   Maximum number of attempts in case of network error or 5xx
      response for DOI requests.

  `doi_retry_backoff`

  :   Initial delay (in seconds) before a new attempt, doubled at each
      successive failure.

## Value

A named list (invisible) containing the values of the requested
variables (or all internal variables if `var = NULL`). This function is
mainly called for its side effect of displaying to the console.

## See also

[`checkrefr_env_reset`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_env_reset.md),
[`checkrefr_set_defaults`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_set_defaults.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Display the entire state of the environment
checkrefr_env_status()

# Display only certain variables
checkrefr_env_status(var = c("mode", "docker_port", "server_url"))
} # }
```

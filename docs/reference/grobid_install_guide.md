# Display an installation guide adapted to the environment

Generates and displays a step-by-step guide based on the detected system
state. If Docker is not installed, guides towards its installation
according to the OS. If there is no Internet connection, indicates
alternative options.

## Usage

``` r
grobid_install_guide(requirements = NULL, test_all_urls = TRUE)
```

## Arguments

- requirements:

  `list` or `NULL` - Result of
  [`grobid_check_requirements()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_check_requirements.md).
  If `NULL`, the diagnostic is relaunched automatically. If provided,
  must contain all the expected fields (see
  [`grobid_check_requirements()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_check_requirements.md)).

- test_all_urls:

  `logical(1)` Used only if `requirements` is `NULL` (the diagnostic is
  then relaunched with this value). If `TRUE`, all configured remote
  servers are tested; if `FALSE`, the test stops at the first reachable
  server found. Default: `TRUE`.

## Value

`invisible(NULL)`

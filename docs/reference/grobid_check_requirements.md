# Check system requirements for using GROBID

Performs a complete diagnostic of the execution environment: operating
system, R version, Internet connection, Docker availability and
connectivity to one or more remote GROBID servers configured by default.
The diagnostic ends with a recommendation of the most suitable operating
mode (`"docker"` or `"remote"`), but this is not mandatory.

## Usage

``` r
grobid_check_requirements(
  verbose = TRUE,
  check_docker = TRUE,
  check_remote = TRUE,
  test_all_urls = TRUE
)
```

## Arguments

- verbose:

  `logical(1)` Display a formatted report in the console. Default:
  `TRUE`.

- check_docker:

  `logical(1)` Include the check of Docker availability (installation,
  daemon startup, active GROBID container). Default: `TRUE`.

- check_remote:

  `logical(1)` Test connectivity to the remote servers configured by
  default (`.checkrefr_env$remote_default_url`). Default: `TRUE`.

- test_all_urls:

  `logical(1)` If `TRUE`, tests all URLs configured for each mode
  (`"crf"` / `"full"`) even after finding a first reachable URL. If
  `FALSE`, the function stops testing as soon as a reachable URL is
  found. Default: `TRUE`. For details concerning the GROBID model type
  (`"crf"` / `"full"`) see the documentation of
  [`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md).

## Value

A `list` (returned invisibly) containing the following fields:

- `os`:

  `character(1)` Detected operating system (`"windows"`, `"macos"`,
  `"linux"` or other).

- `os_version`:

  `character(1)` OS version detail.

- `r_version`:

  `character(1)` R version used.

- `internet_available`:

  `logical(1)` Internet connection detected.

- `docker_installed`:

  `logical(1)` Docker is installed.

- `docker_running`:

  `logical(1)` The Docker daemon is running.

- `docker_version`:

  `character(1)` Docker client version, or `NA` if not installed.

- `grobid_container_active`:

  `logical(1)` A GROBID container is currently active.

- `grobid_container_id`:

  `character(1)` Identifier of the active GROBID container, or `NA`
  otherwise.

- `remote_default_reachable`:

  `logical(1)` At least one default remote server is reachable.

- `remote_reachable_urls`:

  `list` named by mode (`"crf"`, `"full"`) of `character` vectors of
  reachable URLs.

- `recommended_url`:

  `character(1)` Recommended remote URL, or `NA` if none is reachable.

- `recommended_remote_mode`:

  `character(1)` Mode associated with the recommended URL (`"crf"` or
  `"full"`), or `NA`.

- `current_mode`:

  `character(1)` Mode currently configured in the package's internal
  environment.

- `current_url`:

  `character(1)` Currently configured URL.

- `recommended_mode`:

  `character(1)` Recommended global mode: `"docker"`, `"remote"` or `NA`
  if no mode is available.

## See also

[`grobid_install_guide()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_install_guide.md),
[`grobid_docker_check()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_check.md),
[`grobid_server_info()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_server_info.md),
[`checkrefr_set_defaults()`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_set_defaults.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Full diagnostic with console report
grobid_check_requirements()

# Silent diagnostic, without Docker check
req <- grobid_check_requirements(verbose = FALSE, check_docker = FALSE)
req$recommended_mode
} # }
```

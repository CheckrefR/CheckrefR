# Get information about the configured GROBID server

Returns a summary of the current GROBID server configuration (execution
mode, URL, version) and tests in real time the availability of the API
if a server is configured.

## Usage

``` r
grobid_server_info()
```

## Value

An invisible `list` containing:

- `mode`:

  `character`. Current execution mode: `"docker"`, `"remote"` or
  `"not configured"` if no server has yet been started or connected.

- `url`:

  `character`. URL of the configured GROBID server (e.g.
  `"http://localhost:8070"`), or `NA` if no server is configured.

- `api_reachable`:

  `logical`. `TRUE` if the GROBID API responds, `FALSE` otherwise
  (including if no server is configured).

- `grobid_version`:

  `character`. GROBID version returned by the server if it is reachable,
  `NA` otherwise.

- `timeout`:

  `integer`. Delay (in seconds) used for the connection test, taken from
  the current package configuration (see
  [`checkrefr_set_defaults()`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_set_defaults.md)),
  or `NA` if no server is configured.

## See also

[`grobid_check_requirements()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_check_requirements.md)
for a full diagnostic of the environment,
[`grobid_docker_start()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_start.md)
and
[`grobid_remote_connect()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_remote_connect.md)
to configure a server,
[`checkrefr_env_status()`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_env_status.md)
to check the raw state of the package's internal environment.

## Examples

``` r
if (FALSE) { # \dontrun{
grobid_docker_start()
grobid_server_info()
} # }
```

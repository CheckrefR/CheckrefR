# Stop the currently running GROBID Docker container

Stops the GROBID container started via
[`grobid_docker_start()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_start.md).
By default, the function targets the container registered in the
package's internal environment (`.checkrefr_env$docker_container_id`).
An explicit identifier can be provided to stop a different container.

## Usage

``` r
grobid_docker_stop(container_id = NULL, verbose = TRUE)
```

## Arguments

- container_id:

  `character(1)` or `NULL`. Identifier of the container to stop. If
  `NULL`, uses the container currently registered in
  `.checkrefr_env$docker_container_id`. Default: `NULL`.

- verbose:

  `logical(1)` Display progress messages. Default: `TRUE`.

## Value

`invisible(TRUE)` if the container was stopped (or was not active),
`invisible(FALSE)` if no container could be identified.

## Details

Since the container was launched with the `--rm` option (see
[`grobid_docker_start()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_start.md)),
stopping it via `docker stop` also causes its automatic removal by
Docker. The package's internal variables (`docker_container_id`,
`server_url`, `mode`) are reset after stopping.

## See also

[`grobid_docker_start()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_start.md),
[`grobid_docker_check()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_check.md)

## Examples

``` r
if (FALSE) { # \dontrun{
grobid_docker_start()
grobid_docker_stop()
} # }
```

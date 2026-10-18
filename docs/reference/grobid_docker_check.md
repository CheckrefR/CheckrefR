# Check whether Docker is available on the system

Checks that Docker is installed and that the daemon is currently
running. This function is intended to be used directly by the user to
diagnose their Docker environment.

## Usage

``` r
grobid_docker_check(verbose = TRUE)
```

## Arguments

- verbose:

  `logical(1)` Display a confirmation message. Default: `TRUE`.

## Value

`invisible(TRUE)` if Docker is installed and operational. Raises an
error otherwise.

## Examples

``` r
if (FALSE) { # \dontrun{
grobid_docker_check()
} # }
```

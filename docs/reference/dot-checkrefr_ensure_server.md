# Ensure the availability of the GROBID server

Internal function that guarantees a GROBID server is accessible before
any operation requiring the service. Automatically handles Docker mode
(container startup) and remote mode (connection).

## Usage

``` r
.checkrefr_ensure_server(
  mode = .checkrefr_env$mode,
  model_type = .checkrefr_env$grobid_model_type,
  verbose = TRUE
)
```

## Arguments

- mode:

  `character(1)` Connection mode: `"docker"` or `"remote"`. Default:
  value of `.checkrefr_env$mode`, or `"docker"` if not defined.

- verbose:

  `logical(1)` Display progress messages. Default: `TRUE`.

## Value

`invisible(TRUE)` if the server is ready.

# Configure the connection to a remote GROBID server

Configures the package to use a GROBID server accessible via HTTP/HTTPS.

## Usage

``` r
grobid_remote_connect(
  url = NULL,
  model_type = .checkrefr_env$grobid_model_type,
  timeout = .checkrefr_env$timeout,
  verbose = TRUE
)
```

## Arguments

- url:

  `character(1)` URL of the GROBID server. Default:
  `"https://kermitt2-grobid.hf.space"`.

- model_type:

  `character(1)` or `NULL`. Desired GROBID model variant for automatic
  selection of a remote server among
  `.checkrefr_env$remote_default_url`:

  - `NULL` or `""` (default) – treated as `"crf"` for the URL selection
    (default rule, since no preference was expressed).

  - `"crf"` / `"full"` – uses the corresponding URL list.

  See
  [`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md)
  for more information on the `"crf"` or `"full"` model types. Ignored
  if `url` is provided explicitly. Default:
  `.checkrefr_env$grobid_model_type`.

- timeout:

  `integer(1)` Request timeout in seconds. Default: `120`.

- verbose:

  `logical(1)` Display messages. Default: `TRUE`.

## Value

`invisible(TRUE)` if the server responds.

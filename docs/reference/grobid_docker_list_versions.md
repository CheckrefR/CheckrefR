# List available GROBID Docker versions on Docker Hub

Queries the Docker Hub API to retrieve the list of available tags for a
given GROBID image. Allows identifying usable versions with
[`grobid_docker_start()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_start.md)
or by modifying the default parameters via
[`checkrefr_set_defaults()`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_set_defaults.md).

## Usage

``` r
grobid_docker_list_versions(
  repository = NULL,
  page_size = 100L,
  max_pages = 10L,
  verbose = TRUE
)
```

## Arguments

- repository:

  `character(1)` or `NULL`. Name of the Docker Hub repository in the
  form `"namespace/image"`. If `NULL`, automatically resolved from
  `.checkrefr_env$docker_image` (normally `"lfoppiano/grobid"`).
  Default: `NULL`.

- page_size:

  `integer(1)` Number of results per queried page (max allowed by the
  Docker Hub API: 100). Default: `100L`.

- max_pages:

  `integer(1)` Maximum number of pages to browse, to avoid infinite
  pagination. Default: `10L`.

- verbose:

  `logical(1)` Display the formatted list in the console. Default:
  `TRUE`.

## Value

`tibble` (invisibly) with columns `name` (tag), `full_size` (size in
bytes), `last_updated` and `digest`. Sorted by `last_updated`
descending.

## Details

Uses the public unauthenticated endpoint:
<https://hub.docker.com/v2/repositories/grobid/grobid/tags/> (to be
adapted according to the requested `repository`).

## See also

[`grobid_docker_start()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_start.md)

## Examples

``` r
if (FALSE) { # \dontrun{
grobid_docker_list_versions()
grobid_docker_list_versions(repository = "grobid/grobid")
} # }
```

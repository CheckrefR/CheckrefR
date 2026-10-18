# Process a text file of citations via GROBID

Specialized function for the GROBID `"processCitationList"` service.
Reads a text file containing one raw citation per line, then returns
either the raw XML/TEI, or a structured tibble.

Unlike
[`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md)
(which accepts, for the `"processCitationList"` service, either a file
path or a vector of raw text citations), `process_citation_file()` only
accepts a **single path to an existing `.txt` file** on disk. To
directly process a vector of citations without an intermediate file, use
[`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md)
with `service = "processCitationList"`.

## Usage

``` r
process_citation_file(
  file,
  params = list(),
  output_format = "parsed",
  model_type = .checkrefr_env$grobid_model_type,
  verbose = TRUE
)
```

## Arguments

- file:

  `character` Path to an existing text file, containing one raw citation
  per line. Empty lines are ignored.

- params:

  `list` Additional parameters passed to the HTTP form of the GROBID API
  (e.g. `list(consolidateCitations = 1)`). See
  [`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md)
  for details. Default: [`list()`](https://rdrr.io/r/base/list.html).

- output_format:

  `character` Format of the returned result:

  - `"parsed"` — structured result (`tibble`), via
    [`parse_citation_list()`](https://CheckrefR.github.io/CheckrefR/reference/parse_citation_list.md)

  - `"raw"` — raw XML/TEI string

  Default: `"parsed"`.

- model_type:

  `character` or `NA`. GROBID model variant to use for extracting
  bibliographic citations. Two values are possible:

  - `"crf"` — model based solely on a CRF (Conditional Random Field).
    Faster, but generally less accurate than the `"full"` model.

  - `"full"` — model combining CRF and a neural (deep learning) model.
    More accurate, but slower and more resource-intensive.

  This parameter corresponds to the `model.name` / `citation`
  configuration of the GROBID YAML configuration file (see the official
  documentation for details
  [HERE](https://grobid.readthedocs.io/en/latest/Grobid-docker/#configure-using-the-yaml-config-file)).
  If `NA` (default value), in `docker` mode the model without extension
  is used, see the [GROBID dockerHub
  documentation](https://hub.docker.com/r/grobid/grobid/tags) for
  details or use the
  [`grobid_docker_list_versions()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_list_versions.md)
  function. In `remote` mode a `crf` model is used by default. Default:
  `.checkrefr_env$grobid_model_type`, i.e. `NA`.

- verbose:

  `logical` If `TRUE`, displays progress messages in the console (number
  of citations sent, etc.). Default: `TRUE`.

## Value

- `output_format = "parsed"` → structured `tibble` with one row per
  citation (see
  [`parse_citation_list()`](https://CheckrefR.github.io/CheckrefR/reference/parse_citation_list.md)
  for column details)

- `output_format = "raw"` → `character` containing the raw XML/TEI
  returned by GROBID

## See also

[`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md),
[`parse_citation_list()`](https://CheckrefR.github.io/CheckrefR/reference/parse_citation_list.md),
[`grobid_docker_start()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_start.md),
[`grobid_remote_connect()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_remote_connect.md),
[`checkrefr_set_defaults()`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_set_defaults.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Retrieving a sample citation file provided with the package
txt_file <- system.file("extdata", package = "CheckrefR") |>
  list.files(pattern = "\\.txt$", full.names = TRUE)
txt_file <- txt_file[1]

# Processing with structured return (tibble)
citations_df <- process_citation_file(txt_file)

# Processing with raw XML return
citations_xml <- process_citation_file(txt_file, output_format = "raw")
} # }
```

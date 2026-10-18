# Run a GROBID service on multiple files (batch processing)

Applies
[`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md)
to a vector of PDF files (or `.txt` for `"processCitationList"`), with
sequential execution (with optional progress bar) or parallel execution.

Unlike
[`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md),
this function does not accept a vector of raw text citations for
`"processCitationList"`: `files` must always be a vector of paths to
existing files on disk. To directly process citations without an
intermediate file, use
[`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md).

## Usage

``` r
grobid_process_files(
  files,
  service = "processFulltextDocument",
  params = list(),
  output_dir = NULL,
  output_format = "parsed",
  parallel = length(files) > 5L,
  n_workers = .checkrefr_env$max_workers,
  progress = TRUE,
  mode = NULL,
  model_type = .checkrefr_env$grobid_model_type,
  on_error = "warn",
  user_agent = NULL
)
```

## Arguments

- files:

  `character`. Vector of full paths to the files to process. All files
  must exist on disk. PDF files are expected for all services except
  `"processCitationList"` which expects `.txt` files (one citation per
  line).

- service:

  `character`. Name of the GROBID service to use. Accepted values:

  - `"processFulltextDocument"` - full text extraction

  - `"processHeaderDocument"` - header metadata extraction (title,
    authors, abstract, affiliations...)

  - `"processReferences"` - bibliographic reference extraction

  - `"processCitationList"` - parsing of citations from text files (one
    raw citation per line)

  Default: `"processFulltextDocument"`. See the full list of available
  services in the [official GROBID
  documentation](https://grobid.readthedocs.io/en/latest/Grobid-service/).

- params:

  `list`. Additional parameters passed to the HTTP form of the GROBID
  API, applied identically to all files in the batch. Common examples:

  - `consolidateHeader = 1` - metadata enrichment via Crossref

  - `consolidateCitations = 1` - reference enrichment via Crossref

  - `includeRawCitations = 1` - include raw citations in the response

  These parameters correspond to the options accepted by the GROBID
  endpoints. For an exhaustive list, see the [official API
  documentation](https://grobid.readthedocs.io/en/latest/Grobid-service/).
  By default the argument is an empty list:
  [`list()`](https://rdrr.io/r/base/list.html).

- output_dir:

  `character` or `NULL`. If provided, each XML result is saved in this
  folder under the name `{file_name}.tei.xml`. The folder is created
  automatically if it does not exist. In this case, the function returns
  a vector of saved paths (`invisible`). If `NULL`, results are returned
  directly in memory. Default: `NULL`.

- output_format:

  `character`. Format of the results returned when `output_dir = NULL`:

  - `"raw"` - named list (names = `basename(files)`) of raw XML/TEI
    strings

  - `"parsed"` - combined `tibble` (via
    [`dplyr::bind_rows()`](https://dplyr.tidyverse.org/reference/bind_rows.html))

  Default: `"parsed"`.

- parallel:

  `logical` If `TRUE`, processes files in parallel via
  [`future::multisession`](https://future.futureverse.org/reference/multisession.html)
  (see `details`). If `FALSE`, sequential processing. Default:
  `length(files) > 5L`.

- n_workers:

  `integer` Number of workers to use in parallel mode. Automatically
  capped at `max(1, parallel::detectCores() - 1)`. For remote mode, a
  low value is recommended to avoid overloading the server. Default:
  `.checkrefr_env$max_workers` i.e. 4.

- progress:

  `logical` Display a progress bar (sequential mode only). Default:
  `TRUE`.

- mode:

  `character` or `NULL`. Connection mode to the GROBID server:
  `"docker"` or `"remote"`. If `NULL`, uses the mode currently
  registered in the package's internal environment (`"docker"` by
  default if not configured). Default: `NULL`. **Note on internal
  configuration:** to persistently modify the mode or other global
  variables (port, timeout, etc.) for your R session, use
  [`checkrefr_set_defaults()`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_set_defaults.md).

- model_type:

  `character` or `NA`. GROBID model variant to use for bibliographic
  citation extraction. Two values are possible:

  - `"crf"` - model based solely on a CRF (Conditional Random Field).
    Faster, but generally less accurate than the `"full"` model.

  - `"full"` - model combining CRF and a neural (deep learning) model.
    More accurate, but slower and more resource intensive.

  This parameter corresponds to the `model.name` / `citation`
  configuration in GROBID's YAML config file (see the official
  documentation for details
  [HERE](https://grobid.readthedocs.io/en/latest/Grobid-docker/#configure-using-the-yaml-config-file)).
  If `NA` (default value), in `docker` mode the sensible default model
  is used, see the [GROBID dockerHub
  documentation](https://hub.docker.com/r/grobid/grobid/tags) for
  details or use the function
  [`grobid_docker_list_versions()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_list_versions.md).
  In `remote` mode a `crf` model is used by default. Default:
  `.checkrefr_env$grobid_model_type`, i.e. `NA`.

- on_error:

  `character` Behavior in case of an error on a file:

  - `"warn"` - issues a warning and continues with the following files
    (the failing file produces `NA` in the results)

  - `"stop"` - immediately stops processing

  Default: `"warn"`.

- user_agent:

  `character` or `NULL`. Custom User-Agent string to send with each HTTP
  request to the GROBID API. Default: `NULL`.

## Value

- `output_dir` provided -\> vector of saved paths
  (`invisible(character)`)

- `output_format = "raw"` -\> named list (names = `basename(files)`) of
  XML strings, or `NA_character_` for failing files

- `output_format = "parsed"` -\> combined `tibble` with a `source_file`
  column, or `invisible(NULL)` if no parsed result is available

## Details

The availability of the GROBID server (Docker or remote) is checked only
once before batch processing (see
[`grobid_docker_start()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_start.md)
and
[`grobid_remote_connect()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_remote_connect.md)).

In case of an error on a given file, the behavior depends on `on_error`:

- `"warn"` (default) - the failing file produces `NA_character_` in the
  results, a warning is issued, and processing of the following files
  continues normally.

- `"stop"` - processing stops immediately upon the first error
  encountered.

When `parallel = TRUE` and `n_workers > 1`, processing is distributed
via
[`future::multisession`](https://future.futureverse.org/reference/multisession.html)
(package future.apply). The sequential plan is automatically restored at
the end of execution, even in case of error. The effective number of
workers is capped at `parallel::detectCores() - 1`, i.e. the number of
processor cores minus 1, regardless of the `n_workers` value provided,
in order to preserve at least one core for the system.

The `params` parameter is applied identically to all files in the batch;
it is not possible to specify different parameters per file within a
single call.

## References

Official GROBID API documentation:
<https://grobid.readthedocs.io/en/latest/Grobid-service/>

## See also

[`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md),
[`grobid_docker_start()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_start.md),
[`grobid_remote_connect()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_remote_connect.md),
[`parse_fulltext()`](https://CheckrefR.github.io/CheckrefR/reference/parse_fulltext.md),
[`parse_header()`](https://CheckrefR.github.io/CheckrefR/reference/parse_header.md),
[`parse_references()`](https://CheckrefR.github.io/CheckrefR/reference/parse_references.md),
[`parse_citation_list()`](https://CheckrefR.github.io/CheckrefR/reference/parse_citation_list.md),
[`checkrefr_set_defaults()`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_set_defaults.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Example of a batch workflow using the package's example files

# 1. Retrieve example PDFs provided with the package
pdf_files <- system.file("extdata", package = "CheckrefR") |>
  list.files(pattern = "\\.pdf$", full.names = TRUE)

# 2. Start the GROBID server (Docker mode)
grobid_docker_start()

# 3. Sequential processing with progress bar, parsed result
fulltext_df <- grobid_process_files(
  files         = pdf_files,
  service       = "processFulltextDocument",
  output_format = "parsed"
)

# 4. Parallel processing with saving to disk
grobid_process_files(
  files      = pdf_files,
  service    = "processReferences",
  output_dir = tempdir(),
  parallel   = TRUE,
  n_workers  = 2L
)

# 5. Cleanly stop the Docker container
grobid_docker_stop()
} # }
```

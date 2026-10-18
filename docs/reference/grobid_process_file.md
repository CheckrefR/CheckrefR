# Run a GROBID service on a single file

Sends a file (or, for the `"processCitationList"` service, the
possibility of using a vector of raw text citations) to the GROBID API
and returns the result as raw (XML/TEI) or parsed. Supports the four
main GROBID services: full text extraction, header metadata extraction,
bibliographic reference extraction, and parsing of raw text citation
lists.

If no GROBID server is active (Docker or remote), the function attempts
to automatically start/validate the connection via
[`grobid_docker_start()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_start.md)
or
[`grobid_remote_connect()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_remote_connect.md)
before sending the request (see argument `.ensure_server`).

## Usage

``` r
grobid_process_file(
  file,
  service = "processFulltextDocument",
  params = list(),
  output_dir = NULL,
  output_format = "parsed",
  mode = NULL,
  model_type = .checkrefr_env$grobid_model_type,
  verbose = TRUE,
  .ensure_server = TRUE,
  user_agent = NULL
)
```

## Arguments

- file:

  `character` - Full path to the file to process. PDF files are expected
  for all services except `"processCitationList"` which expects a `.txt`
  file (one citation per line). For this service only, `file` can also
  be a vector of raw text citations (each element being a citation).

- service:

  `character` Name of the GROBID service to use. Accepted values:

  - `"processFulltextDocument"` - full text extraction

  - `"processHeaderDocument"` - header metadata extraction (title,
    authors, abstract, affiliations...)

  - `"processReferences"` - bibliographic reference extraction

  - `"processCitationList"` - parsing of citations from a text file or a
    vector of raw citations (one citation per line)

  Default: `"processFulltextDocument"`. See the full list of available
  services in the [official GROBID
  documentation](https://grobid.readthedocs.io/en/latest/Grobid-service/).

- params:

  `list` Additional parameters passed to the HTTP form of the GROBID
  API. Common examples:

  - `consolidateHeader = 1` - metadata enrichment via Crossref

  - `consolidateCitations = 1` - reference enrichment via Crossref

  - `includeRawCitations = 1` - include raw citations in the response

  These parameters correspond to the options accepted by the GROBID
  endpoints. For an exhaustive list, see the [official API
  documentation](https://grobid.readthedocs.io/en/latest/Grobid-service/).
  By default the argument is an empty list:
  [`list()`](https://rdrr.io/r/base/list.html).

- output_dir:

  `character` or `NULL`. If provided, the XML result is saved in this
  folder under the name `{file_name}.tei.xml` (or `citations.tei.xml` if
  `file` is a citation vector). The folder is created automatically if
  it does not exist. In this case, the function returns the path of the
  saved file (`invisible`). If `NULL`, the result is returned directly.
  Default: `NULL`.

- output_format:

  `character` Format of the result returned when `output_dir = NULL`:

  - `"raw"` - raw XML/TEI string

  - `"parsed"` - structured result (`tibble`)

  Default: `"parsed"`.

- mode:

  `character` or `NULL`. Connection mode to the GROBID server:
  `"docker"` or `"remote"`. If `NULL`, the function uses the
  configuration stored in the package's internal environment (default
  `"docker"` if not configured). Default: `NULL`. **Note on internal
  configuration:** To persistently modify the mode or other global
  variables (port, timeout, etc.) for your R session, use the function
  [`checkrefr_set_defaults`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_set_defaults.md).

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

- verbose:

  `logical` If `TRUE`, displays progress messages in the console.
  Default: `TRUE`.

- .ensure_server:

  `logical` If `TRUE`, checks and automatically starts the GROBID server
  (Docker or remote) before running the request. Disable (`FALSE`) only
  when the server availability has already been validated upstream (e.g.
  repeated calls from
  [`grobid_process_files()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_files.md)).
  Default: `TRUE`.

- user_agent:

  `character` or `NULL`. Custom User-Agent string to send with the HTTP
  request to the GROBID API. Default: `NULL`.

## Value

The return type depends on the arguments:

- `output_dir` provided -\> path of the saved `.tei.xml` file
  (`invisible(character)`)

- `output_format = "raw"` -\> `character` containing the XML/TEI

- `output_format = "parsed"` -\> `tibble` or `data.frame` depending on
  the service, with a `source_file` column

- On failure -\> `invisible(NA_character_)` with a warning

## References

Official GROBID API documentation:
<https://grobid.readthedocs.io/en/latest/Grobid-service/>

## See also

[`grobid_process_files()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_files.md),
[`grobid_docker_start()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_start.md),
[`grobid_remote_connect()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_remote_connect.md),
[`parse_fulltext()`](https://CheckrefR.github.io/CheckrefR/reference/parse_fulltext.md),
[`parse_header()`](https://CheckrefR.github.io/CheckrefR/reference/parse_header.md),
[`parse_references()`](https://CheckrefR.github.io/CheckrefR/reference/parse_references.md),
[`parse_citation_list()`](https://CheckrefR.github.io/CheckrefR/reference/parse_citation_list.md),[`checkrefr_set_defaults()`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_set_defaults.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Example of a full workflow using the package's example files

# 1. Retrieve an example PDF provided with the package
pdf_file <- system.file("extdata", package = "CheckrefR") |>
  list.files(pattern = "\\.pdf$", full.names = TRUE) |>
  (\(x) x[1])()

# 2. Start the GROBID server in Docker mode (optional)
grobid_docker_start()

# 3. Full text extraction, parsed result
fulltext <- grobid_process_file(
  file          = pdf_file,
  service       = "processFulltextDocument",
  params        = list(consolidateHeader = 1),
  output_format = "parsed"
)

# 4. Extraction of bibliographic references from the same document
refs <- grobid_process_file(
  file          = pdf_file,
  service       = "processReferences",
  params        = list(consolidateHeader = 1),
  output_format = "parsed"
)

# 5. Processing a raw citations file (.txt) provided as an example
txt_file <- system.file("extdata", package = "CheckrefR") |>
  list.files(pattern = "\\.txt$", full.names = TRUE) |>
  (\(x) x[1])()

citations_parsed <- grobid_process_file(
  file          = txt_file,
  service       = "processCitationList",
  params        = list(consolidateHeader = 1),
  output_format = "parsed"
)

# 6. Cleanly stop the Docker container
grobid_docker_stop()
} # }
```

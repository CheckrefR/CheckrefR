
# 05_grobid_run.R
# Execution of GROBID services - single file, list, folder


#' Run a GROBID service on a single file
#'
#' @description
#' Sends a file (or, for the `"processCitationList"` service, the possibility
#' of using a vector of raw text citations) to the GROBID API and
#' returns the result as raw (XML/TEI) or parsed. Supports
#' the four main GROBID services: full text extraction,
#' header metadata extraction, bibliographic reference extraction, and parsing
#' of raw text citation lists.
#'
#' If no GROBID server is active (Docker or remote), the function
#' attempts to automatically start/validate the connection via
#' [grobid_docker_start()] or [grobid_remote_connect()] before sending the
#' request (see argument `.ensure_server`).
#'
#' @param file `character` - Full path to the file
#'   to process. PDF files are expected for all services except
#'   `"processCitationList"` which expects a `.txt` file (one citation per line).
#'   For this service only, `file` can
#'   also be a vector of raw text citations (each element
#'   being a citation).
#' @param service `character` Name of the GROBID service to use. Accepted
#'   values:
#'   \itemize{
#'     \item `"processFulltextDocument"` - full text extraction
#'     \item `"processHeaderDocument"` - header metadata extraction
#'       (title, authors, abstract, affiliations...)
#'     \item `"processReferences"` - bibliographic reference extraction
#'     \item `"processCitationList"` - parsing of citations from a text
#'       file or a vector of raw citations (one citation per line)
#'   }
#'   Default: `"processFulltextDocument"`.
#'   See the full list of available services in the
#'   [official GROBID documentation](https://grobid.readthedocs.io/en/latest/Grobid-service/).
#' @param params `list` Additional parameters passed to the HTTP form of
#'   the GROBID API. Common examples:
#'   \itemize{
#'     \item `consolidateHeader = 1` - metadata enrichment via
#'       Crossref
#'     \item `consolidateCitations = 1` - reference enrichment via
#'       Crossref
#'     \item `includeRawCitations = 1` - include raw citations in the
#'       response
#'   }
#'   These parameters correspond to the options accepted by the GROBID
#'   endpoints.
#'   For an exhaustive list, see the [official API documentation](https://grobid.readthedocs.io/en/latest/Grobid-service/).
#'   By default the argument is an empty list: `list()`.
#' @param output_dir `character` or `NULL`. If provided, the XML result
#'   is saved in this folder under the name `{file_name}.tei.xml` (or
#'   `citations.tei.xml` if `file` is a citation vector). The folder
#'   is created automatically if it does not exist. In this case, the function
#'   returns the path of the saved file (`invisible`). If `NULL`, the
#'   result is returned directly. Default: `NULL`.
#' @param output_format `character` Format of the result returned when
#'   `output_dir = NULL`:
#'   \itemize{
#'     \item `"raw"` - raw XML/TEI string
#'     \item `"parsed"` - structured result (`tibble`)
#'   }
#'   Default: `"parsed"`.
#' @param mode \code{character} or \code{NULL}. Connection mode to the GROBID server: \code{"docker"} or \code{"remote"}.
#'   If \code{NULL}, the function uses the configuration stored in the package's internal environment
#'   (default \code{"docker"} if not configured). Default: `NULL`.
#'   \strong{Note on internal configuration:} To persistently modify the mode or other
#'   global variables (port, timeout, etc.) for your R session, use the function \code{\link{checkrefr_set_defaults}}.
#' @param model_type `character` or `NA`. GROBID model variant to
#'   use for bibliographic citation extraction. Two
#'   values are possible:
#'   \itemize{
#'     \item `"crf"` - model based solely on a CRF (Conditional
#'       Random Field). Faster, but generally less accurate than
#'       the `"full"` model.
#'     \item `"full"` - model combining CRF and a neural
#'       (deep learning) model. More accurate, but slower and more resource
#'       intensive.
#'   }
#'   This parameter corresponds to the `model.name` /
#'   `citation` configuration in GROBID's YAML config file (see the
#'   official documentation for details [HERE](https://grobid.readthedocs.io/en/latest/Grobid-docker/#configure-using-the-yaml-config-file)).
#'   If `NA` (default value), in `docker` mode the sensible default model is used,
#'   see the [GROBID dockerHub documentation](https://hub.docker.com/r/grobid/grobid/tags)
#'   for details or use the function [grobid_docker_list_versions()].
#'   In `remote` mode a `crf` model is used by default.
#'   Default: `.checkrefr_env$grobid_model_type`, i.e. `NA`.
#' @param user_agent `character` or `NULL`. Custom User-Agent string
#'   to send with the HTTP request to the GROBID API. Default: `NULL`.
#' @param verbose `logical` If `TRUE`, displays progress messages
#'   in the console. Default: `TRUE`.
#' @param .ensure_server `logical` If `TRUE`, checks and automatically
#'   starts the GROBID server (Docker or remote) before running the
#'   request. Disable (`FALSE`) only when the server availability
#'   has already been validated upstream (e.g. repeated calls from
#'   [grobid_process_files()]). Default: `TRUE`.
#'
#' @return
#' The return type depends on the arguments:
#' \itemize{
#'   \item `output_dir` provided -> path of the saved `.tei.xml` file
#'     (`invisible(character)`)
#'   \item `output_format = "raw"` -> `character` containing the XML/TEI
#'   \item `output_format = "parsed"` -> `tibble` or `data.frame` depending on the
#'     service, with a `source_file` column
#'   \item On failure -> `invisible(NA_character_)` with a warning
#' }
#'
#' @references
#' Official GROBID API documentation:
#' \url{https://grobid.readthedocs.io/en/latest/Grobid-service/}
#'
#' @seealso [grobid_process_files()], [grobid_docker_start()],
#'   [grobid_remote_connect()], [parse_fulltext()], [parse_header()],
#'   [parse_references()], [parse_citation_list()],[checkrefr_set_defaults()]
#'
#' @examples
#' \dontrun{
#' # Example of a full workflow using the package's example files
#'
#' # 1. Retrieve an example PDF provided with the package
#' pdf_file <- system.file("extdata", package = "CheckrefR") |>
#'   list.files(pattern = "\\.pdf$", full.names = TRUE) |>
#'   (\(x) x[1])()
#'
#' # 2. Start the GROBID server in Docker mode (optional)
#' grobid_docker_start()
#'
#' # 3. Full text extraction, parsed result
#' fulltext <- grobid_process_file(
#'   file          = pdf_file,
#'   service       = "processFulltextDocument",
#'   params        = list(consolidateHeader = 1),
#'   output_format = "parsed"
#' )
#'
#' # 4. Extraction of bibliographic references from the same document
#' refs <- grobid_process_file(
#'   file          = pdf_file,
#'   service       = "processReferences",
#'   params        = list(consolidateHeader = 1),
#'   output_format = "parsed"
#' )
#'
#' # 5. Processing a raw citations file (.txt) provided as an example
#' txt_file <- system.file("extdata", package = "CheckrefR") |>
#'   list.files(pattern = "\\.txt$", full.names = TRUE) |>
#'   (\(x) x[1])()
#'
#' citations_parsed <- grobid_process_file(
#'   file          = txt_file,
#'   service       = "processCitationList",
#'   params        = list(consolidateHeader = 1),
#'   output_format = "parsed"
#' )
#'
#' # 6. Cleanly stop the Docker container
#' grobid_docker_stop()
#' }
#'
#' @importFrom cli cli_alert_info cli_alert_success cli_warn
#' @importFrom tools file_path_sans_ext
#' @export
grobid_process_file <- function(
    file,
    service       = "processFulltextDocument",
    params        = list(),
    output_dir    = NULL,
    output_format = "parsed",
    mode          = NULL,
    model_type     = .checkrefr_env$grobid_model_type,
    verbose       = TRUE,
    .ensure_server= TRUE,
    user_agent    = NULL
) {

  # -- Resolve model type

  model_type <- .checkrefr_normalize_model_type(model_type)

  # -- Resolve mode

  if (is.null(mode)) {
    env_mode <- .checkrefr_env$mode
    mode <- if (!is.na(env_mode)) env_mode else "docker"
  } else {
    mode <- match.arg(mode, c("docker", "remote"))
  }

  # -- Validate service and file (also handles the citation vector case)
  .checkrefr_check_service(service)
  .checkrefr_check_file(file, service)

  if (service %in% c("processCitationList", "processReferences")) {
    if (!"includeRawCitations" %in% names(params)) {
      params$includeRawCitations <- 1
    }
  }

  # -- Convert to temporary file ONLY if citation vector
  is_citation_vector <- service == "processCitationList" &&
    !(length(file) == 1L && file.exists(file))

  raw_references <- NULL

  if (is_citation_vector) {
    raw_references <- file[nzchar(trimws(file))]
    file_path <- tempfile(fileext = ".txt")
    writeLines(raw_references, file_path, useBytes = TRUE, sep = "\n")
    on.exit(unlink(file_path), add = TRUE)
  } else {
    file_path <- file
    if (service == "processCitationList" && file.exists(file_path)) {
      raw_references <- readLines(file_path, warn = FALSE)
      raw_references <- raw_references[nzchar(trimws(raw_references))]
    }
  }

  output_format <- match.arg(output_format, c("raw", "parsed"))

  # -- Validate and start server if needed
  if (.ensure_server) {
    .checkrefr_ensure_server(mode = mode, model_type = model_type, verbose = verbose)
  }

  if (verbose) {
    label <- if (is_citation_vector) {
      sprintf("%d citation(s)", length(raw_references))
    } else {
      basename(file_path)
    }
    cli::cli_alert_info(
      "Processing {.val {label}} via {.val {service}}..."
    )
  }

  # -- API call
  xml_result <- .grobid_retry_call(
    endpoint   = service,
    file_path  = file_path,
    params     = params,
    user_agent = user_agent
  )

  if (is.na(xml_result)) {
    cli::cli_warn("No result for {.val {if (is_citation_vector) 'the citation vector' else file_path}}.")
    return(invisible(NA_character_))
  }

  # -- Save (only relevant if actual file; kept as-is)
  if (!is.null(output_dir)) {
    if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)


    out_name <- if (is_citation_vector) "citations" else tools::file_path_sans_ext(basename(file_path))
    out_file <- file.path(output_dir, paste0(out_name, ".tei.xml"))
    writeLines(xml_result, out_file, useBytes = TRUE)
    if (verbose) cli::cli_alert_success("Saved: {.path {out_file}}")
    return(invisible(xml_result))
  }

  # -- Return
  if (output_format == "parsed") {
    return(.grobid_dispatch_parse(service        = service,
                                  xml_text       = xml_result,
                                  source_file    = file_path,
                                  raw_references = raw_references))
  }

  xml_result
}



# Internal constants


checkrefr_valid_services <- names(.checkrefr_api_endpoints)


# Internal validation helpers


.checkrefr_check_service <- function(service) {
  if (!service %in% checkrefr_valid_services) {
    cli::cli_abort(c(
      "Unknown service: {.val {service}}.",
      "i" = "Accepted values: {.val {checkrefr_valid_services}}"
    ))
  }
}

.checkrefr_expected_ext <- function(service) {
  if (service == "processCitationList") "\\.txt$" else "\\.pdf$"
}

.checkrefr_check_file <- function(file, service) {

  # -- processCitationList case: file can be a single path OR a vector of citations
  if (service == "processCitationList") {

    # Case 1: single path to an existing file -> standard validation
    if (length(file) == 1L && file.exists(file)) {
      ext_pattern <- .checkrefr_expected_ext(service)
      if (!grepl(ext_pattern, file, ignore.case = TRUE)) {
        cli::cli_abort(c(
          "Incorrect extension for service {.val {service}}.",
          "i" = "Expected extension: {.val '.txt'}",
          "x" = "File provided: {.path {file}}"
        ))
      }
      return(invisible(TRUE))
    }

    # Case 2: vector with several elements -> check that NONE is an existing file
    existing <- file.exists(file)
    if (any(existing)) {
      cli::cli_abort(c(
        "The vector provided for {.val service} mixes citations and file paths, or contains several files.",
        "i" = "Provide either a single path to a .txt file, or a vector of text citations (no element should be an existing file path).",
        "x" = "Element(s) detected as existing file(s): {.path {file[existing]}}"
      ))
    }

    # Case 3: valid citation vector
    if (all(!nzchar(trimws(file)))) {
      cli::cli_abort("The provided citation vector is empty or contains only empty strings.")
    }
    return(invisible(TRUE))
  }

  # -- Standard case (other services): single file path required
  if (length(file) != 1L) {
    cli::cli_abort(c(
      "The service {.val {service}} requires a single file path.",
      "x" = "Vector of length {length(file)} provided."
    ))
  }

  if (!file.exists(file)) {
    cli::cli_abort("File not found: {.path {file}}")
  }

  ext_pattern <- .checkrefr_expected_ext(service)
  if (!grepl(ext_pattern, file, ignore.case = TRUE)) {
    expected <- ".pdf"
    cli::cli_abort(c(
      "Incorrect extension for service {.val {service}}.",
      "i" = "Expected extension: {.val {expected}}",
      "x" = "File provided: {.path {file}}"
    ))
  }
}


# Central internal function: HTTP call


#' Low-level call to the GROBID API
#'
#' @param endpoint `character(1)` Endpoint key.
#' @param file_path `character(1)` Path to the file.
#' @param params `list` Additional form parameters.
#' @param timeout `integer(1)` Timeout in seconds.
#' @param is_text `logical(1)` Send as a text field.
#' @return `character(1)` Raw TEI XML or `NA_character_`.
#' @importFrom cli cli_warn
#' @importFrom curl form_file
#' @importFrom httr2 request req_method req_timeout req_headers req_body_form req_body_multipart req_user_agent req_perform resp_status resp_body_string
#' @noRd
.grobid_call_api <- function( #Potential issue with user_agent integration, to be implemented in this function
  endpoint,
  file_path,
  params   = list(),
  timeout  = .checkrefr_env$timeout,
  is_text  = FALSE,
  user_agent = NULL
) {
  ep  <- .checkrefr_api_endpoints[[endpoint]]
  url <- paste0(.checkrefr_env$server_url, ep$path)

  # -- Systematic resolution of the User-Agent (auto or custom)
  effective_user_agent <- .build_grobid_user_agent(user_agent)

  # Building the multipart body
  # if (is_text) {
  #
  #   citations <- readLines(file_path, warn = FALSE)
  #
    # if (length(citations) == 0 || all(trimws(citations) == "")) {
    #   cli::cli_warn("The file {.path {file_path}} is empty.")
    #   return(NA_character_)
    # }
  #
    # req <- httr2::request(url) |>
    #   httr2::req_method(.checkrefr_api_endpoints[[endpoint]]$method) |>
    #   httr2::req_timeout(timeout) |>
    #   httr2::req_headers(
    #     Accept = "application/xml"
    #   ) |>
    #   httr2::req_body_form(
    #     citations = citations,
    #     .multi = "explode"
    #   )

  if (is_text) {

    # Reading individual quotes from the temporary file
    citations <- readLines(file_path, warn = FALSE)
    citations <- citations[nzchar(trimws(citations))]

    if (length(citations) == 0 || all(trimws(citations) == "")) {
      cli::cli_warn("The file {.path {file_path}} is empty.")
      return(NA_character_)
    }

    # Preparing fields for raw citations
    body_fields <- c(
      setNames(as.list(citations), rep("citations", length(citations))),
      params
    )

    # Generating the httr2 request
    req <- httr2::request(url) |>
      httr2::req_method(ep$method) |>
      httr2::req_timeout(timeout) |>
      httr2::req_headers(Accept = "application/xml") |>
      httr2::req_body_form(!!!body_fields)

  } else {
    body_fields <- c(
      list(input = curl::form_file(file_path)),
      # params
      lapply(params, as.character)
    )
    req <- httr2::request(url) |>
      httr2::req_method(.checkrefr_api_endpoints[[endpoint]]$method) |>
      httr2::req_timeout(timeout) |>
      httr2::req_headers(Accept = "application/xml") |>
      httr2::req_body_multipart(!!!body_fields)
  }

  if (!is.null(user_agent) && nzchar(trimws(user_agent))) {
    req <- httr2::req_user_agent(req, effective_user_agent)
  }

  resp <- tryCatch(
    httr2::req_perform(req),
    error = function(e) {
      cli::cli_warn("Network error for {.path {file_path}}: {conditionMessage(e)}")
      return(NULL)
    }
  )

  if (is.null(resp)) return(NA_character_)

  status <- httr2::resp_status(resp)

  if (status == 200L) {
    return(httr2::resp_body_string(resp))
  }

  if (status == 204L) {
    cli::cli_warn("GROBID produced no result for {.path {file_path}} (HTTP 204).")
    return(NA_character_)
  }

  if (status == 503L) {
    # Flagged as a special condition for retry
    stop(structure(
      list(message = "HTTP 503", status = 503L, call = NULL),
      class = c("grobid_503", "error", "condition")
    ))
  }

  cli::cli_warn(
    "Unexpected HTTP response {status} for {.path {file_path}}."
  )
  NA_character_
}


# Wrapper with retry


#' GROBID call with automatic retry on 503 error
#'
#' @param endpoint `character(1)`
#' @param file_path `character(1)`
#' @param params `list`
#' @param max_retries `integer(1)` Default: 3.
#' @param retry_wait `integer(1)` Seconds between attempts. Default: 10.
#' @return `character(1)` Raw TEI XML or `NA_character_`.
#' @importFrom cli cli_alert_warning cli_warn
#' @noRd
.grobid_retry_call <- function(
    endpoint,
    file_path,
    params      = list(),
    max_retries = 3L,
    retry_wait  = 10L,
    user_agent  = NULL
) {
  attempt <- 0L

  repeat {
    attempt <- attempt + 1L

    result <- tryCatch(
      .grobid_call_api(
        endpoint  = endpoint,
        file_path = file_path,
        params    = params,
        is_text   = (endpoint == "processCitationList"),
        user_agent = user_agent
      ),
      grobid_503 = function(e) {
        if (attempt >= max_retries) {
          cli::cli_warn(c(
            "GROBID server busy (HTTP 503) after {max_retries} attempts.",
            "i" = "File: {.path {file_path}}"
          ))
          return(NA_character_)
        }
        cli::cli_alert_warning(
          "Server busy (503) - retrying in {retry_wait}s \\
          ({attempt}/{max_retries})..."
        )
        Sys.sleep(retry_wait)
        return("__retry__")
      }
    )

    if (!identical(result, "__retry__")) return(result)
  }
}



# Dispatch to parse_* functions

.grobid_dispatch_parse <- function(service, xml_text, source_file, raw_references = NULL) {
  fn <- switch(service,
               "processFulltextDocument" = parse_fulltext,
               "processHeaderDocument"   = parse_header,
               "processReferences"       = parse_references,
               "processCitationList"     = parse_citation_list,
               NULL
  )

  if (is.null(fn)) {
    cli::cli_warn("No parsing function available for {.val {service}}.")
    return(xml_text)
  }

  result <- if (service == "processCitationList") {
    fn(xml_text, raw_references = raw_references)
  } else {
    fn(xml_text)
  }

  # Add source_file column if tibble/data.frame
  if (is.data.frame(result)) {
    result$source_file <- basename(source_file)
  }

  result
}




.checkrefr_sync_env_from_container <- function(verbose = FALSE) {

  container_id <- .checkrefr_env$docker_container_id

  # -- Case where no container is registered: look for an active
  # grobid container via docker ps
  if (is.na(container_id)) {

    # result <- system2(
    #   "docker",
    #   args   = c("ps", "--format", "{{.ID}}|{{.Ports}}|{{.Image}}"),
    #   stdout = TRUE,
    #   stderr = FALSE
    # )

    result <- tryCatch(
      suppressWarnings(system2(
        "docker",
        args   = c("ps", "--format", "{{.ID}}|{{.Ports}}|{{.Image}}"),
        stdout = TRUE,
        stderr = FALSE
      )),
      error = function(e) character(0)
    )

    status <- attr(result, "status")
    if (!is.null(status) && status != 0L) result <- character(0)

    if (length(result) == 0L || nchar(trimws(result[1])) == 0L) {
      if (verbose) {
        cli::cli_alert_info("No active GROBID container found via {.code docker ps}.")
      }
      return(invisible(FALSE))
    }

    # Take the first container found
    parts        <- strsplit(trimws(result[1]), "\\|")[[1]]
    container_id <- parts[1]
    ports_raw    <- parts[2]
    image_raw    <- parts[3]

    # -- Extract the host port from the exposed ports
    # Typical format: "0.0.0.0:8070->8070/tcp"
    port_match <- regmatches(ports_raw, regexpr(":(\\d+)->8070", ports_raw))
    port <- if (length(port_match) > 0L) {
      sub(":(\\d+)->8070", "\\1", port_match)
    } else {
      .checkrefr_env$docker_port
    }

    version_detected <- sub(".*:", "", image_raw)

    .checkrefr_env$docker_container_id <- container_id
    .checkrefr_env$docker_port         <- port
    .checkrefr_env$server_url          <- paste0("http://localhost:", port)
    .checkrefr_env$mode                <- "docker"
    .checkrefr_env$grobid_version      <- version_detected

    if (verbose) {
      cli::cli_alert_info(
        "Environment resynchronized from container {.val {substr(container_id, 1, 12)}}."
      )
    }

    return(invisible(TRUE))
  }

  # -- Registered container: we must verify it is actually still running
  # before trusting it. If it is not active anymore, we stop here and
  # return FALSE without touching server_url/mode: this early return is
  # what prevents the fallback block below from ever running against a
  # container_id that does not correspond to a real running container.
  if (!.checkrefr_container_active()) {
    if (verbose) {
      cli::cli_alert_info(
        "Registered container {.val {substr(container_id, 1, 12)}} is no longer active. \\
        No resynchronization performed."
      )
    }
    return(invisible(FALSE))
  }

  # -- At this point, the container is confirmed active: it is safe to
  # fill in server_url/mode if they were left inconsistent (NA).
  if (is.na(.checkrefr_env$server_url) || is.na(.checkrefr_env$mode)) {
    port <- .checkrefr_env$docker_port
    .checkrefr_env$server_url <- paste0("http://localhost:", port)
    .checkrefr_env$mode       <- "docker"

    if (verbose) {
      cli::cli_alert_info("Environment variables resynchronized (server_url, mode).")
    }
  }

  invisible(TRUE)
}




#' Run a GROBID service on multiple files (batch processing)
#'
#' @description
#' Applies [grobid_process_file()] to a vector of PDF files (or `.txt`
#' for `"processCitationList"`), with sequential execution (with optional progress bar)
#' or parallel execution.
#'
#' Unlike [grobid_process_file()], this function does not accept a
#' vector of raw text citations for `"processCitationList"`:
#' `files` must always be a vector of paths to existing files
#' on disk. To directly process citations without an intermediate
#' file, use [grobid_process_file()].
#'
#'
#' @details
#' The availability of the GROBID server (Docker or remote) is checked only
#' once before batch processing (see [grobid_docker_start()] and
#' [grobid_remote_connect()]).
#'
#' In case of an error on a given file, the behavior depends on
#' `on_error`:
#' \itemize{
#'   \item `"warn"` (default) - the failing file produces `NA_character_`
#'     in the results, a warning is issued, and processing of the
#'     following files continues normally.
#'   \item `"stop"` - processing stops immediately upon the
#'     first error encountered.
#' }
#'
#' When `parallel = TRUE` and `n_workers > 1`, processing is distributed
#' via `future::multisession` (package \pkg{future.apply}). The sequential
#' plan is automatically restored at the end of execution, even in
#' case of error. The effective number of workers is capped at
#' `parallel::detectCores() - 1`, i.e. the number of processor cores minus 1,
#' regardless of the `n_workers` value
#' provided, in order to preserve at least one core for the system.
#'
#' The `params` parameter is applied identically to all
#' files in the batch; it is not possible to specify different
#' parameters per file within a single call.
#'
#' @param files `character`. Vector of full paths to the files to
#'   process. All files must exist on disk. PDF
#'   files are expected for all services except `"processCitationList"`
#'   which expects `.txt` files (one citation per line).
#' @param service `character`. Name of the GROBID service to use. Accepted
#'   values:
#'   \itemize{
#'     \item `"processFulltextDocument"` - full text extraction
#'     \item `"processHeaderDocument"` - header metadata extraction
#'       (title, authors, abstract, affiliations...)
#'     \item `"processReferences"` - bibliographic reference extraction
#'     \item `"processCitationList"` - parsing of citations from
#'       text files (one raw citation per line)
#'   }
#'   Default: `"processFulltextDocument"`.
#'   See the full list of available services in the
#'   [official GROBID documentation](https://grobid.readthedocs.io/en/latest/Grobid-service/).
#' @param params `list`. Additional parameters passed to the HTTP form of
#'   the GROBID API, applied identically to all files in the batch.
#'   Common examples:
#'   \itemize{
#'     \item `consolidateHeader = 1` - metadata enrichment via
#'       Crossref
#'     \item `consolidateCitations = 1` - reference enrichment via
#'       Crossref
#'     \item `includeRawCitations = 1` - include raw citations in the
#'       response
#'   }
#'   These parameters correspond to the options accepted by the GROBID
#'   endpoints.
#'   For an exhaustive list, see the [official API documentation](https://grobid.readthedocs.io/en/latest/Grobid-service/).
#'   By default the argument is an empty list: `list()`.
#' @param output_dir `character` or `NULL`. If provided, each XML
#'   result is saved in this folder under the name `{file_name}.tei.xml`.
#'   The folder is created automatically if it does not exist. In this case, the
#'   function returns a vector of saved paths (`invisible`).
#'   If `NULL`, results are returned directly in memory.
#'   Default: `NULL`.
#' @param output_format `character`. Format of the results returned when
#'   `output_dir = NULL`:
#'   \itemize{
#'     \item `"raw"` - named list (names = `basename(files)`) of raw
#'       XML/TEI strings
#'     \item `"parsed"` - combined `tibble` (via `dplyr::bind_rows()`)
#'   }
#'   Default: `"parsed"`.
#' @param mode `character` or `NULL`. Connection mode to the GROBID server:
#'   `"docker"` or `"remote"`. If `NULL`, uses the mode currently
#'   registered in the package's internal environment (`"docker"` by
#'   default if not configured). Default: `NULL`.
#'   \strong{Note on internal configuration:} to persistently modify
#'   the mode or other global variables (port, timeout,
#'   etc.) for your R session, use [checkrefr_set_defaults()].
#' @param model_type `character` or `NA`. GROBID model variant to
#'   use for bibliographic citation extraction. Two
#'   values are possible:
#'   \itemize{
#'     \item `"crf"` - model based solely on a CRF (Conditional
#'       Random Field). Faster, but generally less accurate than
#'       the `"full"` model.
#'     \item `"full"` - model combining CRF and a neural
#'       (deep learning) model. More accurate, but slower and more resource
#'       intensive.
#'   }
#'   This parameter corresponds to the `model.name` /
#'   `citation` configuration in GROBID's YAML config file (see the
#'   official documentation for details [HERE](https://grobid.readthedocs.io/en/latest/Grobid-docker/#configure-using-the-yaml-config-file)).
#'   If `NA` (default value), in `docker` mode the sensible default model is used,
#'   see the [GROBID dockerHub documentation](https://hub.docker.com/r/grobid/grobid/tags)
#'   for details or use the function [grobid_docker_list_versions()].
#'   In `remote` mode a `crf` model is used by default.
#'   Default: `.checkrefr_env$grobid_model_type`, i.e. `NA`.
#' @param user_agent `character` or `NULL`. Custom User-Agent string
#'   to send with each HTTP request to the GROBID API. Default:
#'   `NULL`.
#' @param parallel `logical` If `TRUE`, processes files in parallel
#'   via `future::multisession` (see `details`). If `FALSE`, sequential
#'   processing. Default: `length(files) > 5L`.
#' @param n_workers `integer` Number of workers to use in
#'   parallel mode. Automatically capped at
#'   `max(1, parallel::detectCores() - 1)`. For remote mode, a low
#'   value is recommended to avoid overloading the server. Default:
#'   `.checkrefr_env$max_workers` i.e. 4.
#' @param progress `logical` Display a progress bar (sequential mode
#'   only). Default: `TRUE`.
#' @param on_error `character` Behavior in case of an error on a file:
#'   \itemize{
#'     \item `"warn"` - issues a warning and continues with the
#'       following files (the failing file produces `NA` in the results)
#'     \item `"stop"` - immediately stops processing
#'   }
#'   Default: `"warn"`.
#'
#' @return
#' \itemize{
#'   \item `output_dir` provided -> vector of saved paths
#'     (`invisible(character)`)
#'   \item `output_format = "raw"` -> named list (names = `basename(files)`)
#'     of XML strings, or `NA_character_` for failing files
#'   \item `output_format = "parsed"` -> combined `tibble` with a
#'     `source_file` column, or `invisible(NULL)` if no parsed result is
#'     available
#' }
#'
#' @references
#' Official GROBID API documentation:
#' \url{https://grobid.readthedocs.io/en/latest/Grobid-service/}
#'
#' @seealso [grobid_process_file()],
#'   [grobid_docker_start()], [grobid_remote_connect()],
#'   [parse_fulltext()], [parse_header()], [parse_references()],
#'   [parse_citation_list()], [checkrefr_set_defaults()]
#'
#' @examples
#' \dontrun{
#' # Example of a batch workflow using the package's example files
#'
#' # 1. Retrieve example PDFs provided with the package
#' pdf_files <- system.file("extdata", package = "CheckrefR") |>
#'   list.files(pattern = "\\.pdf$", full.names = TRUE)
#'
#' # 2. Start the GROBID server (Docker mode)
#' grobid_docker_start()
#'
#' # 3. Sequential processing with progress bar, parsed result
#' fulltext_df <- grobid_process_files(
#'   files         = pdf_files,
#'   service       = "processFulltextDocument",
#'   output_format = "parsed"
#' )
#'
#' # 4. Parallel processing with saving to disk
#' grobid_process_files(
#'   files      = pdf_files,
#'   service    = "processReferences",
#'   output_dir = tempdir(),
#'   parallel   = TRUE,
#'   n_workers  = 2L
#' )
#'
#' # 5. Cleanly stop the Docker container
#' grobid_docker_stop()
#' }
#'
#' @importFrom cli cli_abort cli_alert_info cli_warn
#' @importFrom dplyr bind_rows
#' @importFrom future plan multisession sequential
#' @importFrom future.apply future_lapply
#' @importFrom glue glue
#' @importFrom pbapply pblapply
#' @export
grobid_process_files <- function(
    files,
    service       = "processFulltextDocument",
    params        = list(),
    output_dir    = NULL,
    output_format = "parsed",
    parallel      = length(files) > 5L,
    n_workers     = .checkrefr_env$max_workers,
    progress      = TRUE,
    mode          = NULL,
    model_type    = .checkrefr_env$grobid_model_type,
    on_error      = "warn",
    user_agent    = NULL
) {
  .checkrefr_check_service(service)
  output_format <- match.arg(output_format, c("raw", "parsed"))
  on_error      <- match.arg(on_error, c("warn", "stop"))

  if (length(files) == 0L) {
    cli::cli_abort("The vector {.arg files} is empty.")
  }

  if (is.null(mode)) {
    env_mode <- .checkrefr_env$mode
    mode <- if (!is.na(env_mode)) env_mode else "docker"
  } else {
    mode <- match.arg(mode, c("docker", "remote"))
  }

  .checkrefr_ensure_server(mode = mode, model_type = model_type, verbose = TRUE)


  snapshot <- list(
    server_url        = .checkrefr_env$server_url,
    mode               = .checkrefr_env$mode,
    grobid_model_type  = .checkrefr_env$grobid_model_type,
    docker_port         = .checkrefr_env$docker_port,
    docker_container_id = .checkrefr_env$docker_container_id,
    timeout            = .checkrefr_env$timeout,
    pkg_name           = .checkrefr_env$pkg_name,
    pkg_repo           = .checkrefr_env$pkg_repo,
    grobid_email       = .checkrefr_env$grobid_email
  )

  n_workers <- if (mode == "docker") {
    min(as.integer(n_workers), max(1L, parallel::detectCores() - 1L))
  } else {
    2L
  }

  cli::cli_alert_info(
    "Processing {length(files)} file(s) via {.val {service}}..."
  )

  .process_one <- function(f, snapshot, ...) {

    assign("server_url",       snapshot$server_url,       envir = .checkrefr_env)
    assign("mode",             snapshot$mode,              envir = .checkrefr_env)
    assign("grobid_model_type",snapshot$grobid_model_type, envir = .checkrefr_env)
    assign("docker_port",       snapshot$docker_port,        envir = .checkrefr_env)
    assign("timeout",          snapshot$timeout,           envir = .checkrefr_env)
    assign("pkg_name",         snapshot$pkg_name,          envir = .checkrefr_env)
    assign("pkg_repo",         snapshot$pkg_repo,          envir = .checkrefr_env)
    assign("grobid_email",     snapshot$grobid_email,      envir = .checkrefr_env)

    tryCatch(
      CheckrefR::grobid_process_file(
        file          = f,
        service       = service,
        params        = params,
        output_dir    = output_dir,
        output_format = output_format,
        verbose       = FALSE,
        .ensure_server= FALSE,
        user_agent    = user_agent
      ),
      error = function(e) {
        msg <- glue::glue("Error on {basename(f)}: {conditionMessage(e)}")
        if (on_error == "stop") cli::cli_abort(msg)
        cli::cli_warn(msg)
        NA_character_
      }
    )
  }

  if (parallel && n_workers > 1L) {
    future::plan(future::multisession, workers = n_workers)
    on.exit(future::plan(future::sequential), add = TRUE)

    results <- future.apply::future_lapply(
      files,
      .process_one,
      snapshot = snapshot,          # >> FIX : transmission explicite
      future.seed = TRUE,
      future.packages = "CheckrefR"
    )
  } else {
    if (progress) {
      results <- pbapply::pblapply(files, .process_one, snapshot = snapshot)
    } else {
      results <- lapply(files, .process_one, snapshot = snapshot)
    }
  }

  names(results) <- basename(files)

  if (!is.null(output_dir)) {
    return(invisible(unlist(results)))
  }

  if (output_format == "parsed") {
    parsed <- Filter(is.data.frame, results)
    if (length(parsed) == 0L) {
      cli::cli_warn("No parsed result available.")
      return(invisible(NULL))
    }
    return(dplyr::bind_rows(parsed))
  }

  results
}


#' Normalize the model_type value ("" / NULL / NA -> NA_character_)
#'
#' Shared internal function to standardize the handling of
#' `model_type` throughout the package: an empty string or NULL
#' is systematically reduced to NA_character_, which represents
#' the absence of an explicit choice.
#' @noRd
.checkrefr_normalize_model_type <- function(model_type) {
  if (is.null(model_type) || length(model_type) == 0L) return(NA_character_)
  if (is.na(model_type)) return(NA_character_)
  model_type <- trimws(model_type)
  if (!nzchar(model_type)) return(NA_character_)

  model_type <- match.arg(model_type, c("crf", "full"))
  model_type
}


#' Build the User-Agent header for GROBID calls
#'
#' @description Builds a standardized User-Agent string for HTTP requests
#'   sent to a GROBID server (local or remote). The string includes
#'   the package signature (name, version, repository) as well as, if available,
#'   an optional contact email allowing "polite" identification
#'   with shared remote instances (e.g. HuggingFace Space).
#'   If a custom user_agent is provided as an argument, it is
#'   returned as-is (priority given to the user's explicit customization).
#'
#' @param custom_user_agent character(1) or NULL. Custom User-Agent
#'   provided by the user; if it is not NULL and not empty, it is returned
#'   unmodified and takes precedence over automatic construction.
#'
#' @return character(1). The final User-Agent string to pass to
#'   httr2::req_user_agent().
#'
#' @seealso .build_doi_user_agent
#' @noRd
.build_grobid_user_agent <- function(custom_user_agent = NULL) {

  # -- Absolute priority to the user-agent explicitly provided by the user
  if (!is.null(custom_user_agent) && nzchar(trimws(custom_user_agent))) {
    return(custom_user_agent)
  }

  pkg_name    <- .checkrefr_env$pkg_name
  pkg_repo    <- .checkrefr_env$pkg_repo
  pkg_version <- .checkrefr_pkg_version()

  base <- sprintf("%s/%s (%s)", pkg_name, pkg_version, pkg_repo)

  email <- .checkrefr_env$grobid_email
  if (!is.na(email) && nzchar(trimws(email))) {
    base <- paste0(base, " mailto:", email)
  }

  base
}

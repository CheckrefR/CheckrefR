# Package index

## Environment & Installation Diagnostics

Functions to diagnose the local OS, dependencies, and guide the user
through installation steps.

- [`grobid_check_requirements()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_check_requirements.md)
  : Check system requirements for using GROBID
- [`grobid_install_guide()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_install_guide.md)
  : Display an installation guide adapted to the environment
- [`grobid_server_info()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_server_info.md)
  : Get information about the configured GROBID server

## GROBID Server Management

Manage local Docker containers running GROBID or establish connections
to remote servers.

- [`grobid_docker_check()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_check.md)
  : Check whether Docker is available on the system
- [`grobid_docker_start()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_start.md)
  : Start the GROBID container via Docker
- [`grobid_docker_stop()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_stop.md)
  : Stop the currently running GROBID Docker container
- [`grobid_docker_list_versions()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_list_versions.md)
  : List available GROBID Docker versions on Docker Hub
- [`grobid_remote_connect()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_remote_connect.md)
  : Configure the connection to a remote GROBID server

## Package Configuration & State

View and modify the default values, thresholds, and weights of the
CheckrefR internal environment.

- [`checkrefr_env_status()`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_env_status.md)
  : Display the status of the internal checkrefr environment
- [`checkrefr_env_reset()`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_env_reset.md)
  : Reset the CheckrefR environment to its default values
- [`checkrefr_set_defaults()`](https://CheckrefR.github.io/CheckrefR/reference/checkrefr_set_defaults.md)
  : Modify the default values of the CheckrefR environment
- [`oa_matching_info()`](https://CheckrefR.github.io/CheckrefR/reference/oa_matching_info.md)
  : Get OpenAlex matching parameters information

## Document Processing & Batch Execution

Run GROBID extraction services on individual files, text batches, or
entire directories.

- [`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md)
  : Run a GROBID service on a single file
- [`grobid_process_files()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_files.md)
  : Run a GROBID service on multiple files (batch processing)
- [`process_citation_file()`](https://CheckrefR.github.io/CheckrefR/reference/process_citation_file.md)
  : Process a text file of citations via GROBID

## XML Parsing & Structuring

Extract and parse specific segments of TEI/XML outputs returned by
GROBID into structured data frames.

- [`parse_fulltext()`](https://CheckrefR.github.io/CheckrefR/reference/parse_fulltext.md)
  : Parse the GROBID full-text XML output
- [`parse_header()`](https://CheckrefR.github.io/CheckrefR/reference/parse_header.md)
  : Parse the GROBID header XML output of the document
- [`parse_references()`](https://CheckrefR.github.io/CheckrefR/reference/parse_references.md)
  : Parse the GROBID XML output of bibliographic references
- [`parse_citation_list()`](https://CheckrefR.github.io/CheckrefR/reference/parse_citation_list.md)
  : Parse the GROBID XML output of a citation list

## Reference Validation & Cross-Matching

Query OpenAlex and Crossref to validate reference metadata and filter
results.

- [`validate_references()`](https://CheckrefR.github.io/CheckrefR/reference/validate_references.md)
  : Validate a set of bibliographic references via OpenAlex
- [`deduplicate_references()`](https://CheckrefR.github.io/CheckrefR/reference/deduplicate_references.md)
  : Deduplicate validation results by keeping the best candidate per
  reference
- [`check_doi_exists()`](https://CheckrefR.github.io/CheckrefR/reference/check_doi_exists.md)
  : Check the existence of one or more DOIs

## APA 7 Text Citation Utilities

Functions designed to parse, format, and prepare raw text strings
formatted according to APA 7 rules.

- [`parse_apa_text()`](https://CheckrefR.github.io/CheckrefR/reference/parse_apa_text.md)
  : Parse one or several references in APA 7 format
- [`format_apa_for_validation()`](https://CheckrefR.github.io/CheckrefR/reference/format_apa_for_validation.md)
  : Format APA results for validation pipeline

## Author Similarity Scoring

Fine-grained name-matching metrics and algorithms used inside the
validation pipeline.

- [`compute_author_score()`](https://CheckrefR.github.io/CheckrefR/reference/compute_author_score.md)
  : Compute a global similarity score between two lists of authors
- [`sim_author_pair()`](https://CheckrefR.github.io/CheckrefR/reference/sim_author_pair.md)
  : Compute a similarity score between two author names

## Text Preprocessing Functions

Unicode normalization and string cleaning functions.

- [`remove_diacritics()`](https://CheckrefR.github.io/CheckrefR/reference/remove_diacritics.md)
  : Remove Diacritics and Transliterate Ligatures
- [`to_lower_unicode()`](https://CheckrefR.github.io/CheckrefR/reference/to_lower_unicode.md)
  : Convert Unicode Text to Lowercase

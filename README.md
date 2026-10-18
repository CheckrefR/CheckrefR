# CheckrefR

<!-- badges: start -->

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/CheckrefR/CheckrefR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/CheckrefR/CheckrefR/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/CheckrefR/CheckrefR/graph/badge.svg)](https://app.codecov.io/gh/CheckrefR/CheckrefR)

<!-- badges: end -->

> ⚠️ **Project status**: `CheckrefR` is an **experimental** release (`0.0.0.1`), under active development and not yet submitted to CRAN. The code is covered by automated tests, but this coverage remains partial (see the Codecov badge above). The **computation of matching scores** is currently being revised and has not yet been evaluated through formal tests. See the [Limitations and caution](#limitations-and-caution) section.

## Description

**CheckrefR** is an R package with two complementary goals.

**1. An R client for [GROBID](https://github.com/kermitt2/grobid)** (*GeneRation Of BIbliographic Data*), a tool that reads scientific documents (PDF) and automatically extracts their metadata, full text, and bibliographic references. CheckrefR lets you use it:

- **locally**, via Docker: the package downloads, starts, and stops the GROBID container for you;
- **remotely**, by connecting to an existing GROBID server.

> The remote servers configured by default are **demo** servers: they are shared, sometimes overloaded, and are not suitable for intensive or sensitive use. It is preferable to use GROBID **locally** or to have **your own server**, which the package lets you configure.

**2. A tool for verifying bibliographic references.** `validate_references()` checks references (extracted by GROBID, or read from text in APA 7 format) against the **OpenAlex** and **doi.org** databases: DOI existence, consistency between the DOI and the reference, title search, and computation of configurable similarity scores (title, authors, year).

This second component is designed in the context of **generative artificial intelligence**: language models can produce references of highly variable quality, ranging from pure hallucination to exact references, including approximate references, fabricated DOIs attached to real references (or the reverse), and partially accurate cases. CheckrefR helps spot these situations, **without replacing human verification**.

## Installation

`CheckrefR` is not yet available on CRAN. Install the development version from GitHub:

```r
# install.packages("devtools")
devtools::install_github("CheckrefR/CheckrefR")
```

### Requirements

- [Docker](https://docs.docker.com/get-docker/) (recommended, to run GROBID locally), **or**
- an Internet connection and access to a remote GROBID server.

Reference validation (`validate_references()`) requires an Internet connection (OpenAlex, doi.org), but **not** a GROBID server. An OpenAlex API key and a contact e-mail address are recommended (see the [documentation](https://checkrefr.github.io/CheckrefR/)).

The package ships with example files (PDF and TXT) in `inst/extdata`, which can be used directly after installation (see [Quick start](#quick-start)).

## Quick start

```r
library(CheckrefR)

# 1. Check the environment (Docker, remote servers, etc.)
grobid_check_requirements()

# 2. Get a step-by-step installation guide if needed
grobid_install_guide()

# 3. (Optional) Start GROBID locally via Docker.
#    This step is optional: grobid_process_file() automatically starts or
#    joins a server if necessary (arguments `mode` and `model_type`).
grobid_docker_start()

# 4. Get an example PDF provided with the package
pdf_example <- system.file("extdata", "fpubh-10-1057020.pdf", package = "CheckrefR")

# 5. Extract the full text and metadata
fulltext <- grobid_process_file(
  file    = pdf_example,
  service = "processFulltextDocument"
)

# 6. Extract the bibliographic references
refs <- grobid_process_file(
  file    = pdf_example,
  service = "processReferences"
)

# 7. The container is no longer needed for what follows:
#    validate_references() does not call GROBID.
grobid_docker_stop()

# 8. Validate the references against OpenAlex / doi.org
validated <- validate_references(refs)

# 9. Keep the best candidate for each reference
best <- deduplicate_references(validated)
```

> The **first use** of local mode downloads the GROBID Docker image, which may take some time. This happens again for each new model (`"crf"` or `"full"`) not yet downloaded.

You can also directly process a free-text reference file provided as an example, with or without GROBID:

```r
citation_example <- system.file("extdata", "ref_test.txt", package = "CheckrefR")

# With GROBID (tolerant of varied formats)
parsed_citations <- process_citation_file(file = citation_example)

# Without GROBID, for references in APA 7 format (regular expressions)
apa_refs <- parse_apa_text(citation_example, as_ref_df = TRUE)
```

## Main features

### Data extraction

| Function                                                                            | Description                                                                                                                                                              |
|:----------------------------------------------------------------------------------- |:------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `grobid_process_file()`                                                             | Processes a file (PDF or citations) via one of the four GROBID services (full text, header, references, citation list) and returns a raw (XML) or parsed (table) result. |
| `grobid_process_files()`                                                            | Processes a batch of files, serially or in parallel, with error handling.                                                                                                |
| `process_citation_file()`                                                           | Parses a list of free-text references via the `processCitationList` service.                                                                                             |
| `parse_apa_text()`                                                                  | Extracts title, authors, year, and DOI from **APA 7** references, without GROBID (regular expressions).                                                                  |
| `parse_fulltext()`, `parse_header()`, `parse_references()`, `parse_citation_list()` | Convert a GROBID XML into a data table, depending on the service used.                                                                                                   |

### Reference validation

| Function                                      | Description                                                                                                                                                       |
|:--------------------------------------------- |:----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `validate_references()`                       | Validates references using a dual DOI + title strategy, querying OpenAlex and doi.org, with configurable similarity scores. **Does not require** a GROBID server. |
| `deduplicate_references()`                    | Keeps, for each reference, the best candidate returned by the validation.                                                                                         |
| `check_doi_exists()`                          | Checks the existence and validity of one or more DOIs with doi.org.                                                                                               |
| `compute_author_score()`, `sim_author_pair()` | Compute the similarity between author lists, or between two authors.                                                                                              |
| `oa_matching_info()`                          | Documents the matching parameters used with OpenAlex.                                                                                                             |

### Server and configuration management

| Function                                                                         | Description                                                            |
|:-------------------------------------------------------------------------------- |:---------------------------------------------------------------------- |
| `grobid_check_requirements()`, `grobid_install_guide()`                          | Environment diagnostics and interactive installation guide.            |
| `grobid_docker_start()`, `grobid_docker_stop()`, `grobid_docker_list_versions()` | Management of the local GROBID container and version selection.        |
| `grobid_remote_connect()`, `grobid_server_info()`                                | Connection to a remote server and information about the active server. |
| `checkrefr_set_defaults()`, `checkrefr_env_reset()`                              | Setting and resetting the package's default parameters.                |

## Limitations and caution

- **Experimental version**: the package's functions (names, arguments, result format) and the results they produce may still change from one version to the next.
- **Matching scores**: the current formula is being revised. It has known limitations, notably in the comparison of **authors** (risk of false positives on compound or particle-containing names, and sensitivity to diacritics). More formal tests will be conducted.
- **A score is not proof**: in particular for books, chapters, and conference proceedings (often without a DOI), and for references that are false but close to real ones, **manual verification** remains necessary given the current state of development of the matching score.
- **Demo servers**: to be reserved for trials.

## Example datasets

The package provides example files in `inst/extdata`, accessible via `system.file()`:

```r
# PDF files (scientific articles)
pdf_files <- list.files(
  system.file("extdata", package = "CheckrefR"),
  pattern = "\\.pdf $ ", full.names = TRUE
)

# Text files (lists of APA references)
txt_files <- list.files(
  system.file("extdata", package = "CheckrefR"),
  pattern = "\\.txt $ ", full.names = TRUE
)
```

The `ref_test.txt` file contains 14 test references (exact references, misattributed or fabricated DOIs, nonexistent references, or references close to real ones): it allows you to test the entire pipeline without providing your own documents.

## Documentation

The full documentation is available on the package website: <https://checkrefr.github.io/CheckrefR/>

It includes in particular:

- **Get started**: overview, installation, environment setup (Docker or remote server), first calls.
- **GROBID Server Setup and Administration**: starting, connecting, versions, and default parameters.
- **Document Processing and XML Extraction**: GROBID services, batch processing, `parse_*()`, `parse_apa_text()`.
- **Reference Validation Pipeline and Scoring**: validation pipeline, scoring and its limitations, deduplication.

The documentation for each function is also available via `?function_name` or `help(package = "CheckrefR")`.

## License

This package is distributed under the **GPL-3** license (`GPL (>= 3)`). See the [LICENSE.md](LICENSE.md) file for the full text.

## How to cite

```r
citation("CheckrefR")
```

Pending the release of a stable version, you can cite the project as follows:

> Jollivet, M. (2026). *CheckrefR: Parse Scientific Documents and Validate Citations with 'GROBID'*. R package version 0.0.0.1. https://github.com/CheckrefR/CheckrefR

## Contributing

The project is young and contributions are welcome, particularly in the following areas:

- **Tests**: current coverage is partial (tracked via [Codecov](https://app.codecov.io/gh/CheckrefR/CheckrefR)). **Unit tests** (`testthat`) and **integration tests** are especially appreciated, whether for extraction functions, parsing, or validation.
- Report a bug or suggest a feature via an [issue](https://github.com/CheckrefR/CheckrefR/issues).

To propose a change via a *pull request*:

1. Fork the repository and create a branch dedicated to your contribution.
2. Add or update the tests corresponding to your changes.
3. Make sure `devtools::check()` passes without errors.
4. Clearly describe the changes made in your pull request.

*(This section will be expanded with more detailed instructions, including a code style guide, as the project matures.)*

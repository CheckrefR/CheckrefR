# Get started

![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)

## Introduction

### Goals of CheckrefR

**CheckrefR** pursues two complementary goals.

#### An R client for GROBID

[GROBID](https://github.com/kermitt2/grobid) (*GeneRation Of
BIbliographic Data*) is a machine learning model able to read a document
(typically a PDF of a scientific article) or a list of raw references,
and to extract **structured** information from it: title, authors, year,
journal, DOI, etc.

GROBID works as a **service**: a program that runs somewhere (on your
computer or on a server) and to which you send files in order to get a
result. CheckrefR plays the role of the **client**: it sends your files
to the service, retrieves the response and turns it into R tables that
are ready to use.

Two usage modes are available:

| Mode | Principle | When to use it? |
|:---|:---|:---|
| **Local** (`"docker"`) | GROBID runs on *your* machine, in a Docker container (an isolated “box” that bundles the program). | **Recommended**: fast, private, no volume limit. |
| **Remote** (`"remote"`) | Files are sent to a GROBID server accessible over the Internet. | Troubleshooting, first trials, or if you have your own server. |

⚠️ **Keep in mind.** The remote servers configured by default in the
package are **demonstration servers**: shared, sometimes unavailable or
slow, and with no guarantee of confidentiality for your documents.

It is preferable to **use GROBID locally** or to **have your own
server**. The package lets you configure the server address (see
[`grobid_remote_connect()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_remote_connect.md)
below).

The package also offers a route that is independent of GROBID: the
[`parse_apa_text()`](https://CheckrefR.github.io/CheckrefR/reference/parse_apa_text.md)
function, based on **regular expressions**, which parses references in
**APA 7 format**. Its output can then be validated with the same
pipeline.

#### Verification of bibliographic references

The second part of the package consists in **checking that bibliographic
references really exist** and that they are correctly described. The
references extracted by GROBID are compared against the open database
[OpenAlex](https://openalex.org/) and/or against DOI resolution
(`doi.org`).

### Why verify? The context of generative AI

CheckrefR was designed in particular with the context of **generative
artificial intelligence (GenAI)** in mind. Large language models (LLMs)
can produce bibliographies that look perfectly credible, but whose
quality varies greatly. In general, one may encounter:

- **outright hallucinations**: the reference does not exist (invented
  title, authors and journal);
- **exact references**: the reference exists and all of its information
  is correct;
- **approximate references**: a real work, but with errors (year,
  authors, distorted title, incorrect journal);
- **hallucinated DOIs attached to a real reference**: the reference text
  matches a real article, but the DOI is wrong or points to another
  publication;
- the opposite: a **real DOI attached to an erroneous reference**;
- **ambiguous cases**, where the reference is *partially* correct and it
  is difficult to decide.

This diversity is what makes it necessary to perform a verification that
goes beyond a simple “the DOI exists / does not exist”, and that
compares all the elements (title, authors, year, DOI).

⚠️ Warning: experimental version

- The current version of the package is **experimental**.
- The **computation of matching scores** (title, authors, year, global
  score) is currently the subject of more thorough work and preparation
  than the method presently implemented, which has **limitations**.
- More **formal tests** on this question will be carried out in the
  future.
- Statuses and scores should therefore be read as **decision aids** and
  not as a verdict: manual verification remains necessary, especially
  for ambiguous or partially correct cases.

### Prerequisite: installing Docker (local mode)

The local mode, recommended above, relies on **Docker**. This is
software that runs programs in isolated “boxes” (*containers*), without
installing anything else on your machine. GROBID is distributed in this
form: Docker is therefore needed **only if you wish to use it locally**.
Without Docker, the remote mode remains available (see the caveats
above).

🐳 Installing Docker according to your system

- **Windows**: install [Docker
  Desktop](https://www.docker.com/products/docker-desktop/). It relies
  on WSL 2, which the installer offers to enable. A restart may be
  requested.
- **macOS**: install [Docker
  Desktop](https://www.docker.com/products/docker-desktop/), choosing
  the version suited to your processor (Apple Silicon or Intel).
- **Linux**: install Docker Engine via your distribution’s package
  manager (Debian/Ubuntu, Fedora/RHEL…), start the service, and add your
  user to the `docker` group to avoid using `sudo`.

See the [official
documentation](https://docs.docker.com/engine/install/).

[`grobid_check_requirements()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_check_requirements.md)
tells you whether it is detected, and
[`grobid_install_guide()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_install_guide.md)
provides instructions adapted to your system (see below).

## Getting GROBID up and running

### Overview

Getting started takes place in three steps:

1.  **Diagnose** your environment:
    [`grobid_check_requirements()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_check_requirements.md);
2.  **Install** if necessary, with an interactive guide:
    [`grobid_install_guide()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_install_guide.md);
3.  **Start GROBID**, locally with
    [`grobid_docker_start()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_start.md)
    or by connecting to a remote server with
    [`grobid_remote_connect()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_remote_connect.md).

Once GROBID is available, documents are processed with
[`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md)
and
[`grobid_process_files()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_files.md)
(next section).

### Step 1: check your environment with `grobid_check_requirements()`

This function diagnoses your system: operating system, Internet access,
presence and state of Docker, any active GROBID container, and
accessibility of the default remote servers. It then recommends a usage
mode.

``` r

req <- grobid_check_requirements()
#> ℹ Checking Internet connection...
#> ✔ Internet reachable (via Google).
#> 
#> ── Testing remote servers ──
#> 
#> ℹ Testing <https://grobidorg-grobid.hf.space> [crf]...
#> ✔ Operational server found: <https://grobidorg-grobid.hf.space> (mode: crf)
#> ℹ Testing <https://grobidorg-grobid2.hf.space> [crf]...
#> ℹ Testing <https://grobidorg-grobid-full.hf.space> [full]...
#> ℹ Testing <https://grobidOrg-grobid-full2.hf.space> [full]...
#> ℹ Checking Docker...
#> 
#> ── GROBID Diagnostic ───────────────────────────────────────────────────────────
#> 
#> ── Environment ──
#> 
#> • OS : windows (Windows mingw32)
#> • R : 4.5.2
#> • Internet: ✓
#> 
#> ── Docker ──
#> 
#> • Installed : ✓
#> • Running : ✗
#> • Version : 29.6.2
#> • Active GROBID container : ✗
#> ℹ Docker is installed but not currently running. It can be started automatically when needed (e.g. via `grobid_docker_start()`).
#> 
#> ── Remote server(s) ──
#> 
#> Mode crf:
#> • https://grobidorg-grobid.hf.space : ✓
#> • https://grobidorg-grobid2.hf.space : ✗
#> Mode full:
#> • https://grobidorg-grobid-full.hf.space : ✗
#> • https://grobidOrg-grobid-full2.hf.space : ✓
#> • Reachable remote server : ✓
#> ℹ Recommended URL: <https://grobidorg-grobid.hf.space> (mode: crf)
#> 
#> ── Current configuration ──
#> 
#> • Mode : not configured
#> • URL : not configured
#> 
#> ── Recommendation ──
#> 
#> ✔ Docker is installed on this system: local mode is strongly recommended.
#> ℹ Run `grobid_docker_start()` to start Docker and the GROBID container automatically.
#> ! A remote server is also reachable, but relying on Docker (local) is preferable for stability and independence from external service availability.
```

The result is also returned (invisibly) as a list:

``` r

req$recommended_mode
#> [1] "docker"
```

The recommended value is `"docker"` if Docker is installed, and
`"remote"` if Docker is absent but a remote server responds.

| Argument | Role |
|:---|:---|
| `check_docker` | Checks Docker and any active GROBID container. |
| `check_remote` | Tests the default remote servers. |
| `test_all_urls` | `TRUE`: tests all addresses; `FALSE`: stops at the first one that responds (faster). |
| `verbose` | Displays (or not) the diagnosis in the console. |

``` r

# Silent diagnosis, without testing Docker
req <- grobid_check_requirements(verbose = FALSE, check_docker = FALSE)
req$recommended_mode
```

### Step 2: get guided through installation with `grobid_install_guide()`

If Docker is not installed,
[`grobid_install_guide()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_install_guide.md)
displays a **step-by-step guide adapted to your system**, then invites
you to rerun the diagnosis. It is the interactive version of the box in
the previous section.

``` r

# Uses the previous diagnosis (otherwise, it is rerun automatically)
grobid_install_guide(requirements = req)
#> 
#> ── GROBID installation guide ───────────────────────────────────────────────────
#> 
#> ── 1. Environment summary ──
#> 
#> • OS : windows (Windows mingw32)
#> • Internet : ✓
#> • Docker installed : ✓
#> • Docker running : ✗
#> • Remote server(s) reachable : ✓
#> ℹ Remote server found (fallback only): <https://grobidorg-grobid.hf.space> (mode: crf)
#> ✔ Mode "crf": 1 reachable server(s).
#> ✔ Mode "full": 1 reachable server(s).
#> 
#> ── 2. Recommended option ──
#> 
#> ✔ Docker is installed on this system: local mode is strongly recommended.
#> ℹ Docker is not currently running, but it can be started automatically. Run `grobid_docker_start()` - the package will attempt to start the Docker daemon and the GROBID container for you.
#> ! A remote server is reachable (mode: crf), but it should only be used as a temporary fallback (e.g. `grobid_remote_connect()`). Relying on Docker locally avoids depending on third-party service availability, rate limits, or downtime.
#> 
#> ── 3. Starting Docker ──
#> 
#> • Open the Docker Desktop application from the Start menu.
#> • Wait until the Docker icon in the taskbar is active.
#> • Restart R and run `grobid_install_guide()`, or directly
#> `grobid_docker_start()`.
#> 
#> ── 4. Validation test ──
#> 
#> ℹ Once Docker is running, check your environment with:
#> • `grobid_check_requirements()`
```

### Step 3: start GROBID

Two options, depending on the chosen mode.

#### Local mode: `grobid_docker_start()`

This function launches GROBID in a Docker container on your machine.

``` r

grobid_docker_start()
```

**First launch: downloading the image.** The first time, the GROBID
model *image* (the “package” containing the program and its models) has
to be downloaded to your machine, which can **take a while** (several
GB). This is also the case **for each new model or new version** that
has not yet been downloaded. Subsequent launches are much faster.

Available settings:

| Argument | Role | Default value |
|:---|:---|:---|
| `model_type` | Model used: `"crf"` (lightweight) or `"full"` (deep learning, more accurate but heavier) | not set (standard image) |
| `grobid_version` | GROBID version | `"0.9.0"` |
| `port` | Local port on which the service is exposed | `8070` |
| `max_ram` | Maximum memory allocated (e.g. `"4g"`, `"8g"`) | `"4g"` |
| `pull` | Forces download/update of the image | `FALSE` |
| `timeout_ready` | Maximum waiting time before GROBID is ready | 120 s |
| `docker_image` | Base name of the Docker image | `"lfoppiano/grobid:"` |
| `verbose` | Progress messages | `TRUE` |

``` r

# Full model, more memory, custom port
grobid_docker_start(model_type = "full", max_ram = "8g", port = 8080)

# Another GROBID version
grobid_docker_start(grobid_version = "0.8.1")
```

If a compatible container (same image, version, model and port) is
already active, it is simply reused; otherwise, it is replaced.

#### Remote mode: `grobid_remote_connect()`

This function tests and then stores a remote GROBID server for the
current R session.

``` r

# Default demonstration servers (crf model)
grobid_remote_connect()
```

| Argument | Role |
|----|----|
| `url` | Address of **your own** GROBID server. If provided, `model_type` is ignored. |
| `model_type` | `"crf"` or `"full"`: chooses among the default demonstration servers. |
| `timeout` | Maximum connection delay (120 s by default). |
| `verbose` | Progress messages. |

``` r

# Your own server (recommended if you do not use Docker)
grobid_remote_connect(url = "https://mon-serveur-grobid.exemple.org")

# Demonstration servers, "full" model
grobid_remote_connect(model_type = "full")
```

**Reminder.** The default servers are **demonstration** servers: avoid
sending sensitive or large documents to them.

#### These two functions are optional

**You can skip this step 3.**
[`grobid_docker_start()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_start.md)
and
[`grobid_remote_connect()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_remote_connect.md)
are useful for **fine-tuning** the configuration (memory, port, version,
personal server), but calling them manually is not required.

The processing functions
[`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md)
and
[`grobid_process_files()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_files.md)
call them on their own: you only need to specify the `mode` (`"docker"`
or `"remote"`) and the `model_type` (`"crf"` or `"full"`). If the server
is not already active, it is then started or reached automatically.

## Processing documents with GROBID

### The `grobid_process_file()` and `grobid_process_files()` functions

- [`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md)
  processes **a single** file;
- [`grobid_process_files()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_files.md)
  processes **several** files (optionally in parallel) and gathers the
  results into a single table.

**Main parameters:**

| Argument | Role |
|----|----|
| `file` / `files` | Path(s) of the file(s) to process. |
| `service` | Type of GROBID processing (see below). |
| `params` | Additional options passed to GROBID, e.g. `list(consolidateCitations = 1)`. |
| `output_format` | `"parsed"` (R table, default) or `"raw"` (raw XML). |
| `output_dir` | Folder where XML files are saved (optional). |
| `mode` | `"docker"` or `"remote"`: **automatically starts or connects** the server if necessary. |
| `model_type` | `"crf"` or `"full"`: model used. |
| `parallel`, `n_workers` | *([`grobid_process_files()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_files.md))* parallel processing. |
| `on_error` | *([`grobid_process_files()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_files.md))* `"warn"` (continues) or `"stop"`. |

**Available services:**

| `service` | Input | Extracted content |
|:---|:---|:---|
| `"processFulltextDocument"` | PDF | Structured full text and references |
| `"processHeaderDocument"` | PDF | Header (title, authors, abstract…) |
| `"processReferences"` | PDF | List of bibliographic references |
| `"processCitationList"` | `.txt` file or vector of texts | Parsing of raw references (one per line) |

### Illustration with the example file `ref_test.txt`

The package provides a test file in its `extdata` folder. It contains a
list of raw references, which can be processed with the
`"processCitationList"` service.

``` r

txt_file <- system.file("extdata", package = "CheckrefR") |>
  list.files(pattern = "ref_test", full.names = TRUE)

basename(txt_file)
#> [1] "ref_test.txt"
```

**Preview of the raw content:**

``` r

readLines(txt_file, warn = FALSE) |>
  head(6) |> writeLines(sep = "\n\n")
```

Deci, E. L., & Ryan, R. M. (2000). The “what” and “why” of goal
pursuits: Human needs and the self-determination of behavior.
Psychological Inquiry, 11(4), 227–268.
<https://doi.org/10.1207/S15327965PLI1104_01>

Mikolov, T., Chen, K., Corrado, G., & Dean, J. (2013). Efficient
estimation of word representations in vector space. In Y. Bengio & Y.
LeCun (Eds.), Proceedings of the 1st International Conference on
Learning Representations (pp. 1–12). ICLR.

Vaswani, A., Shazeer, N., Parmar, N., Uszkoreit, J., Jones, L., Gomez,
A. N., Kaiser, Ł., & Polosukhin, I. (2017). Attention is all you need.
arXiv. <https://doi.org/10.48550/arXiv.1706.03762>

Kahneman, D. (2011). Thinking, fast and slow. Farrar, Straus and Giroux.

Baumeister, R. F., & Leary, M. R. (1995). The need to belong: Desire for
interpersonal attachments as a fundamental human motivation. In R. F.
Baumeister (Ed.), Social psychology and human nature (pp. 497–529).
Wadsworth.

Bandura, A. (1977). Self-efficacy: Toward a unifying theory of
behavioral change. Psychological Review, 84(2), 191–215.
<https://doi.org/10.1037/0003-066X.55.1.5>

------------------------------------------------------------------------

### Processing the file

Here, the mode and the model are specified directly: the server is
started or reached automatically, without any prior call to
[`grobid_docker_start()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_start.md)
or
[`grobid_remote_connect()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_remote_connect.md).

``` r

refs <- grobid_process_file(
  file = txt_file,
  service = "processCitationList",
  mode = "docker",        # or "remote"
  model_type = "crf",
  output_format = "parsed"
)
```

The result is a table (*tibble*) with one row per reference:

``` r

dim(refs)
#> [1] 14 17
names(refs)
#>  [1] "ref_n"            "raw_reference"    "title"            "authors"         
#>  [5] "authors_list"     "year"             "journal"          "publisher"       
#>  [9] "volume"           "issue"            "pages"            "doi"             
#> [13] "pmid"             "url"              "ref_type"         "parse_confidence"
#> [17] "source_file"
```

``` r

refs |>
  select(ref_n, title, authors, year, journal, doi) |>
  head(8) |>
  kable_site(caption = "References extracted by GROBID (preview)") |>
  column_spec(2, width = "22em")
```

| ref_n | title | authors | year | journal | doi |
|---:|:---|:---|---:|:---|:---|
| 1 | The “what” and “why” of goal pursuits: Human needs and the self-determination of behavior | Deci, E; Ryan, R | 2000 | Psychological Inquiry | 10.1207/S15327965PLI1104_01 |
| 2 | Efficient estimation of word representations in vector space | Mikolov, T; Chen, K; Corrado, G; Dean, J | 2013 | NA | NA |
| 3 | Attention is all you need | Vaswani, A; Shazeer, N; Parmar, N; Uszkoreit, J; Jones, L; Gomez, A; Kaiser, Ł; Polosukhin, I | 2017 | NA | 10.48550/arXiv.1706.03762 |
| 4 | Thinking, fast and slow | Kahneman, D | 2011 | NA | NA |
| 5 | The need to belong: Desire for interpersonal attachments as a fundamental human motivation | Baumeister, R; Leary, M | 1995 | NA | NA |
| 6 | Self-efficacy: Toward a unifying theory of behavioral change | Bandura, A | 1977 | Psychological Review | 10.1037/0003-066X.55.1.5 |
| 7 | Development and validation of brief measures of positive and negative affect: The PANAS scales | Watson, D; Clark, L; Tellegen, A | 1988 | Journal of Personality and Social Psychology | 10.1037/0022-3514.84.4.822 |
| 8 | The necessary and sufficient conditions of therapeutic personality change | Rogers, C | 1957 | Journal of Consulting Psychology | 10.1037/h9999999 |

References extracted by GROBID (preview) {.table .table .table-striped
.table-hover .table-condensed .table-responsive
style="font-size: 13px; width: auto !important; margin-left: auto; margin-right: auto;"}

For **several files**, use
[`grobid_process_files()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_files.md),
which adds a `source_file` column to identify the origin of each row.
Example with any PDFs available in the package:

``` r

pdf_files <- system.file("extdata", package = "CheckrefR") |>
  list.files(pattern = "\\.pdf$", full.names = TRUE)

refs_pdf <- grobid_process_files(
  files = pdf_files,
  service = "processReferences",
  mode = "docker",
  output_format = "parsed"
)
```

## Validating references

Once the references are extracted, their existence and accuracy can be
checked.

### Comparing against OpenAlex: `validate_references()`

[`validate_references()`](https://CheckrefR.github.io/CheckrefR/reference/validate_references.md)
takes the reference table as input (at minimum the columns `title`,
`authors_list`, `doi`, `year`, `ref_n`, `source_file`) and follows a
multi-step procedure:

1.  **checking DOIs** against OpenAlex;
2.  for unresolved or inconsistent DOIs, **querying `doi.org`**;
3.  if necessary, **searching by title**;
4.  computing **matching scores** (title, authors, year) and a global
    score;
5.  keeping one to `max_candidates` candidates per reference (3 by
    default).

``` r


checkrefr_set_defaults(oa_api_key = keyring::key_get("openalex"))

cache_file <- "validated_refs_2.rds"

if (file.exists(cache_file)) {
  results <- readRDS(cache_file)
} else {
  ref_path <- system.file("extdata", "ref_test.txt", package = "CheckrefR")
  results <- validate_references(refs, verbose = FALSE)
  saveRDS(results, cache_file)
}
```

Main columns of the result:

| Column | Content |
|:---|:---|
| `input_title`, `input_doi`, `input_year`, `input_authors` | Information of the reference **as extracted**. |
| `oa_title`, `oa_doi`, `oa_year`, `oa_authors` | Information of the candidate **OpenAlex record**. |
| `score_title`, `score_authors`, `score_year` | Similarity scores (0 to 1). |
| `score_global` | Weighted score: 60% title, 30% authors, 10% year. |
| `n_candidates` | Number of candidates retained for this reference. |
| `match_status` | Matching status (see below). |

``` r

results |>
  select(ref_n, input_title, oa_title, score_title, score_authors,
         score_year, score_global, match_status) |>
  mutate(across(starts_with("score_"), ~ round(.x, 2))) |>
  head(10) |>
  kable_site(caption = "Validation results (preview)") |>
  column_spec(c(2, 3), width = "16em")
```

| ref_n | input_title | oa_title | score_title | score_authors | score_year | score_global | match_status |
|---:|:---|:---|---:|---:|---:|---:|:---|
| 1 | The “what” and “why” of goal pursuits: Human needs and the self-determination of behavior | The “What” and “Why” of Goal Pursuits: Human Needs and the Self-Determination of Behavior | 1.00 | 0.90 | 1 | 0.97 | confirmed_with_doi |
| 2 | Efficient estimation of word representations in vector space | Efficient Estimation of Word Representations in Vector Space | 1.00 | 0.98 | 1 | 0.99 | title_search |
| 3 | Attention is all you need | Attention Is All You Need | 1.00 | 0.96 | 1 | 0.99 | confirmed_with_doi |
| 4 | Thinking, fast and slow | Thinking, Fast and Slow | 1.00 | 0.90 | 1 | 0.97 | title_search |
| 5 | The need to belong: Desire for interpersonal attachments as a fundamental human motivation | The need to belong: Desire for interpersonal attachments as a fundamental human motivation. | 1.00 | 0.90 | 1 | 0.97 | title_search |
| 5 | The need to belong: Desire for interpersonal attachments as a fundamental human motivation | The need to belong: Desire for interpersonal attachments as a fundamental human motivation. | 1.00 | 0.90 | 1 | 0.97 | title_search |
| 5 | The need to belong: Desire for interpersonal attachments as a fundamental human motivation | The Need to Belong: Desire for Interpersonal Attachments as a Fundamental Human Motivation | 1.00 | 0.90 | 0 | 0.87 | title_search |
| 6 | Self-efficacy: Toward a unifying theory of behavioral change | Positive psychology: An introduction. | 0.22 | 0.00 | 0 | 0.13 | doi_mismatch |
| 6 | Self-efficacy: Toward a unifying theory of behavioral change | Self-efficacy: Toward a unifying theory of behavioral change. | 1.00 | 1.00 | 1 | 1.00 | title_search |
| 6 | Self-efficacy: Toward a unifying theory of behavioral change | Self-efficacy: Toward a unifying theory of behavioral change. | 1.00 | 1.00 | 1 | 1.00 | title_search |

Validation results (preview) {.table .table .table-striped .table-hover
.table-condensed .table-responsive
style="font-size: 13px; width: auto !important; margin-left: auto; margin-right: auto;"}

Most frequent statuses:

| `match_status`       | Meaning                                             |
|----------------------|-----------------------------------------------------|
| `confirmed_with_doi` | DOI confirmed, with matching title and year.        |
| `partial_with_doi`   | DOI found, but only a partial match.                |
| `doi_mismatch`       | The DOI exists, but designates another publication. |
| `doi_not_found`      | DOI not found or nonexistent.                       |
| `title_search`       | Match found through a title search.                 |
| `no_match`           | No sufficiently close candidate.                    |

``` r

results |>
  count(match_status, name = "n_lignes", sort = TRUE) |>
  kable_site(caption = "Distribution of matching statuses")
```

| match_status       | n_lignes |
|:-------------------|---------:|
| title_search       |       17 |
| doi_does_not_exist |        5 |
| no_match           |        4 |
| confirmed_with_doi |        2 |
| doi_mismatch       |        2 |

Distribution of matching statuses {.table .table .table-striped
.table-hover .table-condensed .table-responsive
style="font-size: 13px; width: auto !important; margin-left: auto; margin-right: auto;"}

The thresholds (minimum score of 0.60; “probable” match from 0.85; DOI
confirmation with a title score of at least 0.90 and an identical year)
are those of the **experimental version**. See the warning in the
introduction.

### Keeping the best match: `deduplicate_references()`

Since
[`validate_references()`](https://CheckrefR.github.io/CheckrefR/reference/validate_references.md)
can return several candidates per reference,
[`deduplicate_references()`](https://CheckrefR.github.io/CheckrefR/reference/deduplicate_references.md)
keeps only **the best row** (highest global score) for each
`source_file` / `ref_n` pair. The order of the references is preserved.

``` r

best <- deduplicate_references(results, verbose = TRUE)
```

``` r

best |>
  select(ref_n, input_title, oa_doi, score_global, match_status) |>
  mutate(score_global = round(score_global, 2)) |>
  kable_site(caption = "One row per reference (best match)") |>
  column_spec(2, width = "22em")
```

| ref_n | input_title | oa_doi | score_global | match_status |
|---:|:---|:---|---:|:---|
| 1 | The “what” and “why” of goal pursuits: Human needs and the self-determination of behavior | 10.1207/s15327965pli1104_01 | 0.97 | confirmed_with_doi |
| 2 | Efficient estimation of word representations in vector space | 10.48550/arxiv.1301.3781 | 0.99 | title_search |
| 3 | Attention is all you need | 10.48550/arxiv.1706.03762 | 0.99 | confirmed_with_doi |
| 4 | Thinking, fast and slow | NA | 0.97 | title_search |
| 5 | The need to belong: Desire for interpersonal attachments as a fundamental human motivation | 10.1037/0033-2909.117.3.497 | 0.97 | title_search |
| 6 | Self-efficacy: Toward a unifying theory of behavioral change | 10.1037//0033-295x.84.2.191 | 1.00 | title_search |
| 7 | Development and validation of brief measures of positive and negative affect: The PANAS scales | 10.1037/0022-3514.54.6.1063 | 0.99 | title_search |
| 8 | The necessary and sufficient conditions of therapeutic personality change | 10.1037/h0045357 | 0.97 | title_search |
| 9 | Judgment under uncertainty: Heuristics and biases | 10.1126/science.185.4157.1124 | 0.98 | title_search |
| 10 | L’influence quantique de la pensée positive sur la mécanique cellulaire réversible | NA | NA | doi_does_not_exist |
| 11 | A study of nothing in particular that somehow got published | NA | NA | doi_does_not_exist |
| 12 | Thinking, slow and fast | NA | 0.65 | title_search |
| 13 | The “how” and “why” of goal attainment: Human motivation and self-determination reconsidered | NA | NA | doi_does_not_exist |
| 14 | The need to belong: Desire for social bonding as a fundamental human need | NA | NA | no_match |

One row per reference (best match) {.table .table .table-striped
.table-hover .table-condensed .table-responsive
style="font-size: 13px; width: auto !important; margin-left: auto; margin-right: auto;"}

## Alternative without GROBID: APA 7 format references

For references already written in **APA 7**
(`Authors (year). Title. Journal, volume(issue), pages. DOI`),
[`parse_apa_text()`](https://CheckrefR.github.io/CheckrefR/reference/parse_apa_text.md)
parses them using regular expressions, without a GROBID server. The
`as_ref_df = TRUE` option produces a table directly compatible with
[`validate_references()`](https://CheckrefR.github.io/CheckrefR/reference/validate_references.md).

``` r

txt_files <- system.file("extdata", package = "CheckrefR") |>
  list.files(pattern = "\\.txt$", full.names = TRUE)

apa  <- txt_files[2]
```

Click to display the detailed list of references used to test the
validate_references function

``` r

readLines(apa) |>  writeLines(sep = "\n\n")
```

Topol, E. J. (2019). High-performance medicine: The convergence of human
and artificial intelligence. Nature Medicine, 25(1), 44–56.
<https://doi.org/10.1038/s41591-018-0300-7>

Rajpurkar, P., Irvin, J., Ball, R. L., Zhu, K., Yang, B., Mehta, H.,
Duan, T., Ding, D., Bagul, A., Langlotz, C., Shpanskaya, K., Lungren, M.
P., & Ng, A. Y. (2018). Deep learning for chest radiograph diagnosis.
PLOS Medicine, 15(11), e1002686.
<https://doi.org/10.1371/journal.pmed.1002686>

Esteva, A., Kuprel, B., Novoa, R. A., Ko, J., Swetter, S. M., Blau, H.
M., & Thrun, S. (2017). Dermatologist-level classification of skin
cancer with deep neural networks. Nature, 542(7639), 115–118.
<https://doi.org/10.1038/nature21056>

Obermeyer, Z., Powers, B., Vogeli, C., & Mullainathan, S. (2019).
Dissecting racial bias in an algorithm used to manage the health of
populations. Science, 366(6464), 447–453.
<https://doi.org/10.1126/science.aax2342>

Char, D. S., Shah, N. H., & Magnus, D. (2018). Implementing machine
learning in health care — addressing ethical challenges. New England
Journal of Medicine, 378(11), 981–983.
<https://doi.org/10.1056/NEJMp1714229>

Russell, S., & Norvig, P. (2021). Artificial intelligence: A modern
approach (4th ed.). Pearson.

Topol, E. J. (2019). Deep medicine: How artificial intelligence can make
healthcare human again. Basic Books.

Shortliffe, E. H., & Cimino, J. J. (Eds.). (2014). Biomedical
informatics: Computer applications in health care and biomedicine (4th
ed.). Springer. <https://doi.org/10.1007/978-1-4471-4474-8>

Beam, A. L., & Kohane, I. S. (2018). Translating artificial intelligence
into clinical care. In E. Shortliffe & J. Cimino (Eds.), Biomedical
informatics: Computer applications in health care and biomedicine
(pp. 583–601). Springer. <https://doi.org/10.1007/978-3-319-98779-8_18>

Obermeyer, Z., & Emanuel, E. J. (2016). Predicting the future — big
data, machine learning, and clinical medicine. In The Oxford handbook of
ethics of AI (pp. 421–436). Oxford University Press.
<https://doi.org/10.1056/NEJMp1606181>

Chen, J. H., & Asch, S. M. (2017). Machine learning and prediction in
medicine — beyond the peak of inflated expectations. In M. Matheny, S.
Israni, M. Ahmed & D. Whicher (Eds.), Artificial intelligence in health
care: The hope, the hype, the promise, the peril (pp. 97–112). National
Academy of Medicine.

Rajpurkar, P., Irvin, J., Zhu, K., Yang, B., Mehta, H., Duan, T., & Ng,
A. Y. (2017). CheXNet: Radiologist-level pneumonia detection on chest
X-rays with deep learning. Proceedings of the 31st Conference on Neural
Information Processing Systems (NIPS 2017), Long Beach, United States.
<https://arxiv.org/abs/1711.05225>

Ghassemi, M., Naumann, T., Schulam, P., Beam, A. L., Chen, I. Y., &
Ranganath, R. (2019). A review of challenges and opportunities in
machine learning for health. Proceedings of the AMIA Joint Summits on
Translational Science, San Francisco, United States, 191–200.
<https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6568073/>

Lundberg, S. M., & Lee, S.-I. (2017). A unified approach to interpreting
model predictions. Proceedings of the 31st International Conference on
Neural Information Processing Systems (NIPS 2017) (pp. 4765–4774), Long
Beach, United States. <https://arxiv.org/abs/1705.07874>

Moor, M., Banerjee, O., Abad, Z. S. H., Krumholz, H. M., Leskovec, J.,
Topol, E. J., & Rajpurkar, P. (2023). Foundation models for generalist
medical artificial intelligence. arXiv.
<https://arxiv.org/abs/2301.02139>

Nori, H., King, N., McKinney, S. M., Carignan, D., & Horvitz, E. (2023).
Capabilities of GPT-4 on medical challenge problems. arXiv.
<https://arxiv.org/abs/2303.13375>

Singhal, K., Azizi, S., Tu, T., Mahdavi, S. S., Wei, J., Chung, H. W., &
Natarajan, V. (2022). Large language models encode clinical knowledge.
arXiv. <https://arxiv.org/abs/2212.13138>

World Health Organization. (2021). Ethics and governance of artificial
intelligence for health. WHO.
<https://www.who.int/publications/i/item/9789240029200>

French National Authority for Health. (2023). Artificial intelligence in
health: A framework of best practices. HAS.
<https://www.has-sante.fr/jcms/p_3346314/fr/intelligence-artificielle-en-sante>

MIT Technology Review. (2023, March 14). How AI is transforming medical
diagnosis. MIT Technology Review.
<https://www.technologyreview.com/2023/03/14/ai-medical-diagnosis>

``` r

apa_refs <- parse_apa_text(apa, as_ref_df = TRUE)

apa_refs |>
  select(authors, title, year, doi) |>
  kable_site(caption = "APA 7 references parsed with regular expressions")
```

| authors | title | year | doi |
|:---|:---|---:|:---|
| Topol, E | High-performance medicine: The convergence of human and artificial intelligence | 2019 | 10.1038/s41591-018-0300-7 |
| Rajpurkar, P; Irvin, J; Ball, R; Zhu, K; Yang, B; Mehta, H; Duan, T; Ding, D; Bagul, A; Langlotz, C; Shpanskaya, K; Lungren, M; Ng, A | Deep learning for chest radiograph diagnosis | 2018 | 10.1371/journal.pmed.1002686 |
| Esteva, A; Kuprel, B; Novoa, R; Ko, J; Swetter, S; Blau, H; Thrun, S | Dermatologist-level classification of skin cancer with deep neural networks | 2017 | 10.1038/nature21056 |
| Obermeyer, Z; Powers, B; Vogeli, C; Mullainathan, S | Dissecting racial bias in an algorithm used to manage the health of populations | 2019 | 10.1126/science.aax2342 |
| Char, D; Shah, N; Magnus, D | Implementing machine learning in health care — addressing ethical challenges | 2018 | 10.1056/nejmp1714229 |
| Russell, S; Norvig, P | Artificial intelligence: A modern approach (4th ed | 2021 | NA |
| Topol, E | Deep medicine: How artificial intelligence can make healthcare human again | 2019 | NA |
| Shortliffe, E; Cimino, J | Biomedical informatics: Computer applications in health care and biomedicine (4th ed | 2014 | 10.1007/978-1-4471-4474-8 |
| Beam, A; Kohane, I | Translating artificial intelligence into clinical care | 2018 | 10.1007/978-3-319-98779-8_18 |
| Obermeyer, Z; Emanuel, E | Predicting the future — big data, machine learning, and clinical medicine | 2016 | 10.1056/nejmp1606181 |
| Chen, J; Asch, S | Machine learning and prediction in medicine — beyond the peak of inflated expectations | 2017 | NA |
| Rajpurkar, P; Irvin, J; Zhu, K; Yang, B; Mehta, H; Duan, T; Ng, A | CheXNet: Radiologist-level pneumonia detection on chest X-rays with deep learning | 2017 | NA |
| Ghassemi, M; Naumann, T; Schulam, P; Beam, A; Chen, I; Ranganath, R | A review of challenges and opportunities in machine learning for health | 2019 | NA |
| Lundberg, S; Lee, S-I | A unified approach to interpreting model predictions | 2017 | NA |
| Moor, M; Banerjee, O; Abad, Z; Krumholz, H; Leskovec, J; Topol, E; Rajpurkar, P | Foundation models for generalist medical artificial intelligence | 2023 | NA |
| Nori, H; King, N; McKinney, S; Carignan, D; Horvitz, E | Capabilities of GPT-4 on medical challenge problems | 2023 | NA |
| Singhal, K; Azizi, S; Tu, T; Mahdavi, S; Wei, J; Chung, H; Natarajan, V | Large language models encode clinical knowledge | 2022 | NA |
| NA | Ethics and governance of artificial intelligence for health | 2021 | NA |
| NA | Artificial intelligence in health: A framework of best practices | 2023 | NA |
| NA | MIT Technology Review | NA | NA |

APA 7 references parsed with regular expressions {.table .table
.table-striped .table-hover .table-condensed .table-responsive
style="font-size: 13px; width: auto !important; margin-left: auto; margin-right: auto;"}

This method assumes a strictly compliant format: year in the form
`(YYYY)`, title ending at the first period following the year, DOI as a
`doi.org` URL at the end of the reference. Non-compliant references may
produce missing values or partial extractions, without any error
message.

## Going further

- See the function reference for details on each argument;
- [`grobid_server_info()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_server_info.md)
  and
  [`grobid_docker_stop()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_docker_stop.md)
  let you check the status of the active server and stop the local
  container;
- [`oa_matching_info()`](https://CheckrefR.github.io/CheckrefR/reference/oa_matching_info.md)
  describes the matching parameters with OpenAlex.

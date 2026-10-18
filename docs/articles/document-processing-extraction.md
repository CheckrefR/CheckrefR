# Document Processing and XML Extraction

## Introduction

This page details the **first step of working with CheckrefR: turning a
document or a list of references into usable data**. The “Get started”
page gave an overview; here we go into how each function works.

We will cover, in turn:

1.  **[`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md)**:
    the central function, which sends **one** document to GROBID and
    retrieves the result. We will present the four available services,
    their parameters, and the two output “paths” (raw XML or data
    table), as well as the `parse_*()` functions that turn the XML into
    a table.
2.  **[`grobid_process_files()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_files.md)**:
    a function that repeats the processing on **several** documents,
    with parallel execution and error handling.
3.  **[`process_citation_file()`](https://CheckrefR.github.io/CheckrefR/reference/process_citation_file.md)**:
    a shortcut for processing a text file containing a list of
    references.
4.  **[`parse_apa_text()`](https://CheckrefR.github.io/CheckrefR/reference/parse_apa_text.md)**:
    an alternative **without GROBID**, which extracts reference
    information in APA 7 format using regular expressions.

These four functions perform related tasks: producing, from different
sources, **structured references** (title, authors, year, DOI…) ready
for
[validation](https://CheckrefR.github.io/CheckrefR/articles/reference-validation-pipeline.md).

**Reminder: GROBID and XML.** GROBID is a tool that reads a document
(PDF) or a free-text reference and extracts the bibliographic
information from it. It returns its result in a format called
**TEI/XML**, a tagged text file that is machine-readable but not very
convenient for analysis. CheckrefR can therefore give you this XML as is
(“raw”), or **convert it into a data table** (“parsed”).

## `grobid_process_file()`: processing a document

### Principle

[`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md)
sends **a single file** to GROBID, locally or remotely, and returns the
result. It takes care of checking that the server is running for you
(see “Get started” and the server administration page).

``` r

grobid_process_file(
  file,
  service       = "processFulltextDocument",
  params        = list(),
  output_dir    = NULL,
  output_format = "parsed",
  mode          = NULL,
  model_type    = .checkrefr_env$grobid_model_type,
  verbose       = TRUE,
  user_agent    = NULL
)
```

The arguments fall into three groups:

| Group | Arguments | Role |
|:---|:---|:---|
| **What to process** | `file`, `service`, `params` | The document, the type of analysis requested, the GROBID options |
| **What to get** | `output_format`, `output_dir` | Format of the result, optional saving of the XML |
| **Where and how** | `mode`, `model_type`, `verbose`, `user_agent` | Server used and technical behavior |

### Choosing a service

The `service` argument indicates **which type of analysis** GROBID
should perform. There are four services:

| `service` | Expected input | What you get | Associated parsing function |
|:---|:---|:---|:---|
| `"processFulltextDocument"` (default) | a PDF | The full text, split into sections | [`parse_fulltext()`](https://CheckrefR.github.io/CheckrefR/reference/parse_fulltext.md) |
| `"processHeaderDocument"` | a PDF | The header metadata (title, authors, abstract, DOI…) | [`parse_header()`](https://CheckrefR.github.io/CheckrefR/reference/parse_header.md) |
| `"processReferences"` | a PDF | The list of references cited in the document | [`parse_references()`](https://CheckrefR.github.io/CheckrefR/reference/parse_references.md) |
| `"processCitationList"` | a `.txt` file or a vector of references | Structured references from free text | [`parse_citation_list()`](https://CheckrefR.github.io/CheckrefR/reference/parse_citation_list.md) |

**Which service should you choose?** To validate the references of an
article, the **`processReferences`** service is generally the most
direct: it returns only the bibliography. Use
**`processFulltextDocument`** if you also need the text of the article,
**`processHeaderDocument`** if you are only interested in the article’s
metadata, and **`processCitationList`** if your references are already
in a text file (one per line).

The first three services require a **PDF**. Only `processCitationList`
accepts a `.txt` text file or directly a vector of references.

### The two output paths: `output_format`

The `output_format` argument determines what the function returns to
you. It accepts two values:

| `output_format` | Result | When to use it |
|:---|:---|:---|
| `"parsed"` (default) | A **data table** (tibble), ready for analysis | Common case: you want to work with the data in R |
| `"raw"` | The **raw XML** (a character string) | You want to keep or inspect GROBID’s exact response |

#### `output_format = "parsed"` path: a directly usable table

With the default value, CheckrefR automatically converts the XML into a
table, using the parsing function corresponding to the chosen service. A
`source_file` column is added: it contains the **name** of the processed
file.

``` r

refs <- grobid_process_file(
  file    = "mon_article.pdf",
  service = "processReferences"
)

head(refs)
```

#### `output_format = "raw"` path: raw XML and the `parse_*()` functions

With `"raw"`, you get the XML as GROBID produced it, in the form of **a
character string**. This lets you keep it, inspect it, or **convert it
yourself later**.

``` r

xml <- grobid_process_file(
  file          = "mon_article.pdf",
  service       = "processReferences",
  output_format = "raw"
)

substr(xml, 1, 300)   # preview of the beginning of the XML
```

The conversion into a table is handled by four public functions, **one
per service**. They are called automatically in the `"parsed"` path, but
you can also use them directly on XML you already have:

| Function | Associated service | Content of the returned table |
|:---|:---|:---|
| [`parse_fulltext()`](https://CheckrefR.github.io/CheckrefR/reference/parse_fulltext.md) | `processFulltextDocument` | One row per **section** (title, abstract, body, acknowledgements, appendices), with the text (`content`), the word count (`n_words`) and paragraph count (`n_paragraphs`) |
| [`parse_header()`](https://CheckrefR.github.io/CheckrefR/reference/parse_header.md) | `processHeaderDocument` | **A single row**: title, authors, journal, year, DOI, abstract, keywords, language, number of references (`n_references`) |
| [`parse_references()`](https://CheckrefR.github.io/CheckrefR/reference/parse_references.md) | `processReferences` | One row per **reference**: raw reference, title, authors, year, journal, volume, pages, DOI… |
| [`parse_citation_list()`](https://CheckrefR.github.io/CheckrefR/reference/parse_citation_list.md) | `processCitationList` | One row per parsed **reference**, with a confidence indicator (`parse_confidence`) and a reference type (`ref_type`) |

``` r

# The same XML can be converted with the appropriate function
refs   <- parse_references(xml)
header <- parse_header(xml)
texte  <- parse_fulltext(xml)
```

**One `parse_*()` function per service.** The XML returned by each
service has a different structure. You must therefore use the
`parse_*()` function that matches the service with which the XML was
obtained. These functions accept XML as text, as a file, or as an `xml2`
object.

#### Saving the XML with `output_dir`

The `output_dir` argument lets you **write the XML to disk**, in a
folder that is created if necessary. The file is named after the source
document, followed by the `.tei.xml` extension (for a list of references
sent as a vector, it is called `citations.tei.xml`).

``` r

grobid_process_file(
  file       = "mon_article.pdf",
  service    = "processReferences",
  output_dir = "xml_sortie"
)
```

**Points to note about `output_dir`.**

- When `output_dir` is specified, the function returns the **raw XML**
  (invisibly), and **not the path of the written file**, regardless of
  the value of `output_format`.
- **There is no protection against overwriting**: if a file with the
  same name already exists in the folder, it is replaced without
  warning.

### Tuning the analysis with `params`

The `params` argument is a **list of options** passed as is to GROBID.
They let you adjust the processing: for example, asking GROBID to
**consolidate** the references by checking them against an external
database, or to keep the **raw text** of the references.

``` r

refs <- grobid_process_file(
  file    = "mon_article.pdf",
  service = "processReferences",
  params  = list(consolidateCitations = 1)
)
```

The available parameters depend on the service and the GROBID version.
The most common ones are:

| Parameter | Effect (briefly) | Services concerned |
|:---|:---|:---|
| `consolidateHeader` | Consolidates the header metadata with an external database | Header, full text |
| `consolidateCitations` | Consolidates the references with an external database | References, full text, citation list |
| `includeRawCitations` | Includes the raw text of the references in the XML | References, citation list |
| `segmentSentences` | Splits the text into sentences | Full text |
| `teiCoordinates` | Adds the coordinates of the elements in the PDF | Full text, references |

For the complete list, the possible values and their exact effect, see
the [GROBID API
documentation](https://grobid.readthedocs.io/en/latest/Grobid-service/).

**Good to know.**

- **No validation is performed on `params`**: CheckrefR passes your
  options to GROBID without checking them. An unknown or misspelled
  option will simply be ignored or rejected by GROBID.
- **`includeRawCitations`** is added **automatically** (value `1`) for
  the `processReferences` and `processCitationList` services, so that
  the original reference is kept in the `raw_reference` column.
- **Consolidation** (`consolidateHeader`, `consolidateCitations`) relies
  on external services: it slows down processing and may alter the
  returned metadata. If your goal is to **verify** references with
  [`validate_references()`](https://CheckrefR.github.io/CheckrefR/reference/validate_references.md),
  it is generally preferable not to consolidate beforehand, so as not to
  “correct” upstream the errors you are trying to detect.

### Server, model, and other arguments

The `mode` (`"docker"` or `"remote"`) and `model_type` (`"crf"` or
`"full"`) arguments determine **which GROBID server** is used and
**which model** it applies. They were presented in “Get started” and are
detailed in the “GROBID Server Setup and Administration” page: we do not
return to them here. Simply remember that, if the server is not running,
it is started or reached automatically.

The other arguments are more technical in use:

| Argument | Role |
|:---|:---|
| `verbose` | Displays (`TRUE`) or hides progress messages |
| `.ensure_server` | If `TRUE` (default), checks or starts the server before the request. Set to `FALSE` only if you manage the server yourself |
| `user_agent` | Identification text sent to the server. By default, CheckrefR identifies itself with its name and version |

### Behavior when something goes wrong

- If the server is **temporarily overloaded** (HTTP 503 response, common
  on demonstration servers), the request is **automatically retried**,
  up to 3 times, with a 10-second wait between attempts.
- If GROBID returns **no result**, the function returns `NA`
  (invisibly).
- A missing file or one of the **wrong type** (for example a `.txt` for
  a PDF service) triggers an explicit error.

## `grobid_process_files()`: processing several documents

### Principle

[`grobid_process_files()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_files.md)
applies
[`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md)
to **each element of a vector of paths**. It therefore reuses the same
`service`, `params`, `output_dir`, `output_format`, `mode`, `model_type`
and `user_agent` arguments, with the same meaning. It adds what is
needed to process a batch: **parallelism**, **progress bar**, **error
handling** and **result assembly**.

``` r

grobid_process_files(
  files,
  service       = "processFulltextDocument",
  params        = list(),
  output_dir    = NULL,
  output_format = "parsed",
  parallel      = length(files) > 5L,
  n_workers     = .checkrefr_env $ max_workers,
  progress      = TRUE,
  mode          = NULL,
  model_type    = .checkrefr_env $ grobid_model_type,
  on_error      = "warn",
  user_agent    = NULL
)
```

``` r

pdfs <- list.files("mes_pdf", pattern = "\\.pdf$", full.names = TRUE)

refs <- grobid_process_files(
  files   = pdfs,
  service = "processReferences"
)
```

**The function does not scan a folder.** `files` must be a **vector of
paths that has already been built** (for example with
[`list.files()`](https://rdrr.io/r/base/list.files.html)). There is no
argument to filter by pattern, traverse subfolders or skip files that
have already been processed.

### The added arguments

| Argument | Default value | Role |
|:---|:---|:---|
| `files` | (required) | Vector of file paths |
| `parallel` | `TRUE` if more than 5 files | Processes several files **at the same time** |
| `n_workers` | package internal value | Number of simultaneous processes |
| `progress` | `TRUE` | Displays a progress bar |
| `on_error` | `"warn"` | What to do if a file fails: `"warn"` or `"stop"` |

#### Parallel processing

Processing several files simultaneously speeds up the work. The number
of simultaneous processes depends on the mode:

- **`"docker"` mode**: the requested number (`n_workers`) is capped at
  the number of cores on your computer minus one.
- **`"remote"` mode**: the number is **always set to 2**, regardless of
  the requested value, so as not to overload the demonstration servers.

**Progress bar.** The `progress` argument only has an effect in
**sequential** processing (without parallelism). In parallel mode, no
bar is displayed.

#### Error handling: `on_error`

- `on_error = "warn"` (default): if a file fails, a **warning** is
  issued and processing **continues** with the following files. The file
  concerned yields an `NA` result.
- `on_error = "stop"`: processing **stops** at the first error.

For a large batch, the default value is generally the most practical: a
faulty file does not block the whole run.

### What the function returns

The result depends on `output_dir` and `output_format`:

| Situation | Result |
|:---|:---|
| `output_format = "parsed"`, without `output_dir` | **A single table** combining the results of all files (`source_file` column to tell them apart). Files that failed are absent from it. If no file succeeded, the function returns `NULL`. |
| `output_format = "raw"`, without `output_dir` | A **list** of raw XML, named after the files. Files that failed appear in it with the value `NA`. |
| With `output_dir` | The XML files are written to the folder; the function returns, invisibly, a vector of raw XML (and not of paths). |

``` r

# Get a list of raw XML, one per file
xmls <- grobid_process_files(
  files         = pdfs,
  service       = "processReferences",
  output_format = "raw"
)

names(xmls)   # names of the processed files
```

## `process_citation_file()`: processing a file of references

### Principle

[`process_citation_file()`](https://CheckrefR.github.io/CheckrefR/reference/process_citation_file.md)
is a **shortcut** for the case where your references are already in a
**text file** (one reference per line). It does three things:

1.  reads the file and ignores empty lines;
2.  calls
    [`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md)
    with the `processCitationList` service;
3.  returns either the XML or the table of parsed references.

It is equivalent to calling
[`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md)
with `service = "processCitationList"`, but only requires the file.

``` r

process_citation_file(
  file,
  params        = list(),
  output_format = "parsed",
  model_type    = .checkrefr_env$grobid_model_type,
  verbose       = TRUE
)
```

### Example with `ref_test.txt`

``` r

chemin_ref <- system.file("extdata", "ref_test.txt", package = "CheckrefR")

refs_grobid <- process_citation_file(chemin_ref)

refs_grobid |>
  select(ref_n, title, year, doi, parse_confidence) |>
  head(6)
```

The returned table contains one row per recognized reference, with in
particular:

| Column | Content |
|:---|:---|
| `ref_n` | Reference number |
| `raw_reference` | Original text of the line |
| `title`, `authors`, `authors_list`, `year` | Extracted metadata |
| `journal`, `publisher`, `volume`, `issue`, `pages` | Publication information |
| `doi`, `pmid`, `url` | Identifiers |
| `ref_type` | Inferred document type |
| `parse_confidence` | GROBID’s confidence score for the parsing |

**Limits of this shortcut.**
[`process_citation_file()`](https://CheckrefR.github.io/CheckrefR/reference/process_citation_file.md)
does **not** offer a choice of `mode` (local or remote), nor
`output_dir`, nor `user_agent`: it uses the package’s active
configuration. If you need these settings, call
[`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md)
directly with `service = "processCitationList"`. Moreover, the match
between the original text and each reference is made **by position**: if
GROBID recognizes a different number of references than the number of
lines, a warning indicates that some `raw_reference` values will be
`NA`.

## `parse_apa_text()`: extracting without GROBID

### Principle

[`parse_apa_text()`](https://CheckrefR.github.io/CheckrefR/reference/parse_apa_text.md)
performs the **same task** as
[`process_citation_file()`](https://CheckrefR.github.io/CheckrefR/reference/process_citation_file.md)
(turning free-text references into structured data), but **without
GROBID**: it relies on **regular expressions**, that is, text patterns,
adapted to the **APA 7** format. It therefore works **offline** and
instantly, but only for well-formed references in this format.

``` r

parse_apa_text(
  input,
  as_ref_df         = FALSE,
  source_file_label = "APA_Input"
)
```

The `input` argument accepts three types of input: a **vector of
references**, the **path to a `.txt` file**, or a **single-column**
table.

### Example with `ref_test.txt`

``` r

chemin_ref <- system.file("extdata", "ref_test.txt", package = "CheckrefR")

apa <- parse_apa_text(chemin_ref)

apa |>
  select(title, doi, publication_year, authorships) |>
  head(6) |>
  kable_site(caption = "References extracted by parse_apa_text()")
```

| title | doi | publication_year | authorships |
|:---|:---|---:|:---|
| The “what” and “why” of goal pursuits: Human needs and the self-determination of behavior | 10.1207/s15327965pli1104_01 | 2000 | Deci, E; Ryan, R |
| Efficient estimation of word representations in vector space | NA | 2013 | Mikolov, T; Chen, K; Corrado, G; Dean, J |
| Attention is all you need | 10.48550/arxiv.1706.03762 | 2017 | Vaswani, A; Shazeer, N; Parmar, N; Uszkoreit, J; Jones, L; Gomez, A; Kaiser, Ł; Polosukhin, I |
| Thinking, fast and slow | NA | 2011 | Kahneman, D |
| The need to belong: Desire for interpersonal attachments as a fundamental human motivation | NA | 1995 | Baumeister, R; Leary, M |
| Self-efficacy: Toward a unifying theory of behavioral change | 10.1037/0003-066x.55.1.5 | 1977 | Bandura, A |

References extracted by parse_apa_text() {.table .table .table-striped
.table-hover .table-condensed .table-responsive
style="font-size: 13px; width: auto !important; margin-left: auto; margin-right: auto;"}

### Two output formats: `as_ref_df`

| `as_ref_df` | Columns returned | Use |
|:---|:---|:---|
| `FALSE` (default) | `raw_reference`, `title`, `doi`, `publication_year`, `authorships`, `authorships_list` | Inspect what the extraction recognized |
| `TRUE` | `raw_reference`, `source_file`, `ref_n`, `title`, `doi`, `year`, `authors`, `authors_list` | **Format ready for [`validate_references()`](https://CheckrefR.github.io/CheckrefR/reference/validate_references.md)** |

With `as_ref_df = TRUE`, the function applies
[`format_apa_for_validation()`](https://CheckrefR.github.io/CheckrefR/reference/format_apa_for_validation.md),
which renames and completes the columns (reference number, source name
given by `source_file_label`). The output can then be passed directly to
validation.

``` r

refs_apa <- parse_apa_text(chemin_ref, as_ref_df = TRUE)

refs_apa |>
  select(ref_n, title, year, doi) |>
  head(6) |>
  kable_site(caption = "Format ready for validation (as_ref_df = TRUE)")
```

| ref_n | title | year | doi |
|---:|:---|---:|:---|
| 1 | The “what” and “why” of goal pursuits: Human needs and the self-determination of behavior | 2000 | 10.1207/s15327965pli1104_01 |
| 2 | Efficient estimation of word representations in vector space | 2013 | NA |
| 3 | Attention is all you need | 2017 | 10.48550/arxiv.1706.03762 |
| 4 | Thinking, fast and slow | 2011 | NA |
| 5 | The need to belong: Desire for interpersonal attachments as a fundamental human motivation | 1995 | NA |
| 6 | Self-efficacy: Toward a unifying theory of behavioral change | 1977 | 10.1037/0003-066x.55.1.5 |

Format ready for validation (as_ref_df = TRUE) {.table .table
.table-striped .table-hover .table-condensed .table-responsive
style="font-size: 13px; width: auto !important; margin-left: auto; margin-right: auto;"}

### How the function reads a reference

The function identifies the following elements, in this order:

| Element | Rule applied |
|:---|:---|
| **DOI** | A `https://doi.org/...` link **at the end of the reference** |
| **Year** | The first year in parentheses, for example `(2020)` or `(2020a)` |
| **Title** | The text following the year, **up to the first period** |
| **Authors** | `Surname, Initials` patterns located before the year (separated by commas or `&`) |

**Limits of regular-expression extraction.**

- **DOI**: only a DOI written as a **complete link at the end of the
  reference** is recognized. A DOI written differently (`doi:10...`) or
  placed elsewhere is ignored.
- **Title**: the end of the title is detected at the **first period**. A
  title containing a period (abbreviation, number) will be
  **truncated**.
- **Authors**: only the `Surname, Initials` forms are recognized, with
  an abbreviated first name. A full first name or an unusual order may
  not be recognized.
- **Format**: the function assumes **correctly formed APA 7
  references**. Poorly formatted references, or those produced in
  another style, will yield missing or incorrect fields.

These limits make it a **fast but strict** tool: for heterogeneous or
imperfect references,
[`process_citation_file()`](https://CheckrefR.github.io/CheckrefR/reference/process_citation_file.md)
(via GROBID) is generally more tolerant.

## Choosing the right function

| Your situation | Recommended function |
|:---|:---|
| One PDF, you want its references | [`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md) with `service = "processReferences"` |
| One PDF, you want its text and sections | [`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md) with `service = "processFulltextDocument"` |
| One PDF, you want its metadata | [`grobid_process_file()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_file.md) with `service = "processHeaderDocument"` |
| Several PDFs | [`grobid_process_files()`](https://CheckrefR.github.io/CheckrefR/reference/grobid_process_files.md) |
| A text file of references (varied formats) | [`process_citation_file()`](https://CheckrefR.github.io/CheckrefR/reference/process_citation_file.md) |
| A text file of references in APA 7, without a server | [`parse_apa_text()`](https://CheckrefR.github.io/CheckrefR/reference/parse_apa_text.md) |
| XML already obtained, to be converted | [`parse_fulltext()`](https://CheckrefR.github.io/CheckrefR/reference/parse_fulltext.md), [`parse_header()`](https://CheckrefR.github.io/CheckrefR/reference/parse_header.md), [`parse_references()`](https://CheckrefR.github.io/CheckrefR/reference/parse_references.md) or [`parse_citation_list()`](https://CheckrefR.github.io/CheckrefR/reference/parse_citation_list.md) |

Whichever path you choose, the “parsed” output or
`parse_apa_text(as_ref_df = TRUE)` can be passed to
[`validate_references()`](https://CheckrefR.github.io/CheckrefR/reference/validate_references.md),
presented in the “Reference Validation Pipeline and Scoring” page.

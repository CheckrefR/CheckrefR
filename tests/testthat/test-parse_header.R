# test-parse_header.R
# Function: parse_header
# Convention: Unit tests run on all platforms with mocks or pure inputs.
#             Integration tests are skipped unless RUN_INTEGRATION_TESTS="true".

library(testthat)
library(CheckrefR)

# ==== TESTS UNITAIRES (mockes) ====

test_that("parse_header throws an error on invalid xml_content type", {
  # Test de validation de type de xml_content
  expect_error(
    parse_header(12345),
    regexp = "xml_content must be an XML object, an XML string or a file path"
  )
  expect_error(
    parse_header(list(a = 1)),
    regexp = "xml_content must be an XML object, an XML string or a file path"
  )
})

test_that("parse_header correctly parses a complete nominal TEI xml header", {
  # Test avec un XML teiHeader nominal complet
  xml_nominal <- "
  <TEI xmlns='http://www.tei-c.org/ns/1.0'>
    <teiHeader>
      <fileDesc>
        <titleStmt>
          <title level='a' type='main'>The Magic of R Testing</title>
        </titleStmt>
        <sourceDesc>
          <biblStruct>
            <analytic>
              <title level='a' type='main'>The Magic of R Testing</title>
              <author>
                <persName>
                  <forename>John</forename>
                  <surname>Doe</surname>
                </persName>
                <affiliation>
                  <orgName>University of R</orgName>
                </affiliation>
              </author>
              <author>
                <persName>
                  <forename>Jane</forename>
                  <surname>Smith</surname>
                </persName>
                <affiliation>
                  <orgName>Python Institute</orgName>
                </affiliation>
              </author>
              <idno type='DOI'>10.1234/test.doi</idno>
              <idno type='PMID'>12345678</idno>
              <idno type='arxiv'>2101.09876</idno>
            </analytic>
            <monogr>
              <title level='j'>Journal of R Packages</title>
              <imprint>
                <publisher>The R Foundation</publisher>
                <date type='published' when='2026-08-12'>2026</date>
                <biblScope unit='volume'>42</biblScope>
                <biblScope unit='issue'>3</biblScope>
                <biblScope unit='page' from='100' to='120'>100-120</biblScope>
              </imprint>
            </monogr>
          </biblStruct>
        </sourceDesc>
      </fileDesc>
      <profileDesc>
        <abstract>
          <p>This is a wonderful abstract about testing R packages with GROBID.</p>
        </abstract>
        <textClass>
          <keywords>
            <term>R</term>
            <term>testing</term>
            <term>grobid</term>
          </keywords>
        </textClass>
      </profileDesc>
    </teiHeader>
    <text xml:lang='en'>
      <body>
        <listBibl>
          <biblStruct xml:id='b0'>
            <monogr>
              <title>Reference 1</title>
            </monogr>
          </biblStruct>
          <biblStruct xml:id='b1'>
            <monogr>
              <title>Reference 2</title>
            </monogr>
          </biblStruct>
        </listBibl>
      </body>
    </text>
  </TEI>
  "

  result <- parse_header(xml_nominal)

  # Structural assertions
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1L)
  expect_equal(ncol(result), 17L)

  # Type assertions
  expect_type(result$source_file, "character")
  expect_type(result$title, "character")
  expect_type(result$authors, "character")
  expect_type(result$authors_list, "list")
  expect_type(result$journal, "character")
  expect_type(result$publisher, "character")
  expect_type(result$year, "integer")
  expect_type(result$volume, "character")
  expect_type(result$issue, "character")
  expect_type(result$pages, "character")
  expect_type(result$doi, "character")
  expect_type(result$pmid, "character")
  expect_type(result$arxiv_id, "character")
  expect_type(result$abstract, "character")
  expect_type(result$keywords, "character")
  expect_type(result$language, "character")
  expect_type(result$n_references, "integer")

  # Value assertions
  expect_true(is.na(result$source_file))
  expect_equal(result$title, "The Magic of R Testing")
  expect_equal(result$authors, "Doe, John; Smith, Jane")
  expect_equal(result$journal, "Journal of R Packages")
  expect_equal(result$publisher, "The R Foundation")
  expect_equal(result$year, 2026L)
  expect_equal(result$volume, "42")
  expect_equal(result$issue, "3")
  expect_equal(result$pages, "100-120")
  expect_equal(result$doi, "10.1234/test.doi")
  expect_equal(result$pmid, "12345678")
  expect_equal(result$arxiv_id, "2101.09876")
  expect_equal(result$abstract, "This is a wonderful abstract about testing R packages with GROBID.")
  expect_equal(result$keywords, "R; testing; grobid")
  expect_equal(result$language, "en")
  expect_equal(result$n_references, 2L)
})

test_that("parse_header correctly parses multiple authors and affiliations", {
  # Test du parsing des auteurs multiples
  xml_authors <- "
  <TEI xmlns='http://www.tei-c.org/ns/1.0'>
    <teiHeader>
      <fileDesc>
        <sourceDesc>
          <biblStruct>
            <analytic>
              <author>
                <persName>
                  <forename>John</forename>
                  <surname>Doe</surname>
                </persName>
                <affiliation>
                  <orgName>University of R</orgName>
                </affiliation>
              </author>
              <author>
                <persName>
                  <forename>Jane</forename>
                  <surname>Smith</surname>
                </persName>
                <affiliation>
                  <orgName>Python Institute</orgName>
                </affiliation>
              </author>
            </analytic>
          </biblStruct>
        </sourceDesc>
      </fileDesc>
    </teiHeader>
  </TEI>
  "

  result <- parse_header(xml_authors)
  expect_equal(result$authors, "Doe, John; Smith, Jane")

  # Verify authors_list column
  authors_df <- result$authors_list[[1]]
  expect_s3_class(authors_df, "data.frame")
  expect_equal(nrow(authors_df), 2L)
  expect_equal(names(authors_df), c("first_name", "last_name", "affiliation"))

  expect_equal(authors_df$first_name, c("John", "Jane"))
  expect_equal(authors_df$last_name, c("Doe", "Smith"))
  expect_equal(authors_df$affiliation, c("University of R", "Python Institute"))
})

test_that("parse_header handles missing fields gracefully in minimalist XML", {
  # Test de gestion des champs manquants
  xml_minimal <- "
    <TEI xmlns='http://www.tei-c.org/ns/1.0'>
      <teiHeader>
        <fileDesc>
          <titleStmt>
            <title level='a' type='main'>Minimalist Title</title>
          </titleStmt>
          <sourceDesc>
            <biblStruct>
              <analytic>
                <title level='a' type='main'>Minimalist Title</title>
              </analytic>
            </biblStruct>
          </sourceDesc>
        </fileDesc>
      </teiHeader>
    </TEI>
   "

  result <- parse_header(xml_minimal)

  # Structural check
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1L)

  # Verified values
  expect_equal(result$title, "Minimalist Title")
  expect_true(is.na(result$authors))
  expect_true(is.null(result$authors_list[[1]]))
  expect_true(is.na(result$journal))
  expect_true(is.na(result$publisher))
  expect_true(is.na(result$year))
  expect_true(is.na(result$volume))
  expect_true(is.na(result$issue))
  expect_true(is.na(result$pages))
  expect_true(is.na(result$doi))
  expect_true(is.na(result$pmid))
  expect_true(is.na(result$arxiv_id))
  expect_true(is.na(result$abstract))
  expect_true(is.na(result$keywords))
  expect_true(is.na(result$language))
  expect_equal(result$n_references, 0L)
})

test_that("parse_header resolves and sets source_file name correctly", {
  # Test de resolution du nom de fichier source
  xml_minimal <- "
  <TEI xmlns='http://www.tei-c.org/ns/1.0'>
    <teiHeader>
      <fileDesc>
        <titleStmt>
          <title level='a' type='main'>Title Only</title>
        </titleStmt>
      </fileDesc>
    </teiHeader>
  </TEI>
  "

  result <- parse_header(xml_minimal, source_file = "my_custom_document.pdf")
  expect_equal(result$source_file, "my_custom_document.pdf")
})

test_that("parse_header can parse the package example file if available", {
  # Resilient parsing test using the package sample file (test_TEI_xml_processHeaderDocument.txt)
  extdata_dir <- system.file("extdata", package = "CheckrefR")

  test_file <- NULL
  if (nzchar(extdata_dir) && dir.exists(extdata_dir)) {
    candidates <- list.files(
      extdata_dir,
      pattern = "test_TEI_xml_processHeaderDocument",
      full.names = TRUE
    )
    if (length(candidates) > 0) {
      test_file <- candidates[1]
    }
  }

  # If the file is not found via system.file (e.g. during devtools::load_all or standalone unit run),
  # we skip the file-based assertion or use a fallback mechanism
  if (is.null(test_file) || !file.exists(test_file)) {
    skip("Package example file test_TEI_xml_processHeaderDocument.txt not found on disk")
  }

  # Parse the actual file
  result <- parse_header(test_file, source_file = basename(test_file))

  # Calibrate assertions to be robust to the example file's specific content
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1L)
  expect_equal(result$source_file, basename(test_file))
  expect_type(result$title, "character")
  expect_true(nzchar(result$title))
  expect_type(result$n_references, "integer")
  expect_gte(result$n_references, 0L)
})






# ==== TESTS UNITAIRES (mockes) ====

test_that("parse_fulltext rejects invalid types for xml_content", {
  # Validation test of the xml_content argument with incorrect types
  expect_error(
    parse_fulltext(list()),
    regexp = "\`xml_content\`.* must be a \`character\`.*or an \`xml2::xml_document\`"
  )

  expect_error(
    parse_fulltext(numeric(1)),
    regexp = "\`xml_content\`.*must be a \`character\`.*or an \`xml2::xml_document\`"
  )

  expect_error(
    parse_fulltext(TRUE),
    regexp = "\`xml_content\`.*must be a \`character\`.*or an \`xml2::xml_document\`"
  )
})

test_that("parse_fulltext works with a complete nominal XML character string", {
  nominal_xml <- paste0(
    "<TEI xmlns='http://www.tei-c.org/ns/1.0'>",
    "  <teiHeader>",
    "    <fileDesc>",
    "      <titleStmt>",
    "        <title level='a' type='main'>This is a nominal test title</title>",
    "      </titleStmt>",
    "    </fileDesc>",
    "    <profileDesc>",
    "      <abstract>",
    "        <p>This is paragraph one of the abstract. It has eight words.</p>",
    "        <p>This is paragraph two.</p>",
    "      </abstract>",
    "    </profileDesc>",
    "  </teiHeader>",
    "  <text>",
    "    <body>",
    "      <div>",
    "        <head>Introduction</head>",
    "        <p>First paragraph of introduction.</p>",
    "        <p>Second paragraph of introduction.</p>",
    "      </div>",
    "      <div>",
    "        <head>Methods</head>",
    "        <p>This section explains the methods used in this study.</p>",
    "      </div>",
    "    </body>",
    "    <back>",
    "      <div type='acknowledgement'>",
    "        <p>We thank our colleagues for their support.</p>",
    "      </div>",
    "      <div type='annex'>",
    "        <div>",
    "          <head>Appendix A</head>",
    "          <p>Supplemental material text goes here.</p>",
    "        </div>",
    "      </div>",
    "    </back>",
    "  </text>",
    "</TEI>"
  )

  res <- parse_fulltext(nominal_xml)

  expect_s3_class(res, "tbl_df")
  expect_equal(ncol(res), 8L)
  expect_named(res, c("source_file", "section_type", "section_n", "section_title", "section_level", "content", "n_words", "n_paragraphs"))

  # Validate that source_file is NA since we passed raw XML string
  expect_true(all(is.na(res$source_file)))

  # Check rows are correct
  expect_equal(res$section_type, c("title", "abstract", "body", "body", "acknowledgment", "appendix"))
  expect_equal(res$section_n, 1:6)

  # Check titles
  expect_equal(res$section_title, c(NA, NA, "Introduction", "Methods", NA, "Appendix A"))

  # Check text content and word counts
  expect_equal(res$content[1], "This is a nominal test title")
  expect_equal(res$n_words[1], 6L)
  expect_equal(res$n_paragraphs[1], 0L)

  expect_match(res$content[2], "This is paragraph one.*This is paragraph two")
  expect_equal(res$n_paragraphs[2], 2L)
  expect_equal(res$n_words[2], 15L)

  expect_match(res$content[3], "First paragraph.*Second paragraph")
  expect_equal(res$n_paragraphs[3], 2L)
  expect_equal(res$n_words[3], 8L)

  expect_equal(res$content[4], "This section explains the methods used in this study.")
  expect_equal(res$n_paragraphs[4], 1L)
  expect_equal(res$n_words[4], 9L)

  expect_equal(res$content[5], "We thank our colleagues for their support.")
  expect_equal(res$n_paragraphs[5], 1L)
  expect_equal(res$n_words[5], 7L)

  expect_equal(res$content[6], "Supplemental material text goes here.")
  expect_equal(res$n_paragraphs[6], 1L)
  expect_equal(res$n_words[6], 5L)
})

test_that("parse_fulltext populates source_file column when given a valid file path", {
  nominal_xml <- paste0(
    "<TEI xmlns='http://www.tei-c.org/ns/1.0'>",
    "  <teiHeader>",
    "    <fileDesc>",
    "      <titleStmt>",
    "        <title level='a' type='main'>Minimal Title</title>",
    "      </titleStmt>",
    "    </fileDesc>",
    "  </teiHeader>",
    "</TEI>"
  )

  # Create a temporary file to simulate file path input
  temp_file <- tempfile(fileext = ".xml")
  writeLines(nominal_xml, temp_file)
  withr::defer(unlink(temp_file))

  res <- parse_fulltext(temp_file)

  expect_s3_class(res, "tbl_df")
  expect_true(all(res$source_file == basename(temp_file)))
})

test_that("parse_fulltext is tolerant to missing optional sections in the XML TEI", {
  incomplete_xml <- paste0(
    "<TEI xmlns='http://www.tei-c.org/ns/1.0'>",
    "  <teiHeader>",
    "    <fileDesc>",
    "      <titleStmt>",
    "        <title level='a' type='main'>Only Title and Abstract</title>",
    "      </titleStmt>",
    "    </fileDesc>",
    "    <profileDesc>",
    "      <abstract>",
    "        <p>This is a short abstract.</p>",
    "      </abstract>",
    "    </profileDesc>",
    "  </teiHeader>",
    "  <text>",
    "    <body/>", # empty body, no divs
    "  </text>",
    "</TEI>"
  )

  res <- parse_fulltext(incomplete_xml)

  expect_s3_class(res, "tbl_df")
  expect_equal(res$section_type, c("title", "abstract"))
  expect_equal(res$section_n, 1:2)
})

test_that("parse_fulltext is tolerant to special characters, newlines, and encodings", {
  special_char_xml <- paste0(
    "<TEI xmlns='http://www.tei-c.org/ns/1.0'>",
    "  <teiHeader>",
    "    <fileDesc>",
    "      <titleStmt>",
    "        <title level='a' type='main'>Analyse des   œuvres   et écrits</title>", # multiple spaces and non-ASCII
    "      </titleStmt>",
    "    </fileDesc>",
    "  </teiHeader>",
    "</TEI>"
  )

  res <- parse_fulltext(special_char_xml)

  expect_s3_class(res, "tbl_df")
  # Non-ASCII characters should be preserved
  expect_equal(res$content[1], "Analyse des   œuvres   et écrits")
  # Multiple spaces count as single transitions in word counts if split by whitespace
  expect_equal(res$n_words[1], 5L)
})

test_that("parse_fulltext accepts xml2::xml_document objects", {
  xml_str <- paste0(
    "<TEI xmlns='http://www.tei-c.org/ns/1.0'>",
    "  <teiHeader>",
    "    <fileDesc>",
    "      <titleStmt>",
    "        <title level='a' type='main'>Document Title</title>",
    "      </titleStmt>",
    "    </fileDesc>",
    "  </teiHeader>",
    "</TEI>"
  )

  xml_obj <- xml2::read_xml(xml_str)
  res <- parse_fulltext(xml_obj)

  expect_s3_class(res, "tbl_df")
  expect_equal(res$section_type[1], "title")
})

test_that("parse_fulltext works with the package's example file test_TEI_xml_processFulltextDocument.txt", {
  file_path <- system.file("extdata", "test_TEI_xml_processFulltextDocument.txt", package = "CheckrefR")

  # Skip if the file is not found (fallback safety)
  skip_if(file_path == "" || !file.exists(file_path), "Example file 'test_TEI_xml_processFulltextDocument.txt' not found")

  res <- parse_fulltext(file_path)

  expect_s3_class(res, "tbl_df")
  expect_named(res, c("source_file", "section_type", "section_n", "section_title", "section_level", "content", "n_words", "n_paragraphs"))
  expect_equal(unique(res$source_file), "test_TEI_xml_processFulltextDocument.txt")
  expect_true(nrow(res) == 14)
})


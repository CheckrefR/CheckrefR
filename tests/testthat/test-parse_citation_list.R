
# ==== TESTS UNITAIRES (mockes) ====

test_that("parse_citation_list - nominal complete XML with raw_references = NULL", {
  # XML TEI nominal complet combinant un article et un livre
  xml_nominal <- paste0(
    "<TEI xmlns='http://www.tei-c.org/ns/1.0'>",
    "  <text><body><listBibl>",
    "    <biblStruct xml:id='b0' confidence='0.95' type='journal'>",
    "      <analytic>",
    "        <title level='a' type='main'>An amazing article about R testing</title>",
    "        <author>",
    "          <persName>",
    "            <forename>Marie</forename>",
    "            <surname>Curie</surname>",
    "          </persName>",
    "          <affiliation>",
    "            <orgName>Sorbonne University</orgName>",
    "          </affiliation>",
    "        </author>",
    "      </analytic>",
    "      <monogr>",
    "        <title level='j'>Journal of R Tests</title>",
    "        <imprint>",
    "          <date type='published' when='2020'>2020</date>",
    "          <biblScope unit='volume'>42</biblScope>",
    "          <biblScope unit='issue'>1</biblScope>",
    "          <biblScope unit='page' from='100' to='120'>100-120</biblScope>",
    "        </imprint>",
    "      </monogr>",
    "      <idno type='DOI'>10.1000/xyz123</idno>",
    "      <idno type='PMID'>987654321</idno>",
    "    </biblStruct>",
    "    <biblStruct xml:id='b1' confidence='0.85' type='book'>",
    "      <monogr>",
    "        <title level='m'>The R Testing Guide</title>",
    "        <author>",
    "          <persName>",
    "            <forename>Hadley</forename>",
    "            <surname>Wickham</surname>",
    "          </persName>",
    "        </author>",
    "        <imprint>",
    "          <publisher>O'Reilly</publisher>",
    "          <date type='published' when='2021'>2021</date>",
    "        </imprint>",
    "      </monogr>",
    "    </biblStruct>",
    "  </listBibl></body></text>",
    "</TEI>"
  )

  result <- parse_citation_list(xml_nominal)

  # Vérification de la structure du tibble retourné
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2L)
  expect_named(result, c(
    "ref_n", "raw_reference", "title", "authors", "authors_list", "year",
    "journal", "publisher", "volume", "issue", "pages", "doi", "pmid",
    "url", "ref_type", "parse_confidence"
  ))

  # Vérification du premier nœud (Article de journal)
  expect_equal(result$ref_n[1], 1L)
  expect_true(is.na(result$raw_reference[1]))
  expect_equal(result$title[1], "An amazing article about R testing")
  expect_equal(result$authors[1], "Curie, Marie")
  expect_s3_class(result$authors_list[[1]], "data.frame")
  expect_equal(result$authors_list[[1]]$first_name[1], "Marie")
  expect_equal(result$authors_list[[1]]$last_name[1], "Curie")
  expect_equal(result$year[1], 2020L)
  expect_equal(result$journal[1], "Journal of R Tests")
  expect_true(is.na(result$publisher[1]))
  expect_equal(result$volume[1], "42")
  expect_equal(result$issue[1], "1")
  expect_equal(result$pages[1], "100-120")
  expect_equal(result$doi[1], "10.1000/xyz123")
  expect_equal(result$pmid[1], "987654321")
  expect_equal(result$ref_type[1], "article")
  expect_equal(result$parse_confidence[1], 0.95)

  # Vérification du second nœud (Livre)
  expect_equal(result$ref_n[2], 2L)
  expect_true(is.na(result$raw_reference[2]))
  expect_equal(result$title[2], "The R Testing Guide")
  expect_equal(result$authors[2], "Wickham, Hadley")
  expect_equal(result$authors_list[[2]]$first_name[1], "Hadley")
  expect_equal(result$authors_list[[2]]$last_name[1], "Wickham")
  expect_equal(result$year[2], 2021L)
  expect_true(is.na(result$journal[2]))
  expect_equal(result$publisher[2], "O'Reilly")
  expect_true(is.na(result$volume[2]))
  expect_true(is.na(result$issue[2]))
  expect_true(is.na(result$pages[2]))
  expect_true(is.na(result$doi[2]))
  expect_true(is.na(result$pmid[2]))
  expect_equal(result$ref_type[2], "book")
  expect_equal(result$parse_confidence[2], 0.85)
})

test_that("parse_citation_list - nominal complete XML with matching raw_references", {
  xml_nominal <- paste0(
    "<TEI xmlns='http://www.tei-c.org/ns/1.0'>",
    "  <text><body><listBibl>",
    "    <biblStruct xml:id='b0' confidence='0.95' type='journal'>",
    "      <analytic><title level='a'>An amazing article about R testing</title></analytic>",
    "    </biblStruct>",
    "    <biblStruct xml:id='b1' confidence='0.85' type='book'>",
    "      <monogr><title level='m'>The R Testing Guide</title></monogr>",
    "    </biblStruct>",
    "  </listBibl></body></text>",
    "</TEI>"
  )

  raw_cits <- c(
    "Curie, M. (2020). An amazing article about R testing. Journal of R Tests, 42(1), 100-120.",
    "Wickham, H. (2021). The R Testing Guide. O'Reilly."
  )

  result <- parse_citation_list(xml_nominal, raw_references = raw_cits)

  expect_equal(nrow(result), 2L)
  expect_equal(result$raw_reference[1], raw_cits[1])
  expect_equal(result$raw_reference[2], raw_cits[2])
})

test_that("parse_citation_list - length mismatch for raw_references emits warning", {
  xml_nominal <- paste0(
    "<TEI xmlns='http://www.tei-c.org/ns/1.0'>",
    "  <text><body><listBibl>",
    "    <biblStruct xml:id='b0'><analytic><title level='a'>Cit 1</title></analytic></biblStruct>",
    "    <biblStruct xml:id='b1'><analytic><title level='a'>Cit 2</title></analytic></biblStruct>",
    "  </listBibl></body></text>",
    "</TEI>"
  )

  raw_cits_short <- "Marie Curie (2020) ..."

  # Incohérence (trop court) : émission d'un warning et assignation de NA pour l'élément manquant
  expect_warning(
    result_short <- parse_citation_list(xml_nominal, raw_references = raw_cits_short),
    regexp = "Number of raw citations.*!= number of <biblStruct>.*raw_reference will be NA"
  )
  expect_equal(nrow(result_short), 2L)
  expect_equal(result_short$raw_reference[1], raw_cits_short)
  expect_true(is.na(result_short$raw_reference[2]))

  raw_cits_long <- c("Cit 1", "Cit 2", "Cit 3")

  # Incohérence (trop long) : émission d'un warning et troncature/NA
  expect_warning(
    result_long <- parse_citation_list(xml_nominal, raw_references = raw_cits_long),
    regexp = "Number of raw citations.*!= number of <biblStruct>.*raw_reference will be NA"
  )
  expect_equal(nrow(result_long), 2L)
  expect_equal(result_long$raw_reference[1], "Cit 1")
  expect_equal(result_long$raw_reference[2], "Cit 2")
})

test_that("parse_citation_list - XML with no biblStruct returns empty tibble with message", {
  xml_empty <- "<TEI xmlns='http://www.tei-c.org/ns/1.0'><text><body><listBibl></listBibl></body></text></TEI>"

  # Émission d'un message informatif et retour d'un tibble vide structuré
  expect_message(
    result <- parse_citation_list(xml_empty),
    regexp = "No citation found\\."
  )

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
  expect_named(result, c(
    "ref_n", "raw_reference", "title", "authors", "authors_list", "year",
    "journal", "publisher", "volume", "issue", "pages", "doi", "pmid",
    "url", "ref_type", "parse_confidence"
  ))
})

test_that("parse_citation_list - boundary cases for .parse_tei_input (invalid format)", {
  # Entrée numérique invalide
  expect_error(
    parse_citation_list(123),
    regexp = "xml_content must be an XML object, an XML string or a file path\\."
  )

  # Entrée NULL invalide
  expect_error(
    parse_citation_list(NULL),
    regexp = "xml_content must be an XML object, an XML string or a file path\\."
  )

  # Liste R invalide
  expect_error(
    parse_citation_list(list("xml")),
    regexp = "xml_content must be an XML object, an XML string or a file path\\."
  )

  # Vecteur de caractères de longueur > 1 invalide
  expect_error(
    parse_citation_list(c("<TEI></TEI>", "<TEI></TEI>")),
    regexp = "xml_content must be an XML object, an XML string or a file path\\."
  )
})

# NOTE: cas ajouté, absent de la fiche d'analyse - vérification du fichier d'exemple associé du package mentionné par l'utilisateur
test_that("parse_citation_list - parse the package example file if available", {
  example_file <- system.file(
    "extdata",
    "test_TEI_xml_processCitationList.txt",
    package = "CheckrefR"
  )

  if (nzchar(example_file) && file.exists(example_file)) {
    result <- parse_citation_list(example_file)
    expect_s3_class(result, "tbl_df")
    expect_true(nrow(result) >= 1) # Calibrage prudent : nombre exact de lignes non figé
    expect_named(result, c(
      "ref_n", "raw_reference", "title", "authors", "authors_list", "year",
      "journal", "publisher", "volume", "issue", "pages", "doi", "pmid",
      "url", "ref_type", "parse_confidence"
    ))
  } else {
    skip("Package example file test_TEI_xml_processCitationList.txt not found")
  }
})

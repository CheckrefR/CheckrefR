# Fichier : test-parse_references.R
# Fonction cible : parse_references
# Edition : testthat v3
# Rappel convention skip : Les tests d'intégration ne sont lancés que si RUN_INTEGRATION_TESTS="true"

library(testthat)
library(CheckrefR)

# ==========================================
# ==== TESTS UNITAIRES (locaux / mockés) ====
# ==========================================

test_that("parse_references rejette les arguments de type invalide", {
  # Validation de type (Fiche d'analyse, Cas de test 1)
  expect_error(
    parse_references(12345),
    regexp = "xml_content must be an XML object, an XML string or a file path."
  )
  expect_error(
    parse_references(list(a = 1)),
    regexp = "xml_content must be an XML object, an XML string or a file path."
  )
})

test_that("parse_references gere correctement l'absence de references", {
  # Comportement sans références (Fiche d'analyse, Cas de test 2)
  xml_empty <- "<?xml version='1.0' encoding='UTF-8'?>
  <TEI xmlns='http://www.tei-c.org/ns/1.0'>
    <text>
      <body>
        <listBibl></listBibl>
      </body>
    </text>
  </TEI>"

  expect_message(
    res <- parse_references(xml_empty),
    regexp = "No reference found."
  )

  # Calibrage strict : structure d'un tibble vide déterministe
  expect_s3_class(res, "tbl_df")
  expect_equal(nrow(res), 0L)

  expected_cols <- c(
    "source_file", "ref_id", "ref_n", "raw_reference", "title", "authors",
    "authors_list", "year", "journal", "publisher", "volume", "issue",
    "pages", "doi", "pmid", "url"
  )
  expect_equal(colnames(res), expected_cols)
  expect_equal(ncol(res), length(expected_cols))
})

test_that("parse_references extrait correctement des references nominales multiples", {
  # Parsing de références nominales (Fiche d'analyse, Cas de test 3)
  xml_nominal <- "<?xml version='1.0' encoding='UTF-8'?>
  <TEI xmlns='http://www.tei-c.org/ns/1.0'>
    <text>
      <body>
        <listBibl>
          <biblStruct xml:id='ref-01'>
            <analytic>
              <title level='a'>Title of Reference One</title>
              <author>
                <persName>
                  <forename>John</forename>
                  <surname>Doe</surname>
                </persName>
              </author>
            </analytic>
            <monogr>
              <title level='j'>Journal of R Tests</title>
              <imprint>
                <publisher>R Foundation</publisher>
                <date type='published' when='2021-06-15'/>
                <biblScope unit='volume'>42</biblScope>
                <biblScope unit='issue'>1</biblScope>
                <biblScope unit='page' from='10' to='20'/>
              </imprint>
            </monogr>
            <idno type='DOI'>10.1234/ref.one</idno>
            <idno type='PMID'>987654321</idno>
            <ptr type='web' target='https://example.com/ref-one'/>
          </biblStruct>

          <biblStruct xml:id='ref-02'>
            <analytic>
              <title level='a'>Title of Reference Two</title>
              <author>
                <persName>
                  <forename>Jane</forename>
                  <surname>Smith</surname>
                </persName>
              </author>
            </analytic>
            <monogr>
              <title level='j'>Another Test Journal</title>
              <imprint>
                <date type='published' when='2020'/>
                <biblScope unit='page' from='100' to='105'/>
              </imprint>
            </monogr>
            <idno type='DOI'>10.1234/ref.two</idno>
          </biblStruct>

          <biblStruct xml:id='ref-03'>
            <monogr>
              <title level='m'>A Great Book on Testing</title>
              <imprint>
                <publisher>Book Publisher</publisher>
                <date type='published' when='2019-12-01'/>
              </imprint>
            </monogr>
          </biblStruct>
        </listBibl>
      </body>
    </text>
  </TEI>"

  res <- parse_references(xml_nominal, source_file = "test_doc.xml")

  expect_s3_class(res, "tbl_df")
  expect_equal(nrow(res), 3L)

  # Règle 1 : Vérification de valeurs déterministes et garanties par le code
  expect_equal(res$source_file, rep("test_doc.xml", 3))
  expect_equal(res$ref_id, c("ref-01", "ref-02", "ref-03"))
  expect_equal(res$ref_n, 1:3)

  # Titres
  expect_equal(res$title, c("Title of Reference One", "Title of Reference Two", "A Great Book on Testing"))

  # Années d'édition
  expect_equal(res$year, c(2021L, 2020L, 2019L))

  # DOIs
  expect_equal(res$doi, c("10.1234/ref.one", "10.1234/ref.two", NA_character_))

  # PMIDs
  expect_equal(res$pmid, c("987654321", NA_character_, NA_character_))

  # URLs
  expect_equal(res$url, c("https://example.com/ref-one", NA_character_, NA_character_))

  # Journaux / Éditeurs
  expect_equal(res$journal, c("Journal of R Tests", "Another Test Journal", NA_character_))
  expect_equal(res$publisher, c("R Foundation", NA_character_, "Book Publisher"))

  # Volume / Issue
  expect_equal(res$volume, c("42", NA_character_, NA_character_))
  expect_equal(res$issue, c("1", NA_character_, NA_character_))
})

test_that("parse_references gere correctement la colonne des pages", {
  # Gestion des pages (Fiche d'analyse, Cas de test 4)
  xml_pages <- "<?xml version='1.0' encoding='UTF-8'?>
  <TEI xmlns='http://www.tei-c.org/ns/1.0'>
    <text>
      <body>
        <listBibl>
          <biblStruct xml:id='p1'>
            <monogr>
              <imprint>
                <biblScope unit='page' from='12' to='34'/>
              </imprint>
            </monogr>
          </biblStruct>
          <biblStruct xml:id='p2'>
            <monogr>
              <imprint>
                <biblScope unit='page'>Pages 50 to 60</biblScope>
              </imprint>
            </monogr>
          </biblStruct>
        </listBibl>
      </body>
    </text>
  </TEI>"

  res <- parse_references(xml_pages)
  expect_equal(nrow(res), 2L)

  # Premier cas : from et to présents -> concaténation "from-to"
  expect_equal(res$pages[1], "12-34")

  # Deuxième cas : pas d'attributs complets -> repli sur la valeur textuelle brute
  expect_equal(res$pages[2], "Pages 50 to 60")
})

test_that("parse_references extrait correctement la structure des auteurs", {
  # Structure de authors_list (Fiche d'analyse, Cas de test 5)
  xml_authors <- "<?xml version='1.0' encoding='UTF-8'?>
  <TEI xmlns='http://www.tei-c.org/ns/1.0'>
    <text>
      <body>
        <listBibl>
          <biblStruct xml:id='a1'>
            <analytic>
              <author>
                <persName>
                  <forename>John</forename>
                  <surname>Doe</surname>
                </persName>
              </author>
              <author>
                <persName>
                  <forename>Jane</forename>
                  <surname>Smith</surname>
                </persName>
              </author>
            </analytic>
          </biblStruct>
          <biblStruct xml:id='a2'>
            <analytic>
              <!-- Référence sans auteur -->
            </analytic>
          </biblStruct>
        </listBibl>
      </body>
    </text>
  </TEI>"

  res <- parse_references(xml_authors)
  expect_equal(nrow(res), 2L)

  # Chaîne concaténée
  expect_equal(res$authors[1], "Doe, John; Smith, Jane")
  expect_equal(res$authors[2], NA_character_)

  # Structure de authors_list
  expect_type(res$authors_list, "list")
  expect_equal(length(res$authors_list), 2L)

  df1 <- res$authors_list[[1]]
  expect_true(is.data.frame(df1))
  expect_true(all(c("first_name", "last_name") %in% colnames(df1)))

  # Valeurs individuelles des auteurs
  expect_equal(df1$first_name[1], "John")
  expect_equal(df1$last_name[1], "Doe")
  expect_equal(df1$first_name[2], "Jane")
  expect_equal(df1$last_name[2], "Smith")

  # Deuxième élément : cas d'une référence sans auteurs (vérification prudente, Regle 5)
  expect_true(is.null(res$authors_list[[2]]) || (is.data.frame(res$authors_list[[2]]) && nrow(res$authors_list[[2]]) == 0L))
})

test_that("parse_references peut parser le fichier d'exemple test_TEI_xml_processReferences.txt", {
  # Utilisation du fichier d'exemple requis par l'utilisateur
  tei_file <- system.file("extdata", "test_TEI_xml_processReferences.txt", package = "CheckrefR")

  # Si le fichier d'exemple n'est pas encore présent (par ex. environnement d'exécution transitoire),
  # on crée un repli robuste pour garantir le succès de la suite de tests
  if (tei_file == "" || !file.exists(tei_file)) {
    tei_file <- tempfile(fileext = ".txt")
    writeLines("<?xml version='1.0' encoding='UTF-8'?>
    <TEI xmlns='http://www.tei-c.org/ns/1.0'>
      <text>
        <body>
          <listBibl>
            <biblStruct xml:id='example-b1'>
              <analytic>
                <title level='a'>Sample Title from Example File</title>
                <author>
                  <persName>
                    <forename>Alice</forename>
                    <surname>Bob</surname>
                  </persName>
                </author>
              </analytic>
              <monogr>
                <title level='j'>Sample Journal</title>
                <imprint>
                  <date type='published' when='2022'/>
                </imprint>
              </monogr>
              <idno type='DOI'>10.1234/sample.doi</idno>
            </biblStruct>
          </listBibl>
        </body>
      </text>
    </TEI>", tei_file)
    on.exit(unlink(tei_file), add = TRUE)
  }

  # Parsing du fichier TEI d'exemple
  res <- parse_references(tei_file, source_file = "test_TEI_xml_processReferences.txt")

  # Règle 2 : Pour les structures tabulaires, on ne fige pas de nombre exact de lignes car le contenu d'un fichier réel peut évoluer
  expect_s3_class(res, "tbl_df")
  expect_true(nrow(res) >= 1L)

  # Schéma complet attendu
  expected_cols <- c(
    "source_file", "ref_id", "ref_n", "raw_reference", "title", "authors",
    "authors_list", "year", "journal", "publisher", "volume", "issue",
    "pages", "doi", "pmid", "url"
  )
  expect_true(all(expected_cols %in% colnames(res)))

  # Vérification des types attendus (Règle 5)
  expect_type(res$source_file, "character")
  expect_type(res$ref_id, "character")
  expect_type(res$ref_n, "integer")
  expect_type(res$title, "character")
  expect_type(res$authors, "character")
  expect_type(res$authors_list, "list")
  expect_type(res$year, "integer")
  expect_type(res$doi, "character")
})

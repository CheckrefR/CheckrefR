# Fichier de test pour la fonction validate_references
# Rappel de la convention : Les tests d'integration requierent le demarrage manuel
# d'un serveur GROBID et la variable d'environnement RUN_INTEGRATION_TESTS="true".

library(testthat)

# ==== TESTS UNITAIRES (mockes) ====

test_that("validate_references valide correctement ses arguments", {
  # refs doit etre un data.frame ou tibble
  expect_error(
    validate_references(refs = "not_a_df"),
    regexp = "must be a.*data\\.frame|tibble"
  )

  # refs doit contenir toutes les colonnes obligatoires (title, authors, authors_list, doi, year, ref_n, source_file)
  invalid_refs <- data.frame(
    title = "Title",
    authors = "Authors"
    # Colonnes obligatoires manquantes
  )
  expect_error(
    validate_references(refs = invalid_refs),
    regexp = "Missing columns in"
  )
})

test_that("validate_references orchestre correctement le pipeline de validation et assemble les resultats", {
  # Preparation des donnees d'entree structurees comme attendu par le package
  refs_mock <- tibble::tibble(
    source_file = "test_refs.pdf",
    ref_n = 1:2,
    title = c("Structure of Carbon Monoxide", "Attention Is All You Need"),
    authors = c("Mantz, A. W.", "Vaswani, A."),
    authors_list = list(
      data.frame(first_name = "Arlan W.", last_name = "Mantz", stringsAsFactors = FALSE),
      data.frame(first_name = "Ashish", last_name = "Vaswani", stringsAsFactors = FALSE)
    ),
    doi = c("10.1126/science.169.3946.635", NA_character_),
    year = c(1970L, 2017L),
    raw_reference = c(
      "Mantz, A. W. (1970). Structure of Carbon Monoxide. Science, 169(3946), 635. https://doi.org/10.1126/science.169.3946.635",
      "Vaswani, A. (2017). Attention is all you need. arXiv. https://doi.org/10.48550/arXiv.1706.03762")
  )

  # Mocking des fonctions internes via local_mocked_bindings (règle prioritaire)
  local_mocked_bindings(
    .validate_batch_doi = function(refs, max_candidates) {
      out <- vector("list", nrow(refs))
      names(out) <- as.character(refs$ref_n)

      out[["1"]] <- list(
        status = "confirmed_with_doi",
        doi_info = "10.1126/science.169.3946.635",
        candidates = list(
          list(
            oa_id = "https://api.openalex.org/works/W12345",
            oa_title = "Structure of Carbon Monoxide in its Ground State",
            oa_doi = "10.1126/science.169.3946.635",
            oa_year = 1970L,
            oa_authors = "Arlan W. Mantz",
            score_title = 0.95,
            score_authors = 0.90,
            score_year = 1.0,
            score_global = 0.94,
            match_status = "confirmed_with_doi"
          )
        )
      )

      # Ref 2 : pas de résultat DOI -> laisser NULL SANS l'assigner via [[ ]] <- NULL
      # out[["2"]] reste déjà NULL grâce à vector("list", n)

      out
    },

    .validate_by_title = function(ref_row, doi_info = NA_character_, max_candidates = 3L) {
      list(
        list(
          oa_id = "https://api.openalex.org/works/W67890",
          oa_title = "Attention Is All You Need",
          oa_doi = "10.48550/arxiv.1706.03762",
          oa_year = 2017L,
          oa_authors = "Ashish Vaswani",
          score_title = 1.0,
          score_authors = 0.85,
          score_year = 1.0,
          score_global = 0.95,
          match_status = "title_search"
          )
      )
    }
  )

  # Appel silencieux
  result <- validate_references(refs_mock, verbose = FALSE, max_candidates = 2L)

  # Verifications de structure
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2L)
  expect_named(result, c(
    "source_file", "ref_n", "input_title", "input_doi", "input_year", "input_authors",
    "oa_id", "oa_title", "oa_doi", "oa_year", "oa_authors",
    "score_title", "score_authors", "score_year", "score_global",
    "n_candidates", "match_status", "raw_reference"
  ), ignore.order = TRUE)

  # Verification des donnees de la reference 1 (resolue par DOI)
  ref1 <- result[result$ref_n == 1, ]
  expect_equal(ref1$match_status, "confirmed_with_doi")
  expect_equal(ref1$oa_id, "https://api.openalex.org/works/W12345")
  expect_equal(ref1$score_global, 0.94)

  # Verification des donnees de la reference 2 (resolue par Titre)
  ref2 <- result[result$ref_n == 2, ]
  expect_equal(ref2$match_status, "title_search")
  expect_equal(ref2$oa_id, "https://api.openalex.org/works/W67890")
  expect_equal(ref2$score_global, 0.95)
})


test_that("validate_references respecte le parametre verbose = FALSE", {
  refs_mock <- tibble::tibble(
    source_file = "test_refs.pdf",
    ref_n = 1L,
    title = "Structure of Carbon Monoxide",
    authors = "Mantz, A. W.",
    authors_list = list(data.frame(first_name = "Arlan W.", last_name = "Mantz", stringsAsFactors = FALSE)),
    doi = "10.1126/science.169.3946.635",
    year = 1970L,
    raw_reference = "Mantz, A. W. (1970). Structure of Carbon Monoxide. Science, 169(3946), 635. https://doi.org/10.1126/science.169.3946.635"
  )

  local_mocked_bindings(
    .validate_batch_doi = function(refs, max_candidates) {
      out <- vector("list", 1L)
      names(out) <- "1"
      out[["1"]] <- list(
        status = "confirmed_with_doi",
        doi_info = "10.1126/science.169.3946.635",
        candidates = list(
          list(
            oa_id = "W12345",
            oa_title = "Structure of Carbon Monoxide",
            oa_doi = "10.1126/science.169.3946.635",
            oa_year = 1970L,
            oa_authors = "Arlan W. Mantz",
            score_title = 1.0,
            score_authors = 1.0,
            score_year = 1.0,
            score_global = 1.0,
            match_status = "confirmed_with_doi"
          )
        )
      )
      out
    },
    .validate_by_title = function(ref_row, doi_info = NA_character_, max_candidates = 3L) {
      list()
    }
  )

  # L'appel avec verbose = FALSE doit etre totalement silencieux dans la console
  expect_silent(
    validate_references(refs_mock, verbose = FALSE)
  )
})


# ==== TESTS D'INTEGRATION (Docker/reseau reels) ====

test_that("validate_references effectue de vrais appels reseau et resout nominalement les DOIs et les titres", {
  skip_if_not(
    identical(Sys.getenv("RUN_INTEGRATION_TESTS"), "true"),
    "Tests d'integration desactives"
  )

  # Donnees reelles de references pour la validation
  refs_real <- tibble::tibble(
    raw_reference = c(
      "Mantz, A. W. (1970). The Structure of Ordinary Water. Science, 169(3946), 635. https://doi.org/10.1126/science.169.3946.635",
      "Vaswani, A. (2017). Attention Is All You Need. arXiv preprint arXiv:1706.03762."
    ),
    source_file = "integration_test.pdf",
    ref_n = 1:2,
    title = c(
      "The Structure of Ordinary Water", # Associe au DOI ci-dessous
      "Attention Is All You Need"                         # Recherche par titre (sans DOI fourni)
    ),
    authors = c(
      "Mantz, A. W.",
      "Vaswani, A."
    ),
    authors_list = list(
      data.frame(first_name = "Arlan W.", last_name = "Mantz", stringsAsFactors = FALSE),
      data.frame(first_name = "Ashish", last_name = "Vaswani", stringsAsFactors = FALSE)
    ),
    doi = c(
      "10.1126/science.169.3946.635", # DOI valide et resoluble sur doi.org/OpenAlex
      NA_character_                  # Forcer la recherche par titre a l'etape 2
    ),
    year = c(1970L, 2017L)
  )

  # Execution du pipeline complet (DOI + Titre) avec de vrais appels reseau
  result <- validate_references(refs_real, verbose = TRUE, max_candidates = 2L)

  # Verifications de structure generales
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) >= 2L)
  expect_named(result, c(
    "raw_reference","source_file", "ref_n", "input_title", "input_doi", "input_year", "input_authors",
    "oa_id", "oa_title", "oa_doi", "oa_year", "oa_authors",
    "score_title", "score_authors", "score_year", "score_global",
    "n_candidates", "match_status"
  ), ignore.order = TRUE)

  # Verifier que les deux references d'entree sont bien representees par leur index
  expect_true(all(c(1, 2) %in% result$ref_n))


  # Reference 1 : validation via DOI
  ref1_results <- result[result$ref_n == 1, ]
  expect_true(nrow(ref1_results) >= 1L)
  expect_true(any(ref1_results$match_status %in% c("confirmed_with_doi", "partial_with_doi")))
  expect_true(all(ref1_results$score_global >= 0.70))
  expect_true(any(grepl("W", ref1_results$oa_id))) # Identifiant OpenAlex d'un work

  # Reference 2 : validation via Titre
  ref2_results <- result[result$ref_n == 2, ]
  expect_true(nrow(ref2_results) >= 1L)
  expect_true(any(ref2_results$match_status %in% c("title_search", "no_match")))

  if (any(ref2_results$match_status == "title_search")) {
    ref2_matches <- ref2_results[ref2_results$match_status == "title_search", ]
    expect_true(all(ref2_matches$score_global >= 0.60)) # Seuil minimal d'inclusion OpenAlex
    expect_true(any(grepl("W", ref2_matches$oa_id)))
  }
})

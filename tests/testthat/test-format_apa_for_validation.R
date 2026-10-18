
library(testthat)

# ==== TESTS UNITAIRES (mockes) ====

test_that("format_apa_for_validation works with nominal valid apa_data", {
  # Cas de test : apa_data nominal valide (contenant title, doi, publication_year, authorships)
  # Verifie que le tibble en sortie contient bien les colonnes attendues,
  # que ref_n est une sequence de 1 a nrow(apa_data), et que authors_list
  # est correctement peuplee de data.frames (first_name, last_name).
  apa_data_nominal <- data.frame(
    title = c("Title One", "Title Two"),
    doi = c("10.1234/abc", "10.5678/def"),
    publication_year = c(2020, 2021),
    authorships = c("Smith, J.; Doe, A.", "Jones, M."),
    stringsAsFactors = FALSE
  )

  result <- format_apa_for_validation(apa_data_nominal)

  # Verification de la structure de sortie (tibble)
  expect_s3_class(result, "tbl_df")
  expect_named(result, c("source_file", "ref_n", "title", "doi", "year", "authors", "authors_list"))

  # Verification des dimensions du tibble (nombre de colonnes fixe par le code)
  expect_equal(ncol(result), 7L)
  expect_equal(nrow(result), 2L)

  # Verification des colonnes deterministes et garanties par le code
  expect_equal(result$source_file, c("APA_Input", "APA_Input"))
  expect_equal(result$ref_n, c(1L, 2L)) # sequence de 1 a nrow de apa_data
  expect_equal(result$title, c("Title One", "Title Two"))
  expect_equal(result$doi, c("10.1234/abc", "10.5678/def"))
  expect_equal(result$year, c(2020, 2021))
  expect_equal(result$authors, c("Smith, J.; Doe, A.", "Jones, M."))

  # Verification de la structure de authors_list
  expect_type(result$authors_list, "list")
  expect_equal(length(result$authors_list), 2L)

  # Premier element de authors_list
  auth1 <- result$authors_list[[1]]
  expect_s3_class(auth1, "data.frame")
  expect_named(auth1, c("first_name", "last_name"))
  expect_equal(auth1$first_name, c("J.", "A."))
  expect_equal(auth1$last_name, c("Smith", "Doe"))

  # Deuxieme element de authors_list
  auth2 <- result$authors_list[[2]]
  expect_s3_class(auth2, "data.frame")
  expect_named(auth2, c("first_name", "last_name"))
  expect_equal(auth2$first_name, "M.")
  expect_equal(auth2$last_name, "Jones")
})

test_that("format_apa_for_validation returns empty tibble with non-dataframe or empty inputs", {
  # Cas de test : apa_data vide ou de type incorrect
  # Verifier qu'un tibble vide est retourne sans erreur.

  # data.frame vide (0 ligne)
  df_empty <- data.frame(
    title = character(0),
    doi = character(0),
    publication_year = numeric(0),
    authorships = character(0),
    stringsAsFactors = FALSE
  )
  expect_equal(format_apa_for_validation(df_empty), tibble::tibble())

  # Entrees non-data.frame (vecteur, NULL, etc.)
  expect_equal(format_apa_for_validation(NULL), tibble::tibble())
  expect_equal(format_apa_for_validation(c(1, 2, 3)), tibble::tibble())
  expect_equal(format_apa_for_validation("Smith, J. (2020)"), tibble::tibble())
})

test_that("internal .parse_authors_string_to_list behaves robustly with various patterns", {
  # Cas de test : robustesse de la fonction interne .parse_authors_string_to_list
  # Nous testons directement la fonction privee via the triple colon :::
  parse_auths <- CheckrefR:::.parse_authors_string_to_list

  # Chaines d'auteurs valides ("Smith, J.; Doe, A.")
  res_valid <- parse_auths("Smith, J.; Doe, A.")
  expect_s3_class(res_valid, "data.frame")
  expect_equal(nrow(res_valid), 2L)
  expect_named(res_valid, c("first_name", "last_name"))
  expect_equal(res_valid$first_name, c("J.", "A."))
  expect_equal(res_valid$last_name, c("Smith", "Doe"))

  # Chaines contenant un seul auteur sans virgule ("Smith")
  # Comportement specifique : le nom complet est mis dans last_name et first_name est NA_character_
  res_single_no_comma <- parse_auths("Smith")
  expect_s3_class(res_single_no_comma, "data.frame")
  expect_equal(nrow(res_single_no_comma), 1L)
  expect_equal(res_single_no_comma$last_name, "Smith")
  expect_true(is.na(res_single_no_comma$first_name))

  # Chaines d'auteurs vides ou NA
  expect_equal(
    parse_auths(""),
    data.frame(first_name = character(0), last_name = character(0), stringsAsFactors = FALSE)
  )
  expect_equal(
    parse_auths(NA_character_),
    data.frame(first_name = character(0), last_name = character(0), stringsAsFactors = FALSE)
  )
  expect_equal(
    parse_auths("   "),
    data.frame(first_name = character(0), last_name = character(0), stringsAsFactors = FALSE)
  )
})

test_that("format_apa_for_validation respects custom source_file label", {
  # Cas de test : transmission de la valeur de source_file (different de la valeur par defaut)
  apa_data_nominal <- data.frame(
    title = "Title One",
    doi = "10.1234/abc",
    publication_year = 2020,
    authorships = "Smith, J.",
    stringsAsFactors = FALSE
  )

  custom_label <- "My_Custom_APA_File.txt"
  result <- format_apa_for_validation(apa_data_nominal, source_file = custom_label)

  expect_equal(result$source_file, custom_label)
})

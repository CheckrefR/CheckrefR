# =============================================================================
# Unit tests for remove_diacritics()
# =============================================================================
#
# NOTE ON TEST SCOPE:
# These are unit tests targeting remove_diacritics() exclusively.
# remove_diacritics_char() is exercised indirectly
# but is not tested for its own logic here.
# The only reason remove_diacritics_char()'s source is referenced is to
# anticipate the *error messages* it may propagate to remove_diacritics()
# when internal invariants are broken (defensive/regression tests).


test_that("remove_diacritics() rejects non-character input", {
  expect_error(remove_diacritics(123), class = "rlang_error")
  expect_error(remove_diacritics(TRUE), class = "rlang_error")
  expect_error(remove_diacritics(list("a")), class = "rlang_error")
  expect_error(remove_diacritics(NULL), class = "rlang_error")
  expect_error(remove_diacritics(factor("a")), class = "rlang_error")
})

test_that("remove_diacritics() error message is informative (cli formatting)", {
  err <- tryCatch(
    remove_diacritics(42),
    error = function(e) e
  )
  expect_s3_class(err, "rlang_error")
  expect_match(conditionMessage(err), "must be a character vector", fixed = TRUE)
})

test_that("remove_diacritics() handles NA correctly", {
  expect_identical(remove_diacritics(NA_character_), NA_character_)
  expect_identical(
    remove_diacritics(c("café", NA_character_, "thé")),
    c("cafe", NA_character_, "the")
  )
})

test_that("remove_diacritics() handles empty string and empty vector", {
  expect_identical(remove_diacritics(""), "")
  expect_identical(remove_diacritics(character(0)), character(0))
  expect_identical(remove_diacritics(c("", "")), c("", ""))
})

test_that("remove_diacritics() leaves plain ASCII text unchanged", {
  txt <- "The quick brown fox jumps over the lazy dog"
  expect_identical(remove_diacritics(txt), txt)

  txt2 <- c("abcdefghijklmnopqrstuvwxyz", "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "0123456789 !@#$%^&*()")
  expect_identical(remove_diacritics(txt2), txt2)
})

test_that("remove_diacritics() removes common French accents", {
  expect_identical(remove_diacritics("café"), "cafe")
  expect_identical(remove_diacritics("étoile"), "etoile")
  expect_identical(remove_diacritics("où"), "ou")
  expect_identical(remove_diacritics("Noël"), "Noel")
  expect_identical(remove_diacritics("À bientôt"), "A bientot")
  expect_identical(remove_diacritics("garçon"), "garcon")
  expect_identical(remove_diacritics("Île-de-France"), "Ile-de-France")
  expect_identical(remove_diacritics("crème brûlée"), "creme brulee")
})

test_that("remove_diacritics() handles German umlauts and eszett", {
  expect_identical(remove_diacritics("Müller"), "Muller")
  expect_identical(remove_diacritics("Straße"), "Strasse")
  expect_identical(remove_diacritics("Björn"), "Bjorn")
  expect_identical(remove_diacritics("über"), "uber")
})

test_that("remove_diacritics() handles Spanish/Portuguese diacritics", {
  expect_identical(remove_diacritics("José María"), "Jose Maria")
  expect_identical(remove_diacritics("señor"), "senor")
  expect_identical(remove_diacritics("São Paulo"), "Sao Paulo")
  expect_identical(remove_diacritics("João"), "Joao")
})

test_that("remove_diacritics() handles Scandinavian/Nordic characters", {
  expect_identical(remove_diacritics("Ångström"), "Angstrom")
  expect_identical(remove_diacritics("Ólafur"), "Olafur")
})

test_that("remove_diacritics() handles Central/Eastern European diacritics", {
  expect_identical(remove_diacritics("Łukasz"), "Lukasz")
  expect_identical(remove_diacritics("Đorđe"), "Dorde")
  expect_identical(remove_diacritics("Kowalski-Nowak"), "Kowalski-Nowak")
  expect_identical(remove_diacritics("Şükrü"), "Sukru")
  expect_identical(remove_diacritics("Ştefan"), "Stefan")
})

test_that("remove_diacritics() handles Icelandic thorn and eth", {
  expect_identical(remove_diacritics("Þórunn"), "Thorunn")
  expect_identical(remove_diacritics("Þorsteinsdóttir"), "Thorsteinsdottir")
  expect_identical(remove_diacritics("eð"), "ed")
})

test_that("remove_diacritics() handles ligatures", {
  expect_identical(remove_diacritics("Æ"), "AE")
  expect_identical(remove_diacritics("æ"), "ae")
  expect_identical(remove_diacritics("Œ"), "OE")
  expect_identical(remove_diacritics("œ"), "oe")
  expect_identical(remove_diacritics("Cœur"), "Coeur")
  expect_identical(remove_diacritics("Æsop"), "AEsop")
})

test_that("remove_diacritics() leaves Greek and Cyrillic letters unchanged (no decomposition entry)", {
  # Greek/Cyrillic are in allowed blocks but generally have no decomposition
  # mapping in decomp_table for base letters -> expect them unchanged
  expect_identical(remove_diacritics("αβγ"), "αβγ")
  expect_identical(remove_diacritics("Привет"), "Привет")
})

test_that("remove_diacritics() handles hyphenated author names with various dash characters", {
  expect_identical(remove_diacritics("Jean-Baptiste"), "Jean-Baptiste")
  expect_identical(remove_diacritics("Marie-Ève"), "Marie-Eve")
  expect_identical(remove_diacritics("Anne-Sophie Le Bihan--Quéré"), "Anne-Sophie Le Bihan--Quere")
  expect_identical(remove_diacritics("Pierre\u2010Louis D\u00fbchamp"), "Pierre\u2010Louis Duchamp")
  expect_identical(remove_diacritics("H\u00e9l\u00e8ne Aubert\u2212L\u00e9vy"), "Helene Aubert\u2212Levy")
  expect_identical(remove_diacritics("Jean\u2011Marc \u0152uvrard"), "Jean\u2011Marc OEuvrard")
})

test_that("remove_diacritics() handles full author reference formats", {
  expect_identical(
    remove_diacritics("Delécluse, J.-P., Müller-Böhm, A., & Ångström, K."),
    "Delecluse, J.-P., Muller-Bohm, A., & Angstrom, K."
  )
  expect_identical(
    remove_diacritics("Fernández, J.M., García-Núñez, R., et Şükrü, A."),
    "Fernandez, J.M., Garcia-Nunez, R., et Sukru, A."
  )
})

test_that("remove_diacritics() handles single-character and short input", {
  expect_identical(remove_diacritics("é"), "e")
  expect_identical(remove_diacritics("a"), "a")
  expect_identical(remove_diacritics(" "), " ")
})

test_that("remove_diacritics() preserves whitespace, punctuation and digits", {
  expect_identical(remove_diacritics("é1é2é!é?é"), "e1e2e!e?e")
  expect_identical(remove_diacritics("caf\u00e9 - 100%"), "cafe - 100%")
})

test_that("remove_diacritics() is idempotent (applying twice = applying once)", {
  txt <- c("café", "Müller", "Ångström", "Straße", "plain text")
  once  <- remove_diacritics(txt)
  twice <- remove_diacritics(once)
  expect_identical(once, twice)
})

test_that("remove_diacritics() is vectorized and preserves vector length/order", {
  input <- c("café", "thé", NA_character_, "Müller", "")
  result <- remove_diacritics(input)
  expect_length(result, length(input))
  expect_identical(
    result,
    c("cafe", "the", NA_character_, "Muller", "")
  )
})

test_that("remove_diacritics() does not add names (USE.NAMES = FALSE behavior)", {
  input <- c(a = "café", b = "thé")
  result <- remove_diacritics(input)
  expect_null(names(result))
})


test_that("remove_diacritics() handles long realistic multi-author strings", {
  txt <- "Müller, J., Fernández-López, J.M., Ångström, K., & Þórunn Þorsteinsdóttir"
  expected <- "Muller, J., Fernandez-Lopez, J.M., Angstrom, K., & Thorunn Thorsteinsdottir"
  expect_identical(remove_diacritics(txt), expected)
})

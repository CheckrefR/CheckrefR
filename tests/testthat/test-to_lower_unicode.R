# =============================================================================
# Unit tests for to_lower_unicode()
# =============================================================================
#
# NOTE ON TEST SCOPE:
# All tests below are strict unit tests of the exported function
# to_lower_unicode().

test_that("to_lower_unicode() rejects non-character input", {
  expect_error(to_lower_unicode(123), class = "rlang_error")
  expect_error(to_lower_unicode(TRUE), class = "rlang_error")
  expect_error(to_lower_unicode(list("A")), class = "rlang_error")
  expect_error(to_lower_unicode(NULL), class = "rlang_error")
  expect_error(to_lower_unicode(factor("A")), class = "rlang_error")
})

test_that("to_lower_unicode() error message is informative (cli formatting)", {
  err <- tryCatch(
    to_lower_unicode(3.14),
    error = function(e) e
  )
  expect_s3_class(err, "rlang_error")
  expect_match(conditionMessage(err), "must be a character vector", fixed = TRUE)
})

test_that("to_lower_unicode() handles NA correctly", {
  expect_identical(to_lower_unicode(NA_character_), NA_character_)
  expect_identical(
    to_lower_unicode(c("ABC", NA_character_, "XYZ")),
    c("abc", NA_character_, "xyz")
  )
})

test_that("to_lower_unicode() handles empty string and empty vector", {
  expect_identical(to_lower_unicode(""), "")
  expect_identical(to_lower_unicode(character(0)), character(0))
  expect_identical(to_lower_unicode(c("", "")), c("", ""))
})

test_that("to_lower_unicode() lowercases plain ASCII text", {
  expect_identical(to_lower_unicode("HELLO WORLD"), "hello world")
  expect_identical(to_lower_unicode("MixedCase123"), "mixedcase123")
  expect_identical(to_lower_unicode("already lower"), "already lower")
})

test_that("to_lower_unicode() leaves digits and punctuation unchanged", {
  expect_identical(to_lower_unicode("ABC123!@#"), "abc123!@#")
  expect_identical(to_lower_unicode("1234567890"), "1234567890")
})

test_that("to_lower_unicode() lowercases accented Latin uppercase letters", {
  expect_identical(to_lower_unicode("ÀÉÎÔÛÇ"), "àéîôûç")
  expect_identical(to_lower_unicode("ÄÖÜ"), "äöü")
  expect_identical(to_lower_unicode("ÑÁÍÓÚ"), "ñáíóú")
  expect_identical(to_lower_unicode("MÜLLER"), "müller")
  expect_identical(to_lower_unicode("ÅNGSTRÖM"), "ångström")
})

test_that("to_lower_unicode() lowercases Central/Eastern European uppercase letters", {
  expect_identical(to_lower_unicode("ĄĆĘŁŃÓŚŹŻ"), "ąćęłńóśźż")
  expect_identical(to_lower_unicode("ŁUKASZ"), "łukasz")
  expect_identical(to_lower_unicode("ĐORĐE"), "đorđe")
})

test_that("to_lower_unicode() lowercases Greek uppercase letters", {
  expect_identical(to_lower_unicode("ΑΒΓΔΕΖΗΘ"), "αβγδεζηθ")
  expect_identical(to_lower_unicode("ΠΑΠΑΔΌΠΟΥΛΟΣ"), "παπαδόπουλοσ")
})

test_that("to_lower_unicode() lowercases Cyrillic uppercase letters", {
  expect_identical(to_lower_unicode("АБВГДЕЁЖЗ"), "абвгдеёжз")
  expect_identical(to_lower_unicode("ИВАНОВ"), "иванов")
})

test_that("to_lower_unicode() handles ligatures present in lower_table", {
  expect_identical(to_lower_unicode("Æ"), "æ")
  expect_identical(to_lower_unicode("Œ"), "œ")
})

test_that("to_lower_unicode() leaves already-lowercase Unicode text unchanged", {
  expect_identical(to_lower_unicode("café"), "café")
  expect_identical(to_lower_unicode("müller"), "müller")
  expect_identical(to_lower_unicode("αβγ"), "αβγ")
  expect_identical(to_lower_unicode("абвгд"), "абвгд")
})

test_that("to_lower_unicode() leaves characters with no mapping entry unchanged", {
  # Characters absent from lower_table should pass through untouched
  expect_identical(to_lower_unicode("123"), "123")
  expect_identical(to_lower_unicode("!?."), "!?.")
})

test_that("to_lower_unicode() is vectorized and preserves vector length/order", {
  input <- c("HELLO", NA_character_, "MÜLLER", "")
  result <- to_lower_unicode(input)
  expect_length(result, length(input))
  expect_identical(result, c("hello", NA_character_, "müller", ""))
})

test_that("to_lower_unicode() does not add names (USE.NAMES = FALSE behavior)", {
  input <- c(a = "HELLO", b = "WORLD")
  result <- to_lower_unicode(input)
  expect_null(names(result))
})

test_that("to_lower_unicode() is idempotent (applying twice = applying once)", {
  txt <- c("HELLO", "MÜLLER", "ΑΒΓ", "АБВ", "already lower")
  once  <- to_lower_unicode(txt)
  twice <- to_lower_unicode(once)
  expect_identical(once, twice)
})

test_that("to_lower_unicode() replicates expected /etc/os-release ID extraction behavior", {
  # Simulates: tolower(trimws(sub("^ID=", "", id_line)))
  # to_lower_unicode() should behave consistently with base::tolower()
  # for the ASCII-only distro identifiers typically found in os-release files.
  id_lines <- c(
    "ubuntu", "\"ubuntu\"", "Fedora", "  arch  ", "OPENSUSE-LEAP",
    "CentOS", "MANJARO", "NixOS", "\"Red Hat Enterprise Linux\""
  )
  processed <- to_lower_unicode(trimws(sub("^ID=", "", id_lines)))
  expected  <- tolower(trimws(sub("^ID=", "", id_lines)))
  expect_identical(processed, expected)
})

test_that("to_lower_unicode() handles mixed-script strings", {
  expect_identical(
    to_lower_unicode("HELLO ΑΒΓ ПРИВЕТ MÜLLER"),
    "hello αβγ привет müller"
  )
})

test_that("to_lower_unicode() handles single-character input", {
  expect_identical(to_lower_unicode("A"), "a")
  expect_identical(to_lower_unicode("É"), "é")
  expect_identical(to_lower_unicode(" "), " ")
})

test_that("to_lower_unicode() handles long realistic bibliographic strings", {
  txt <- "DELÉCLUSE, J.-P., MÜLLER-BÖHM, A., ΠΑΠΑΔΌΠΟΥΛΟΣ, Ν."
  expected <- "delécluse, j.-p., müller-böhm, a., παπαδόπουλοσ, ν."
  expect_identical(to_lower_unicode(txt), expected)
})

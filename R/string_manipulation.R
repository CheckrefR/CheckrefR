
#' Convert Unicode Text to Lowercase
#'
#' @description
#' Transforms all uppercase characters in a character vector to their lowercase
#' equivalents using an internal Unicode Character Database (UCD) lookup table.
#'
#' @details
#' Unlike base R's [tolower()], which can depend on system locale settings and
#' may vary across operating systems, `to_lower_unicode()` relies on a static,
#' precomputed 1-to-1 Unicode mapping table. This guarantees deterministic,
#' fast, and reproducible lowercase conversion across all platforms (Latin,
#' Greek, Cyrillic, etc.).
#'
#' Missing values (`NA`) and empty strings (`""`) are preserved as-is.
#'
#' @param x A character vector to be converted to lowercase.
#'
#' @return A character vector of the same length as `x` with all characters
#'   converted to lowercase.
#'
#' @seealso [remove_diacritics()]
#'
#' @examples
#' # Basic Latin conversion
#' to_lower_unicode(c("HELLO WORLD", "R Package", "DATA"))
#'
#' # Accented and non-Latin characters (Greek, Cyrillic)
#' to_lower_unicode(c("ÉLÉPHANT", "ΑΘΉΝΑ", "МОСКВА"))
#'
#' # Preserves empty strings and NA values
#' to_lower_unicode(c("MIXED Case", "", NA_character_))
#'
#' @export
to_lower_unicode <- function(x) {
  if (!is.character(x)) {
    cli::cli_abort("{.arg x} must be a character vector.")
  }

  vapply(x, function(str) {
    if (is.na(str)) return(NA_character_)
    if (str == "") return("")

    # 1. Convert string to code points
    cps <- utf8ToInt(str)

    # 2. Lookup replacement code points
    mapped_cps <- lower_lut[cps + 1L]

    # 3. Convert back to UTF-8
    intToUtf8(mapped_cps, multiple = FALSE)
  }, character(1), USE.NAMES = FALSE)
}


#' Remove Diacritics and Transliterate Ligatures
#'
#' @description
#' Strips diacritical marks (accents, umlauts, cedillas, tildes, etc.) and
#' transliterates common Latin ligatures/special characters (e.g., `œ` -> `oe`,
#' `æ` -> `ae`, `ß` -> `ss`, `ø` -> `o`) into their base ASCII equivalents.
#'
#' @details
#' The function uses an internal precomputed lookup table derived from the
#' Unicode Character Database (UCD) canonical decomposition rules and extended
#' Latin mappings.
#'
#' Performance is optimized by checking whether any character in the input string
#' requires replacement before performing string reconstruction. If a string
#' contains only ASCII characters or characters without diacritics, it is
#' returned immediately without memory reallocation.
#'
#' Missing values (`NA`) and empty strings (`""`) are preserved as-is.
#'
#' @param x A character vector from which diacritics should be stripped.
#'
#' @return A character vector of the same length as `x` with diacritics removed
#'   and ligatures expanded.
#'
#' @seealso [to_lower_unicode()]
#'
#' @examples
#' # Common French/Spanish accents
#' remove_diacritics(c("Café", "Crème brûlée", "El Niño", "Façade"))
#'
#' # Ligatures and special Latin characters
#' remove_diacritics(c("Cœur", "Encyclopædia", "Fußball", "København"))
#'
#' # Combined with case transformation
#' raw_text <- c("HÉLÈNE", "À bientôt !")
#' remove_diacritics(to_lower_unicode(raw_text))
#'
#' # Edge cases: empty strings and missing values
#' remove_diacritics(c("Simple ASCII", "", NA_character_))
#'
#' @export
remove_diacritics <- function(x) {
  if (!is.character(x)) {
    cli::cli_abort("{.arg x} must be a character vector.")
  }

  vapply(x, function(str) {
    if (is.na(str)) return(NA_character_)
    if (str == "") return("")

    cps <- utf8ToInt(str)

    # Direct replacement lookup
    replacements <- diacritics_lut[cps + 1L]

    # Quick exit if no diacritic was replaced
    has_change <- nzchar(replacements)
    if (!any(has_change)) {
      return(str)
    }

    # Reconstruct final string
    chars <- intToUtf8(cps, multiple = TRUE)
    chars[has_change] <- replacements[has_change]

    paste(chars, collapse = "")
  }, character(1), USE.NAMES = FALSE)
}


#' Strip control and formatting characters
#'
#' @param x A character vector.
#'
#' @return A character vector of the same length as `x`.
#' @noRd
.strip_control_format_chars <- function(x) {
  if (!is.character(x)) {
    cli::cli_abort("{.arg x} must be a character vector.")
  }

  mask <- removable_chars$mask

  has_removable <- vapply(x, function(str) {
    if (is.na(str) || str == "") return(FALSE)
    any(mask[utf8ToInt(str) + 1L])
  }, logical(1), USE.NAMES = FALSE)

  if (!any(has_removable)) return(x)

  out <- x
  idx <- which(has_removable)

  out[idx] <- vapply(x[idx], function(str) {
    code <- utf8ToInt(str)
    code <- code[!mask[code + 1L]]
    if (length(code) == 0L) return("")
    intToUtf8(code, multiple = FALSE)
  }, character(1), USE.NAMES = FALSE)

  out
}


#' Recompose canonical Unicode characters (NFC-like)
#'
#' @param x A character vector.
#'
#' @return A character vector of the same length as `x`.
#' @noRd
.recompose_nfc <- function(x) {
  if (!is.character(x)) {
    cli::cli_abort("{.arg x} must be a character vector.")
  }

  recomp_table <- recomposition_data$table
  comb_mask    <- recomposition_data$combining_mask

  vapply(x, function(str) {
    if (is.na(str) || str == "") return(str)

    cps <- utf8ToInt(str)
    n <- length(cps)
    if (n < 2L) return(str)

    # Court-circuit : si aucun combinant n'est présent, arrêt immédiat
    if (!any(comb_mask[cps + 1L])) return(str)

    out <- integer(n)
    out_len <- 0L
    i <- 1L

    while (i <= n) {
      current <- cps[i]
      j <- i + 1L

      repeat {
        if (j > n) break
        # Clé directe décimale (beaucoup plus rapide que sprintf hex)
        key <- paste0(current, "_", cps[j])
        composed <- recomp_table[[key]]
        if (is.null(composed)) break

        # 'composed' est déjà un entier, pas de strtoi() nécessaire
        current <- composed
        j <- j + 1L
      }

      out_len <- out_len + 1L
      out[out_len] <- current
      i <- j
    }

    intToUtf8(out[seq_len(out_len)], multiple = FALSE)
  }, character(1), USE.NAMES = FALSE)
}

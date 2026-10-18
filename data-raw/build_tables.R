# data-raw/build_tables.R
#
# This script generates the internal lookup tables (LUTs) used by the package:
#   - lower_lut         : Direct integer array mapping for lowercase conversion
#   - diacritics_lut    : Direct character array mapping for diacritics & ligatures removal
#   - removable_chars   : Boolean mask and codepoint vector of removable control characters
#   - recomposition_data: Canonical composition mapping environment & combining mask
#
# Source: Unicode Character Database (UCD), UnicodeData.txt
# Run this script manually whenever the tables need to be regenerated
# (e.g. after a new Unicode release). It is NOT run automatically at
# package build/install time.

# ---- 1. Download and Parse Unicode Character Database -------------------

force_download <- FALSE

ucd_dir <- "data-raw"
if (!dir.exists(ucd_dir)) {
  dir.create(ucd_dir, recursive = TRUE)
}

ucd_path <- file.path(ucd_dir, "UnicodeData.txt")

if (force_download || !file.exists(ucd_path)) {
  message("Downloading UnicodeData.txt from unicode.org...")
  download.file(
    "https://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt",
    destfile = ucd_path,
    mode = "wb"
  )
}

message("Reading and parsing UnicodeData.txt...")
ucd_lines <- readLines(ucd_path, encoding = "UTF-8")
fields    <- strsplit(ucd_lines, ";", fixed = TRUE)

# Max valid Unicode code point (0x10FFFF = 1,114,111) -> 1,114,112 total points
MAX_CP <- 1114111L
TOTAL_CPS <- MAX_CP + 1L

# ---- 2. Build Lowercase Lookup Table ------------------------------------

build_lower_lut <- function(fields) {
  # Initialize with identity mapping (each code point maps to itself)
  # R is 1-indexed, so code point cp is stored at index cp + 1L
  lut <- 0L:MAX_CP

  for (f in fields) {
    if (length(f) < 14) next
    lower_str <- f[14]

    if (!nzchar(lower_str)) next

    cp_from <- strtoi(f[1], base = 16L)
    cp_to   <- strtoi(lower_str, base = 16L)

    lut[cp_from + 1L] <- cp_to
  }

  lut
}

# ---- 3. Build Diacritics Lookup Table -----------------------------------

build_diacritics_lut <- function(fields, allowed_tags = NULL) {
  # 1. Raw decomposition mapping extraction
  raw_decomp <- vector("list", TOTAL_CPS)

  for (f in fields) {
    if (length(f) < 6) next
    decomp <- f[6]
    if (!nzchar(decomp)) next

    tag_match <- regmatches(decomp, regexpr("^<[a-zA-Z]+>", decomp))

    if (length(tag_match) == 0) {
      codepoints_hex <- strsplit(decomp, " ")[[1]]
    } else {
      tag <- gsub("[<>]", "", tag_match)
      if (!(tag %in% allowed_tags)) next
      remainder <- trimws(sub("^<[a-zA-Z]+>\\s*", "", decomp))
      codepoints_hex <- strsplit(remainder, " ")[[1]]
    }

    cp_int <- strtoi(f[1], base = 16L)
    raw_decomp[[cp_int + 1L]] <- strtoi(codepoints_hex, base = 16L)
  }

  # 2. Target Unicode block filter
  in_allowed_block <- function(cp) {
    (cp >= 0x0080L && cp <= 0x00FFL) || # Latin-1 Supplement
      (cp >= 0x0100L && cp <= 0x017FL) || # Latin Extended-A
      (cp >= 0x0180L && cp <= 0x024FL) || # Latin Extended-B
      (cp >= 0x0370L && cp <= 0x03FFL) || # Greek and Coptic
      (cp >= 0x0400L && cp <= 0x04FFL) || # Cyrillic
      (cp >= 0x1E00L && cp <= 0x1EFFL)    # Latin Extended Additional
  }

  # 3. Build replacement table (character vector)
  lut <- vector("character", TOTAL_CPS)

  # Resolve recursive decompositions precalculated
  for (cp in 0L:MAX_CP) {
    if (!in_allowed_block(cp)) next

    current_cp <- cp
    repeat {
      codes <- raw_decomp[[current_cp + 1L]]
      if (is.null(codes)) break
      current_cp <- codes[1]
    }

    if (current_cp != cp) {
      lut[cp + 1L] <- intToUtf8(current_cp)
    }
  }

  # 4. Integrate common ligatures
  ligature_map <- c(
    "\u00C6" = "AE", "\u00E6" = "ae", "\u0152" = "OE", "\u0153" = "oe",
    "\u00DF" = "ss", "\u0110" = "D",  "\u0111" = "d",  "\u00D0" = "D",
    "\u00F0" = "d",  "\u0141" = "L",  "\u0142" = "l",  "\u0132" = "IJ",
    "\u0133" = "ij", "\u00DE" = "Th", "\u00FE" = "th"
  )

  for (ch in names(ligature_map)) {
    cp_lig <- utf8ToInt(ch)
    lut[cp_lig + 1L] <- ligature_map[[ch]]
  }

  lut
}

# ---- 4. Build Removable Characters Data ---------------------------------

build_removable_chars_opt <- function(fields) {
  # Category Cc (Control characters): safe to remove
  cc_cps <- vapply(fields, function(f) {
    if (length(f) < 3) return(NA_character_)
    if (f[[3]] == "Cc") f[[1]] else NA_character_
  }, character(1))
  cc_cps <- strtoi(cc_cps[!is.na(cc_cps)], base = 16L)

  # Category Cf (Format characters): safe subset only (BOM, bidi controls)
  # Explicitly excluding ZWNJ/ZWJ which carry semantic meaning
  cf_safe <- c(
    0xFEFF, 0x200E, 0x200F, 0x061C,
    0x202A, 0x202B, 0x202C, 0x202D, 0x202E
  )

  cps <- as.integer(c(cc_cps, cf_safe))
  cps <- sort(unique(cps[!is.na(cps) & cps > 0L]))

  # Boolean mask across full Unicode space (0x0000 to 0x10FFFF)
  mask <- logical(TOTAL_CPS)
  mask[cps + 1L] <- TRUE

  list(cps = cps, mask = mask)
}

# ---- 5. Build Recomposition Data ----------------------------------------


build_recomposition_table_opt <- function(fields) {
  recomp <- new.env(parent = emptyenv(), hash = TRUE)
  combining_cps <- integer(0)

  for (f in fields) {
    if (length(f) < 6) next
    decomp <- f[[6]]
    if (!nzchar(decomp) || grepl("^<", decomp)) next

    parts <- strsplit(decomp, " ")[[1]]
    if (length(parts) != 2) next

    composed_int  <- strtoi(f[[1]], base = 16L)
    base_int      <- strtoi(parts[1], base = 16L)
    comb_int      <- strtoi(parts[2], base = 16L)

    combining_cps <- c(combining_cps, comb_int)

    # Clé décimale simple et stockage direct de l'entier
    key <- paste0(base_int, "_", comb_int)
    assign(key, composed_int, envir = recomp)
  }

  has_comb_mask <- logical(TOTAL_CPS)
  has_comb_mask[unique(combining_cps) + 1L] <- TRUE

  list(table = recomp, combining_mask = has_comb_mask)
}

# ---- 6. Generate All Tables ---------------------------------------------

message("Building lower_lut...")
lower_lut <- build_lower_lut(fields)

message("Building diacritics_lut...")
diacritics_lut <- build_diacritics_lut(fields)

message("Building removable_chars...")
removable_chars <- build_removable_chars_opt(fields)

message("Building recomposition_data...")
recomposition_data <- build_recomposition_table_opt(fields)

# ---- 7. Save as Internal Package Data (R/sysdata.rda) -------------------

message("Saving objects to R/sysdata.rda...")
usethis::use_data(
  lower_lut,
  diacritics_lut,
  removable_chars,
  recomposition_data,
  internal = TRUE,
  overwrite = TRUE,
  compress = "gzip"
)

chk <- tools::checkRdaFiles("R/sysdata.rda")
stopifnot(chk$compress == "gzip")
message("Done.")

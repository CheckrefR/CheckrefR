# Convert Unicode Text to Lowercase

Transforms all uppercase characters in a character vector to their
lowercase equivalents using an internal Unicode Character Database (UCD)
lookup table.

## Usage

``` r
to_lower_unicode(x)
```

## Arguments

- x:

  A character vector to be converted to lowercase.

## Value

A character vector of the same length as `x` with all characters
converted to lowercase.

## Details

Unlike base R's [`tolower()`](https://rdrr.io/r/base/chartr.html), which
can depend on system locale settings and may vary across operating
systems, `to_lower_unicode()` relies on a static, precomputed 1-to-1
Unicode mapping table. This guarantees deterministic, fast, and
reproducible lowercase conversion across all platforms (Latin, Greek,
Cyrillic, etc.).

Missing values (`NA`) and empty strings (`""`) are preserved as-is.

## See also

[`remove_diacritics()`](https://CheckrefR.github.io/CheckrefR/reference/remove_diacritics.md)

## Examples

``` r
# Basic Latin conversion
to_lower_unicode(c("HELLO WORLD", "R Package", "DATA"))
#> [1] "hello world" "r package"   "data"       

# Accented and non-Latin characters (Greek, Cyrillic)
to_lower_unicode(c("ÉLÉPHANT", "ΑΘΉΝΑ", "МОСКВА"))
#> [1] "éléphant" "αθήνα"    "москва"  

# Preserves empty strings and NA values
to_lower_unicode(c("MIXED Case", "", NA_character_))
#> [1] "mixed case" ""           NA          
```

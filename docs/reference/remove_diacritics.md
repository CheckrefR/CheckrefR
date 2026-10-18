# Remove Diacritics and Transliterate Ligatures

Strips diacritical marks (accents, umlauts, cedillas, tildes, etc.) and
transliterates common Latin ligatures/special characters (e.g., `œ` -\>
`oe`, `æ` -\> `ae`, `ß` -\> `ss`, `ø` -\> `o`) into their base ASCII
equivalents.

## Usage

``` r
remove_diacritics(x)
```

## Arguments

- x:

  A character vector from which diacritics should be stripped.

## Value

A character vector of the same length as `x` with diacritics removed and
ligatures expanded.

## Details

The function uses an internal precomputed lookup table derived from the
Unicode Character Database (UCD) canonical decomposition rules and
extended Latin mappings.

Performance is optimized by checking whether any character in the input
string requires replacement before performing string reconstruction. If
a string contains only ASCII characters or characters without
diacritics, it is returned immediately without memory reallocation.

Missing values (`NA`) and empty strings (`""`) are preserved as-is.

## See also

[`to_lower_unicode()`](https://CheckrefR.github.io/CheckrefR/reference/to_lower_unicode.md)

## Examples

``` r
# Common French/Spanish accents
remove_diacritics(c("Café", "Crème brûlée", "El Niño", "Façade"))
#> [1] "Cafe"         "Creme brulee" "El Nino"      "Facade"      

# Ligatures and special Latin characters
remove_diacritics(c("Cœur", "Encyclopædia", "Fußball", "København"))
#> [1] "Coeur"         "Encyclopaedia" "Fussball"      "København"    

# Combined with case transformation
raw_text <- c("HÉLÈNE", "À bientôt !")
remove_diacritics(to_lower_unicode(raw_text))
#> [1] "helene"      "a bientot !"

# Edge cases: empty strings and missing values
remove_diacritics(c("Simple ASCII", "", NA_character_))
#> [1] "Simple ASCII" ""             NA            
```

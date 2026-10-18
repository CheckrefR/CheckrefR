# Compute a similarity score between two author names

Compares two author names (typically a name extracted by Grobid and a
name from OpenAlex) by decomposing them into two categories of tokens:
"full" tokens (words of the name written in full, e.g. "dupont", "jean")
and "initials" (tokens reduced to a single letter, e.g. "j"). A
similarity score between 0 and 1 is then calculated according to one of
the two available modes.

## Usage

``` r
sim_author_pair(id1, id2, same_position = TRUE)
```

## Arguments

- id1:

  `character`. Full name of the first author to compare (for example a
  name extracted by Grobid), in "First Last" format.

- id2:

  `character`. Full name of the second author to compare (for example a
  name from OpenAlex), same format as `id1`.

- same_position:

  `logical`. If `TRUE` (default), the two names are assumed to occupy
  the same position in two aligned author lists and the score is
  calculated according to the formula anchored on the common full tokens
  (`0.8 + 0.2 * Jaccard`). If `FALSE`, no positional alignment is
  assumed and an F1 score (precision/recall on covered tokens) is used
  instead.

## Value

A single number (`numeric`) between 0 and 1 representing the degree of
similarity between the two author names, based solely on exact token
matches (no tolerance for typos). Returns `0` in degenerate cases
(absence of a full token or zero precision/recall), and `1` in case of
perfect match of the full tokens with no residual initial.

## Details

**Important — no tolerance for typos**: the comparison of full tokens
relies on an **exact string match** (after normalization: lowercase,
removal of accents, hyphens and punctuation. There is **no tolerance for
typos or spelling variants**: "Dupont" and "Dupond" are considered two
completely different tokens, with no partial match.

**Common step: matching of full tokens**

The full tokens common to both names are extracted via multiset
intersection, i.e. an intersection that accounts for repetitions
internal to each name (for example if the same token appears twice in
`id1` and at least twice in `id2`, both occurrences are counted as
common). This is in no way an approximate similarity: only strict
equality between two tokens counts as "common".

Full tokens that have not been matched are then reduced to their first
letter and added to the initials already present in the name, forming a
set of "residual initials" for each name.

If one of the two names contains **no full token** (for example a name
reduced to initials only), the function returns `0` (degenerate case),
regardless of `same_position`.

**Mode `same_position = TRUE` (positional comparison)**

Used when the two names are supposed to occupy the same rank in two
aligned author lists. If there is no common full token (exact match),
the score equals `0`. Otherwise:

\$\$score = 0.8 + 0.2 \times J(I_1, I_2)\$\$

where \\J(I_1, I_2) = \|I_1 \cap I_2\| / \|I_1 \cup I_2\|\\ is the
multiset Jaccard index computed on the residual initials sets \\I_1\\
and \\I_2\\. Special case: if both names consist only of full tokens
that all match exactly (no residual initial on either side, i.e. \\I_1 =
I_2 = \emptyset\\), the Jaccard index is conventionally set to `1`, so
that the final score equals exactly `1.0` in this case of perfect match.
Outside of this special case, the resulting score belongs to the
interval `(0.8, 1]` as soon as at least one full token is shared.

**Mode `same_position = FALSE` (free comparison, F1-type)**

Used when no positional alignment is assumed (e.g. comparison via a
sliding window). We compute:

\$\$precision = covered / total_2, \quad recall = covered / total_1\$\$

where `covered` is the total number of tokens matched by exact
correspondence (common full tokens + common initials), and
`total_1`/`total_2` are the total numbers of tokens (full

- initials) of `id1` and `id2` respectively. The final score is the
  harmonic mean (F1-score):

\$\$score = \frac{2 \times precision \times recall}{precision +
recall}\$\$

If `precision + recall == 0`, the function returns `0`.

## See also

[`compute_author_score`](https://CheckrefR.github.io/CheckrefR/reference/compute_author_score.md)
for the aggregation of this score at the level of a complete list of
authors.

## Examples

``` r
# Perfect match of full tokens -> score = 1
sim_author_pair("Jean Dupont", "Jean Dupont", same_position = TRUE)
#> [1] 1

# Same last name, one initial instead of the full first name
sim_author_pair("Jean Dupont", "J. Dupont", same_position = TRUE)
#> [1] 1

# Typo in the name -> NO tolerance, penalized score
sim_author_pair("Jean Dupont", "Jean Dupond", same_position = TRUE)
#> [1] 1

# Clearly different authors -> no common full token
sim_author_pair("Marie Curie", "Albert Einstein", same_position = TRUE)
#> [1] 0

# Free comparison (no positional alignment), F1-type score
sim_author_pair("Jean-Baptiste Martin", "J.B. Martin", same_position = FALSE)
#> [1] 1
```

# Search the catalog

Ranked dataset search from plain words, in English or Spanish ("jobless
rate", "kids missing school", "desempleo"). Use it when you know what
you are looking for but not what the dataset is called.

Search is hybrid: keyword matching plus matching by meaning. The query
text is sent to the Georgia Civic Data API, which embeds it with Voyage
AI for the meaning half and never logs it. This is the one function
whose results can't be reproduced by filtering
[`gcd_datasets()`](https://georgiacivicdata.org/r/reference/gcd_datasets.md)
locally, and the ranking can change between releases of the platform.

## Usage

``` r
gcd_search(query, main_topic = NULL, level = NULL, year = NULL, n = 20)
```

## Arguments

- query:

  Plain words, a single string.

- main_topic, level, year:

  The same filters as
  [`gcd_datasets()`](https://georgiacivicdata.org/r/reference/gcd_datasets.md):
  a subject area, a detail level and a year. Default `NULL`: no filter.

- n:

  The number of matches to return, 1 to 100. Default 20.

## Value

A tibble, one row per match, best first, with columns:

- `rank`: integer, 1 is the best match.

- `name`, `title`, `summary`, `main_topic`: the dataset.

- `detail_levels`: list-column of the levels it publishes.

- `year_min`, `year_max`: integer, the years covered.

- `score`: double, the match score.

- `matched_on`: list-column of what matched (aliases, columns, summary,
  ...).

- `matched_columns`: list-column of the dataset's columns that matched.

Attributes `confidence` (`"high"`, `"medium"` or `"low"`), `retrieval`
(a list: `mode` and `reranked`) and `total_matches` describe the search.
On low confidence the function says that nothing in the catalog may fit;
it also names any lookup tables that matched.

## See also

[`gcd_datasets()`](https://georgiacivicdata.org/r/reference/gcd_datasets.md)
for the full catalog;
[`gcd_describe()`](https://georgiacivicdata.org/r/reference/gcd_describe.md)
and
[`gcd_columns()`](https://georgiacivicdata.org/r/reference/gcd_columns.md)
to understand a match.

Other find data:
[`gcd_datasets()`](https://georgiacivicdata.org/r/reference/gcd_datasets.md)

## Examples

``` r
if (FALSE) { # interactive()
gcd_search("high school graduation")
gcd_search("desempleo", n = 5)
gcd_search("chronic absence", level = "districts")
}
```

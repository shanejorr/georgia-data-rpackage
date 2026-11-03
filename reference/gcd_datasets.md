# List the datasets in the catalog

The catalog of everything the API publishes, one row per dataset. With
no arguments it returns **every dataset**: all subject areas, detail
levels and years, tables and geometry alike. Each argument only narrows
the list (the filtering runs on the server). About 176 datasets: small
enough to [`View()`](https://rdrr.io/r/utils/View.html) or filter with
dplyr.

The six lookup tables (districts, schools, counties, tracts, block
groups, demographics) are not datasets and are not listed; see
[`gcd_dimension()`](https://georgiacivicdata.org/r/reference/gcd_dimension.md).

## Usage

``` r
gcd_datasets(
  main_topic = NULL,
  level = NULL,
  year = NULL,
  kind = NULL,
  details = FALSE
)
```

## Arguments

- main_topic:

  A single subject area: `"education"`, `"census"`, `"health"` or
  `"immigration"`. Default `NULL`: all.

- level:

  Keep datasets that publish rows at this detail level, such as
  `"schools"`, `"districts"`, `"counties"` or `"tracts"`. Default
  `NULL`: all.

- year:

  Keep datasets that cover this year (a single number). Default `NULL`:
  all.

- kind:

  `"table"` or `"geometry"`. Default `NULL`: both.

- details:

  `FALSE` (default) gives the compact catalog. `TRUE` adds the long
  columns (description, source, grain and more).

## Value

A tibble, one row per dataset, with columns:

- `name`: the dataset's name, used by every other function.

- `title`, `summary`: what it holds.

- `kind`: `"table"` or `"geometry"`.

- `main_topic`: the subject area.

- `detail_levels`: list-column of the levels it publishes.

- `year_min`, `year_max`: integer, the years covered.

With `details = TRUE`, also: `description`, `source`, `source_url`,
`grain` (list-column: the columns that identify a row),
`default_detail`, `year_gaps` (list-column of missing years),
`update_frequency`, `search_aliases_en` and `search_aliases_es`
(list-columns of everyday search phrases), and `updated_at` (POSIXct,
UTC). Geometry datasets have `NA` where a field doesn't apply.

## See also

[`gcd_search()`](https://georgiacivicdata.org/r/reference/gcd_search.md)
to rank datasets by plain words;
[`gcd_describe()`](https://georgiacivicdata.org/r/reference/gcd_describe.md)
for one dataset.

Other find data:
[`gcd_search()`](https://georgiacivicdata.org/r/reference/gcd_search.md)

## Examples

``` r
if (FALSE) { # interactive()
gcd_datasets()
gcd_datasets(main_topic = "education", level = "schools")
gcd_datasets(kind = "geometry", details = TRUE)
}
```

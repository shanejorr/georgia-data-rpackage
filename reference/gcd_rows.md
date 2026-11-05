# Get rows of a dataset

The core function: the rows of one dataset at one detail level, as a
tibble typed from the dataset's schema, with place names beside their
codes.

**It returns every category and group the filters don't exclude.**
Nothing is pinned by default: no single demographic group, no single
subject. A call with only a dataset name returns the whole dataset at
its default detail level.

## Usage

``` r
gcd_rows(
  name,
  ...,
  year = NULL,
  detail = NULL,
  district = NULL,
  school = NULL,
  county = NULL,
  labels = TRUE,
  columns = NULL,
  sort = NULL,
  n_max = Inf,
  cache = getOption("gcd.cache", FALSE),
  quiet = FALSE
)
```

## Arguments

- name:

  The dataset's name, such as `"graduation_rate_4_year_cohort"` (see
  [`gcd_datasets()`](https://georgiacivicdata.org/r/reference/gcd_datasets.md)
  and
  [`gcd_search()`](https://georgiacivicdata.org/r/reference/gcd_search.md)).

- ...:

  Named filters (see "Filters"). Unnamed arguments are an error.

- year:

  Years to keep, an integer vector. A run of consecutive years
  (`2019:2024`) is sent as a range; anything else (`c(2019, 2024)`) as
  exact years. Default `NULL`: all years.

- detail:

  The one level the rows describe, such as `"schools"`, `"districts"`,
  `"states"`, `"counties"` or `"tracts"`. Default `NULL`: the dataset's
  default (the finest level, except Census datasets, which default to
  counties). To combine levels, call once per level and bind the rows.

- district, school, county:

  Places by name, such as `district = "Fulton County"`,
  `school = "Roswell High School"`, `county = c("Fulton", "DeKalb")`.
  Matched exactly against current and former names (ignoring case,
  accents and a trailing "County"); an unknown or ambiguous name is an
  error that lists suggestions or candidates. A school name found in
  more than one district needs `district` too. For any one place, give
  its code or its name, not both. Default `NULL`.

- labels:

  `TRUE` (default) adds place names beside codes; `FALSE` returns codes
  only (see "Labels").

- columns:

  A character vector to return only some columns. Default `NULL`: all.

- sort:

  A character vector of columns to sort by on the server; prefix `-` for
  descending (`"-graduation_rate"`). Missing values sort last. Mostly
  useful with `n_max` for a top N. Default `NULL`: the dataset's own
  order (its grain).

- n_max:

  The most rows to return. Default `Inf`: all.

- cache:

  `TRUE` to use the disk cache (see "Large downloads and the disk
  cache"). Default `getOption("gcd.cache", FALSE)`.

- quiet:

  `TRUE` to silence the advisory messages. Default `FALSE`.

## Value

A tibble of rows at one detail level, typed from the schema: codes and
names character (leading zeros kept), `year` integer, counts integer,
rates and proportions double (proportions on the 0-1 scale), booleans
logical. Columns come in grain order: `year`, each geography code
followed by its names, `demographic` and its labels, other categorical
columns, then metrics.
[`gcd_columns()`](https://georgiacivicdata.org/r/reference/gcd_columns.md)
describes each column. The tibble carries a `gcd_meta` attribute (see
[`gcd_meta()`](https://georgiacivicdata.org/r/reference/gcd_meta.md)):
dataset, title, detail, key metric, units, `null_semantics`, source,
citation, license, advisories, data version, `updated_at` and the
request URL.

## Filters

Give filters as named arguments in `...`; each value is a vector. Values
within one filter are OR'd; different filters are AND'd. Accepted names:

- any categorical column: `subject = "mathematics"`,
  `demographic = c("all", "black")`;

- geography codes: `district_code`, `school_code`, `county_fips`,
  `tract_geoid`, `block_group_geoid`;

- `school_id`: schools as `"DISTRICT-SCHOOL"` codes
  (`school_id = c("761-0199", "660-0104")`), the form
  [`gcd_locate()`](https://georgiacivicdata.org/r/reference/gcd_locate.md)
  returns (a school code alone is not unique across districts);

- lookup-table attributes: `district_type = "state_charter"`,
  `school_level = "high"`, `locale = "rural"`,
  `demographic_category = "race"`;

- metric bounds: `graduation_rate_min = 0.9`, `num_cohort_max = 50`
  (inclusive, in stored units).

`NA` in a filter selects rows where a nullable column is empty; logicals
become `true` / `false`. The API validates every filter and its errors
name what went wrong;
[`gcd_describe()`](https://georgiacivicdata.org/r/reference/gcd_describe.md)
lists each dataset's filters and their values.

## Labels

With `labels = TRUE` (the default) the rows carry the API's joined name
columns, each right after its code: `district_name`,
`district_census_id` and `district_type` after `district_code`;
`school_name` after `school_code`; `county_name`, `tract_name` and
`block_group_name` after their codes; `demographic_label` and
`demographic_category` after `demographic`. Codes are always kept:
school names repeat across districts, names change over time, and joins
run on codes.

- Categorical values (`subject`, `grade_cluster`) are readable
  snake_case codes already; there are no separate labels for them.

- `demographic_category` (race, gender, economic_status, ...) is a
  grouping that arrives with the labels; filtering by it works either
  way.

- Other lookup-table attributes (school addresses, locale, coordinates)
  are not joined; get them from
  [`gcd_dimension()`](https://georgiacivicdata.org/r/reference/gcd_dimension.md)
  and join.

`labels = FALSE` asks for the dataset's own columns only, for large
pulls.
[`gcd_columns()`](https://georgiacivicdata.org/r/reference/gcd_columns.md)
takes the same argument and lists the name columns too, with `role`
`"label"`. Either way, code columns that would be empty on every row (a
district row's `school_code`, a state row's geography codes) are left
out, so both settings give the same shape.

## Missing values and totals

`NA` in a metric usually means the value was **suppressed** to protect
privacy (small counts), **not zero**; the schema's `null_semantics` says
which
([`gcd_describe()`](https://georgiacivicdata.org/r/reference/gcd_describe.md)).
Because nothing is pinned, results hold the `all` totals beside the
subgroups: never add a total to its subgroups. The API's advisories say
so when they apply, and print once per call as messages (`quiet = TRUE`
or `options(gcd.quiet = TRUE)` silences them; they stay in
`gcd_meta(x)$advisories`).

Rates must be pooled from their counts, never averaged:
`sum(num_graduates) / sum(num_cohort)`, not `mean(graduation_rate)`.
[`gcd_columns()`](https://georgiacivicdata.org/r/reference/gcd_columns.md)
shows each metric's numerator and denominator.

## Large downloads and the disk cache

Up to 10,000 rows come back as one JSON page. A larger result is
downloaded in full as CSV in one response (with a progress bar); the
metadata and advisories then come from the first JSON page and describe
its first 10,000 rows.

With `cache = TRUE` (or `options(gcd.cache = TRUE)`), responses are kept
in `tools::R_user_dir("georgiacivicdata", "cache")` with their `ETag`.
Repeating a request asks the server whether the data changed: an
unchanged answer reuses the saved copy without downloading, and a new
data release downloads afresh. A response the server marks fresh (for
five minutes) is reused without asking. Clear it with
[`gcd_cache_clear()`](https://georgiacivicdata.org/r/reference/gcd_cache_clear.md).

## Data license

The data is CC BY 4.0: credit Georgia Civic Data and the original
source, as
[`gcd_citation()`](https://georgiacivicdata.org/r/reference/gcd_citation.md)
writes.

## See also

[`gcd_values()`](https://georgiacivicdata.org/r/reference/gcd_values.md)
to see which category values exist under a filter;
[`gcd_describe()`](https://georgiacivicdata.org/r/reference/gcd_describe.md)
and
[`gcd_columns()`](https://georgiacivicdata.org/r/reference/gcd_columns.md)
to understand a dataset;
[`gcd_citation()`](https://georgiacivicdata.org/r/reference/gcd_citation.md)
to cite it.

Other get data:
[`gcd_values()`](https://georgiacivicdata.org/r/reference/gcd_values.md)

## Examples

``` r
if (FALSE) { # interactive()
# Names and codes (the default), one district by name
grad <- gcd_rows(
  "graduation_rate_4_year_cohort",
  district = "Fulton County",
  demographic = c("all", "black", "hispanic"),
  year = 2020:2024
)

# One school, by name within its district
gcd_rows("graduation_rate_4_year_cohort",
         district = "Fulton County", school = "Roswell High School",
         demographic = "all")

# Statewide schools, one subject, codes only
gcd_rows("ccrpi_content_mastery", year = 2025, detail = "schools",
         grade_cluster = "high", subject = "mathematics", labels = FALSE)

# Top 10 counties by unemployment
gcd_rows("employment", year = 2024, sort = "-unemployment_rate",
         n_max = 10)
}
```

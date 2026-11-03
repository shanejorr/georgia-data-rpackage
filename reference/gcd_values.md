# List the category combinations a filter covers

Which combinations of category values exist, and how many rows each has,
under the same filters as
[`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md). It
answers "which subjects exist in 2016 at district level?" or "which
demographic groups does this county have rows for?" without downloading
the rows. The schema's `valid_values` list every value a column has ever
used; `gcd_values()` lists what exists **for this filter**, which is
what you need when a filter returns zero rows.

The API returns at most 500 combinations; the function warns when that
cap is reached.

## Usage

``` r
gcd_values(
  name,
  columns,
  ...,
  year = NULL,
  detail = NULL,
  district = NULL,
  school = NULL,
  county = NULL
)
```

## Arguments

- name:

  The dataset's name, such as `"graduation_rate_4_year_cohort"` (see
  [`gcd_datasets()`](https://georgiacivicdata.org/r/reference/gcd_datasets.md)
  and
  [`gcd_search()`](https://georgiacivicdata.org/r/reference/gcd_search.md)).

- columns:

  One or more categorical columns (or `"demographic"`), such as
  `"subject"` or `c("subject", "grade_cluster")`.

- ...:

  Named filters, exactly as in
  [`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md).

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

## Value

A tibble, most rows first, with one column per requested column (typed
from the schema; `NA` where the column is empty for those rows) and
`n_rows` (integer), the number of rows with that combination.

## See also

[`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md) for
the rows themselves;
[`gcd_describe()`](https://georgiacivicdata.org/r/reference/gcd_describe.md)
for every filter and its allowed values.

Other get data:
[`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md)

## Examples

``` r
if (FALSE) { # interactive()
gcd_values("ccrpi_content_mastery", "subject", year = 2016,
           detail = "districts")
gcd_values("graduation_rate_4_year_cohort", "demographic",
           district = "Fulton County", year = 2024)
}
```

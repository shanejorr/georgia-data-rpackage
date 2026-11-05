# Describe a dataset or lookup table

Everything about one dataset, lookup table or geometry dataset: what it
holds, its source, years, detail levels, the columns that identify a row
(the grain), its key metric, every filter, and the notes its data
contract declares (limitations, series breaks, groups that must not be
added up, and so on). Printing the result shows a readable summary.

Read the **"Pick one value of"** line: it names categorical columns with
no total (such as `grade_cluster`), whose values must not be mixed in
one summary.
[`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md)
returns every value of them unless you filter one.

The `$filters` table is also how to discover the filters that are not
columns of the dataset: lookup-table attributes such as `district_type`,
`school_level`, `locale` and `demographic_category`.

## Usage

``` r
gcd_describe(name)
```

## Arguments

- name:

  A dataset, lookup table or geometry dataset name, such as
  `"graduation_rate_4_year_cohort"`, `"schools"` or
  `"school_attendance_zones"`. Names are unique across all three kinds.

## Value

A `gcd_description` object: a named list with a print method. Components
include `name`, `kind` (`"table"`, `"geometry"` or `"lookup"`), `title`,
`summary`, `description`, `source`, `source_url`, `years` (integer),
`year_gaps`, `detail_levels`, `default_detail`, `grain`, `key_metric`,
and:

- `$columns`: the column dictionary, as
  [`gcd_columns()`](https://georgiacivicdata.org/r/reference/gcd_columns.md)
  returns it by default (for a dataset, the joined name columns
  included).

- `$filters`: a tibble of every filter parameter: `param`, `kind`
  (categorical, foreign_key, dimension_attribute, metric_bound, year,
  detail, ...), `values` (list-column of allowed values), `multi_value`,
  `has_total`, `total_value`, `requires_single_value` and `nullable`.

- `$notes`: the contract's declarations that are present, each a tibble
  or a string: `limitations`, `year_meaning`, `null_semantics`,
  `series_breaks`, `non_additive`, `partitions`, `pooled_rates`,
  `year_window`, `value_implications`, `pooled_min_count` (and
  `assignment_note` for the zones).

- `$raw`: the full parsed schema response.

## See also

[`gcd_columns()`](https://georgiacivicdata.org/r/reference/gcd_columns.md)
for the column table alone;
[`gcd_values()`](https://georgiacivicdata.org/r/reference/gcd_values.md)
for the category values present under a filter;
[`gcd_contract()`](https://georgiacivicdata.org/r/reference/gcd_contract.md)
for the formal contract.

Other describe a dataset:
[`gcd_columns()`](https://georgiacivicdata.org/r/reference/gcd_columns.md),
[`gcd_contract()`](https://georgiacivicdata.org/r/reference/gcd_contract.md)

## Examples

``` r
if (FALSE) { # interactive()
gcd_describe("graduation_rate_4_year_cohort")
gcd_describe("ccrpi_content_mastery")$filters
gcd_describe("schools")
}
```

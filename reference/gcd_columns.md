# Get a dataset's column dictionary

The columns of a dataset, lookup table or geometry dataset as a tidy
table: what each column means, its type, its unit and, for metrics,
whether it is a numerator or denominator. This is the place to check
"what does `pct_proficient_learner_or_above` mean, and is it 0-1?".

The dictionary lists every column a dataset can return. Which ones a
given
[`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md)
call returns also depends on its `detail` and `columns`: code columns
that would be empty on every row (a county row's `tract_geoid`, a
district row's `school_code`) are left out.

## Usage

``` r
gcd_columns(name, labels = TRUE)
```

## Arguments

- name:

  A dataset, lookup table or geometry dataset name, such as
  `"graduation_rate_4_year_cohort"`, `"schools"` or
  `"school_attendance_zones"`. Names are unique across all three kinds.

- labels:

  `TRUE` (default) also lists the name columns that
  [`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md)
  joins in by default (`district_name`, `county_name`,
  `demographic_label`, ...), each right after its code, with `role`
  `"label"`. `FALSE` lists the dataset's own columns only, matching
  `gcd_rows(labels = FALSE)`. Labels come only with datasets; lookup
  tables and geometry datasets ignore this argument.

## Value

A tibble, one row per column, with columns:

- `column`: the column name.

- `label`: a short display name.

- `type`: `"integer"`, `"number"`, `"string"`, `"boolean"` or `"date"`,
  which
  [`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md)
  maps to integer, double, character, logical and Date.

- `role`: `"year"`, a foreign key (`"fk_district"`, `"fk_school"`, ...),
  `"categorical"`, `"metric"` or `"label"` (a joined name column) for
  datasets; `"key"` or `"attribute"` for lookup tables.

- `label_of`: for a `"label"` column, the code column it names
  (`"district_code"`, `"demographic"`, ...); otherwise `NA`.

- `unit`: `"count"`, `"proportion"` (0-1 scale), a rate unit, ...

- `is_key_metric`: logical, `TRUE` for the dataset's headline metric.

- `metric_component`: `"numerator"` or `"denominator"` for the counts a
  rate is built from.

- `nullable`: logical.

- `valid_values`: list-column of a categorical column's values.

- `description`: the full definition.

- `null_meaning`: what a missing value means in this column.

Fields that don't apply (labels and units for lookup tables and joined
name columns, most fields for geometry datasets) are `NA`. A joined name
column's `description` and `nullable` come from its lookup table; see
[`gcd_dimension()`](https://georgiacivicdata.org/r/reference/gcd_dimension.md).

## See also

[`gcd_describe()`](https://georgiacivicdata.org/r/reference/gcd_describe.md)
for the whole schema.

Other describe a dataset:
[`gcd_contract()`](https://georgiacivicdata.org/r/reference/gcd_contract.md),
[`gcd_describe()`](https://georgiacivicdata.org/r/reference/gcd_describe.md)

## Examples

``` r
if (FALSE) { # interactive()
gcd_columns("graduation_rate_4_year_cohort")
gcd_columns("graduation_rate_4_year_cohort", labels = FALSE)
gcd_columns("schools")
}
```

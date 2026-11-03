# Get a dataset's column dictionary

The columns of a dataset, lookup table or geometry dataset as a tidy
table: what each column means, its type, its unit and, for metrics,
whether it is a numerator or denominator. This is the place to check
"what does `pct_proficient_learner_or_above` mean, and is it 0-1?".

## Usage

``` r
gcd_columns(name)
```

## Arguments

- name:

  A dataset, lookup table or geometry dataset name, such as
  `"graduation_rate_4_year_cohort"`, `"schools"` or
  `"school_attendance_zones"`. Names are unique across all three kinds.

## Value

A tibble, one row per column, with columns:

- `column`: the column name.

- `label`: a short display name.

- `type`: `"integer"`, `"number"`, `"string"`, `"boolean"` or `"date"`,
  which
  [`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md)
  maps to integer, double, character, logical and Date.

- `role`: `"year"`, a foreign key (`"fk_district"`, `"fk_school"`, ...),
  `"categorical"` or `"metric"` for datasets; `"key"` or `"attribute"`
  for lookup tables.

- `unit`: `"count"`, `"proportion"` (0-1 scale), a rate unit, ...

- `is_key_metric`: logical, `TRUE` for the dataset's headline metric.

- `metric_component`: `"numerator"` or `"denominator"` for the counts a
  rate is built from.

- `nullable`: logical.

- `valid_values`: list-column of a categorical column's values.

- `description`: the full definition.

- `null_meaning`: what a missing value means in this column.

Fields that don't apply (labels and units for lookup tables, most fields
for geometry datasets) are `NA`.

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
gcd_columns("schools")
}
```

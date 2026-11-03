# Get a dataset's data contract

The dataset's formal, versioned contract in the Open Data Contract
Standard (ODCS v3.2): its schema, quality rules, `version` and
`schema_hash`. For data engineers building pipelines and anyone citing
the exact schema. Most users want
[`gcd_describe()`](https://georgiacivicdata.org/r/reference/gcd_describe.md)
instead.

Datasets and the `school_attendance_zones` geometry dataset have
contracts; lookup tables and `school_district_boundaries` do not.

## Usage

``` r
gcd_contract(name, file = NULL)
```

## Arguments

- name:

  A dataset, lookup table or geometry dataset name, such as
  `"graduation_rate_4_year_cohort"`, `"schools"` or
  `"school_attendance_zones"`. Names are unique across all three kinds.

- file:

  A path. If given, the contract is written there verbatim as YAML and
  the path is returned invisibly. Default `NULL`: return the contract as
  a list.

## Value

The contract as a nested list (parsed from its JSON form), or, with
`file`, the path invisibly.

## See also

[`gcd_describe()`](https://georgiacivicdata.org/r/reference/gcd_describe.md)
for a readable summary.

Other describe a dataset:
[`gcd_columns()`](https://georgiacivicdata.org/r/reference/gcd_columns.md),
[`gcd_describe()`](https://georgiacivicdata.org/r/reference/gcd_describe.md)

## Examples

``` r
if (FALSE) { # interactive()
contract <- gcd_contract("graduation_rate_4_year_cohort")
contract$version
gcd_contract("graduation_rate_4_year_cohort", file = tempfile(fileext = ".yaml"))
}
```

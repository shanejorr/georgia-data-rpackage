# Get each district's attendance-zone coverage

How completely each standard district's attendance zones were collected,
one row per district and zone level: the source tier, the status of each
level, the share of the district's land and 2020 population the zones
cover, how they were built, and the reason for anything short of
complete.

The API returns one row per district with a column per level
(`level_status_elementary`, `pct_population_middle`, ...); this function
pivots those columns long. The district filter runs in R (the route
takes no filters; the table has about 180 rows).

## Usage

``` r
gcd_school_zone_coverage(
  district_code = NULL,
  district = NULL,
  geometry = FALSE
)
```

## Arguments

- district_code:

  A character vector of district codes. Default `NULL`: every district.

- district:

  District names, matched to codes as in
  [`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md).
  Default `NULL`.

- geometry:

  `FALSE` (default) returns a tibble; `TRUE` returns an `sf` object of
  the district outlines carrying the same fields (needs the 'sf'
  package).

## Value

A tibble (or `sf` object), one row per district and zone level, with
columns `year` (integer), `district_code`, `district_name`, `tier` (the
source tier, A to E or N), `status` (the district's overall status),
`zone_level`, `level_status` (`"zoned"`, `"one_school_per_grade"`,
`"partial"`, `"not_available"`, `"served_by_other_district"`),
`pct_land_area` and `pct_population` (0-1, the share the level's zones
cover), `zone_count`, `methods`, `accuracy_classes`, `reason`, then
`levels_covered`, `currency_statuses`, `best_lead`, `extension_note` and
`served_elsewhere` (a list-column of tibbles: the other district's
school serving that level, with `district_code`, `school_code` and
`reason`).

## See also

[`gcd_school_zones()`](https://georgiacivicdata.org/r/reference/gcd_school_zones.md)
for the zones.

Other geography:
[`gcd_district_boundaries()`](https://georgiacivicdata.org/r/reference/gcd_district_boundaries.md),
[`gcd_locate()`](https://georgiacivicdata.org/r/reference/gcd_locate.md),
[`gcd_school_zone_status()`](https://georgiacivicdata.org/r/reference/gcd_school_zone_status.md),
[`gcd_school_zones()`](https://georgiacivicdata.org/r/reference/gcd_school_zones.md)

## Examples

``` r
if (FALSE) { # interactive()
gcd_school_zone_coverage(district = "Clay County")
coverage <- gcd_school_zone_coverage()
table(coverage$zone_level, coverage$level_status)
}
```

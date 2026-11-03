# Get each school's attendance-zone status

Whether each school of the standard districts has an attendance zone on
the platform and, if not, why: a magnet or charter school with no zone,
a district whose maps are not published yet, and so on. Answers "why
doesn't this school have a zone?" without inferring it from a missing
polygon.

## Usage

``` r
gcd_school_zone_status(
  district_code = NULL,
  school_code = NULL,
  district = NULL,
  school = NULL,
  zone_status = NULL,
  no_zone_category = NULL
)
```

## Arguments

- district_code, school_code:

  Character vectors of codes. Default `NULL`.

- district, school:

  Names, matched to codes as in
  [`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md).
  A school name found in more than one district needs `district` too.
  Default `NULL`.

- zone_status:

  `"zoned"`, `"no_zone"` and/or `"not_yet_collected"`. Default `NULL`:
  all.

- no_zone_category:

  Why a school has no zone (the API's categories, listed by
  [`gcd_describe()`](https://georgiacivicdata.org/r/reference/gcd_describe.md)
  with `"school_attendance_zones"`). Default `NULL`: all.

## Value

A tibble, one row per school, with columns `year` (integer),
`district_code`, `district_name`, `school_code`, `school_name`,
`zone_status`, `zone_levels` (the levels it is zoned for, as one
string), `no_zone_category` and `reason`. The API's note on reading the
table is the `note` attribute.

## See also

[`gcd_school_zones()`](https://georgiacivicdata.org/r/reference/gcd_school_zones.md)
for the zones;
[`gcd_school_zone_coverage()`](https://georgiacivicdata.org/r/reference/gcd_school_zone_coverage.md)
for each district's coverage.

Other geography:
[`gcd_district_boundaries()`](https://georgiacivicdata.org/r/reference/gcd_district_boundaries.md),
[`gcd_locate()`](https://georgiacivicdata.org/r/reference/gcd_locate.md),
[`gcd_school_zone_coverage()`](https://georgiacivicdata.org/r/reference/gcd_school_zone_coverage.md),
[`gcd_school_zones()`](https://georgiacivicdata.org/r/reference/gcd_school_zones.md)

## Examples

``` r
if (FALSE) { # interactive()
gcd_school_zone_status(district = "Atlanta Public Schools")
gcd_school_zone_status(zone_status = "no_zone")
}
```

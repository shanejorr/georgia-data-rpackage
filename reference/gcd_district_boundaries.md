# Get school district boundaries

The Census TIGER/Line outlines of Georgia's school districts, keyed to
district codes: unified districts, the secondary-only pieces some
districts serve (Fort Benning grades 9-12), and the Department of
Defense districts (which have no district code).

## Usage

``` r
gcd_district_boundaries(district_code = NULL, district = NULL, geometry = TRUE)
```

## Arguments

- district_code:

  A character vector of district codes. Default `NULL`: every district.

- district:

  District names, matched to codes as in
  [`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md).
  Default `NULL`.

- geometry:

  `TRUE` (default) returns an `sf` object (needs the 'sf' package);
  `FALSE` returns the attributes as a plain tibble.

## Value

An `sf` object (or, with `geometry = FALSE`, a tibble), one row per
district piece, with columns `district_code`, `district_name` (for
Department of Defense districts, the Census name), `boundary_type`
(`"unified"`, `"secondary_extension"` or `"dodea"`),
`district_census_id`, `nces_lea_id`, `grade_low`, `grade_high`,
`tiger_geoid`, `tiger_name`, `tiger_vintage`, `land_area_sq_mi`,
`area_sq_mi`, the bounding box and the `geometry` (WGS 84).

## See also

[`gcd_school_zones()`](https://georgiacivicdata.org/r/reference/gcd_school_zones.md)
for the zones inside each district.

Other geography:
[`gcd_locate()`](https://georgiacivicdata.org/r/reference/gcd_locate.md),
[`gcd_school_zone_coverage()`](https://georgiacivicdata.org/r/reference/gcd_school_zone_coverage.md),
[`gcd_school_zone_status()`](https://georgiacivicdata.org/r/reference/gcd_school_zone_status.md),
[`gcd_school_zones()`](https://georgiacivicdata.org/r/reference/gcd_school_zones.md)

## Examples

``` r
if (FALSE) { # interactive() && requireNamespace("sf", quietly = TRUE)
gcd_district_boundaries(district = "Clay County")
gcd_district_boundaries(geometry = FALSE)
}
```

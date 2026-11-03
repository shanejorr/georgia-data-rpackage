# Get school attendance zones

Attendance-zone polygons: the areas that assign a home to its zoned
elementary, middle and high school, one polygon per school, level and
grade run, for the current school year.

**Zones differ in precision.** Some are the district's official GIS
layers; others are digitized from PDF maps, rebuilt from street lists,
or are the whole district outline (districts with one school per grade).
Read `method` and `accuracy_class` before treating zones as equally
exact, and see
[`gcd_school_zone_coverage()`](https://georgiacivicdata.org/r/reference/gcd_school_zone_coverage.md)
for how completely each district was collected. A zone is the default
assignment, not an official enrollment determination: confirm with the
district.

**A statewide pull is large**, especially at `resolution = "full"`.
Filter to a district and keep the `"display"` default for maps.

## Usage

``` r
gcd_school_zones(
  district_code = NULL,
  school_code = NULL,
  district = NULL,
  school = NULL,
  zone_level = NULL,
  grade = NULL,
  year = NULL,
  resolution = c("display", "full"),
  geometry = TRUE
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

- zone_level:

  `"elementary"`, `"middle"` and/or `"high"`. Default `NULL`: all.

- grade:

  One grade: keep zones serving it (`"pk"`, `"k"`, `"01"` to `"12"`;
  `"5"` and `"K"` are accepted). Default `NULL`: all.

- year:

  The zones' school year as its ending year (2027 is 2026-27). Default
  `NULL`: the current zones.

- resolution:

  `"display"` (default): simplified polygons for maps, much smaller;
  `"full"`: the source polygons the point lookup uses.

- geometry:

  `TRUE` (default) returns an `sf` object (needs the 'sf' package);
  `FALSE` returns the attributes as a plain tibble.

## Value

An `sf` object (or, with `geometry = FALSE`, a tibble), one row per
zone, with columns `year` (integer), `district_code`, `district_name`,
`school_code`, `school_name`, `zone_level`, `grade_low`, `grade_high`
(`"pk"`, `"k"`, `"01"` ... `"12"`), `method` (how the zone was built),
`accuracy_class`, `currency_status`, `boundary_vintage`, `source_url`,
`retrieved_on` (Date), `area_sq_mi`, the bounding box (`bbox_xmin`,
`bbox_ymin`, `bbox_xmax`, `bbox_ymax`), `source_school_name` (the name
as the district's map spells it), then `positional_rmse_m`,
`currency_note`, `source_publisher`, `nces_school_id`,
`district_census_id`, `nces_lea_id` and the `geometry` (WGS 84). The
API's disclaimer is the `note` attribute.

## See also

[`gcd_locate()`](https://georgiacivicdata.org/r/reference/gcd_locate.md)
to find the zones a point falls in;
[`gcd_school_zone_status()`](https://georgiacivicdata.org/r/reference/gcd_school_zone_status.md)
for schools without a zone;
[`gcd_describe()`](https://georgiacivicdata.org/r/reference/gcd_describe.md)
with `"school_attendance_zones"` for every field.

Other geography:
[`gcd_district_boundaries()`](https://georgiacivicdata.org/r/reference/gcd_district_boundaries.md),
[`gcd_locate()`](https://georgiacivicdata.org/r/reference/gcd_locate.md),
[`gcd_school_zone_coverage()`](https://georgiacivicdata.org/r/reference/gcd_school_zone_coverage.md),
[`gcd_school_zone_status()`](https://georgiacivicdata.org/r/reference/gcd_school_zone_status.md)

## Examples

``` r
if (FALSE) { # interactive() && requireNamespace("sf", quietly = TRUE)
zones <- gcd_school_zones(district = "Atlanta Public Schools",
                          zone_level = "high")
plot(zones["school_name"])

gcd_school_zones(district_code = "630", geometry = FALSE)
}
```

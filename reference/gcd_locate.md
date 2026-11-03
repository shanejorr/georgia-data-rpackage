# Locate points or addresses

The county, 2020 Census tract and block group, school district and zoned
schools that points or street addresses fall in.

Points are sent to the API's `POST /locate` route in batches of up to
1,000, so coordinates never appear in URLs and nothing is cached.
**Addresses never reach the Georgia Civic Data API**: the package
geocodes them on your computer with the U.S. Census batch geocoder
(<https://geocoding.geo.census.gov/geocoder/>, benchmark
`Public_AR_Current`, the address data the API's own search uses; up to
10,000 addresses per upload), then sends the coordinates as points. An
address the Census can't match is never sent. To geocode with another
service, geocode first (for example with the 'tidygeocoder' package) and
pass `lat` and `lon`.

A zone is the default assignment, not the only option: a student may
attend another public school by transfer, or a charter, magnet or other
choice school. This is not an official enrollment determination; confirm
with the school district.

## Usage

``` r
gcd_locate(
  lat = NULL,
  lon = NULL,
  address = NULL,
  id = NULL,
  grade = NULL,
  year = NULL
)
```

## Arguments

- lat, lon:

  Numeric vectors of equal length: latitude and longitude in decimal
  degrees (WGS 84). Default `NULL`.

- address:

  Street addresses: a character vector of one-line addresses
  (`"206 Washington St SW, Atlanta, GA 30334"`), or a data frame with
  columns `street`, `city`, `state` and `zip`. Give either `lat` and
  `lon` or `address`, not both. Default `NULL`.

- id:

  Identifiers for the inputs, the same length, carried into the output
  so results join back to your data. Default
  [`seq_along()`](https://rdrr.io/r/base/seq.html) of the input.

- grade:

  Keep only school zones serving this grade (`"pk"`, `"k"`, `"01"` to
  `"12"`; `"5"` and `"K"` are accepted). Default `NULL`: every grade.

- year:

  The zones' school year as its ending year (2027 is 2026-27). Default
  `NULL`: the current zones.

## Value

A tibble with columns, in order:

1.  `id`.

2.  The input: `lat`, `lon` for points; for addresses `address`, the
    geocoder's `match_status` (`"match"`, `"no_match"`, `"tie"`),
    `match_type` (`"exact"`, `"non_exact"`), `matched_address`, and the
    geocoded `lat` and `lon`.

3.  `geographic_type`: `"county"`, `"tract"`, `"block_group"`,
    `"school_district"`, `"elementary_school"`, `"middle_school"` or
    `"high_school"`.

4.  `geographic_id`: county FIPS (`"13121"`), tract GEOID
    (`"13121003500"`), block group GEOID (`"131210035001"`), district
    code (`"761"`), or for a school `"DISTRICT-SCHOOL"` (`"761-4560"`),
    the form
    [`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md)
    takes as `school_id`.

5.  `geographic_name`: the place's name.

6.  `grades`: a school row's grade range (`"K-5"`, `"6-8"`, `"9-12"`);
    `NA` on other rows.

7.  `note`: `NA`, or why a row is missing or needs care.

Attributes `assignment_note` and `note` carry the API's notes on reading
the zones.

## Output

A long tibble: **for each input, one row per place it falls in.** A
typical location gives seven rows: its county, tract, block group and
school district, then one row per zoned school. Rows for each input come
in a fixed order: county, tract, block group, district, then elementary,
middle and high schools by grade.

A level can have more than one school row: some homes are zoned to one
elementary school for kindergarten to grade 2 and another for grades
3-5. The `grades` column tells them apart; pass `grade` to keep only the
school for one grade.

The `note` column is `NA` normally, and one plain sentence otherwise, so
a missing row is never silent:

- a level with no zone collected yet, a gap between zones, or a level
  served by another district gets a row with `NA` id, name and grades,
  and a note saying why;

- an input outside Georgia, a point the API rejects, or an address the
  Census can't match gets one row with `NA` geographic columns and the
  reason; one bad input never stops the batch;

- in a Department of Defense district the district row has an `NA` id
  and a note;

- school rows whose zone has a known pending change, or which overlap
  another school's zone, say so.

## See also

[`gcd_school_zones()`](https://georgiacivicdata.org/r/reference/gcd_school_zones.md)
for the zones' shapes and precision (`method`, `accuracy_class`);
[`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md)
with `school_id` for data on a located school.

Other geography:
[`gcd_district_boundaries()`](https://georgiacivicdata.org/r/reference/gcd_district_boundaries.md),
[`gcd_school_zone_coverage()`](https://georgiacivicdata.org/r/reference/gcd_school_zone_coverage.md),
[`gcd_school_zone_status()`](https://georgiacivicdata.org/r/reference/gcd_school_zone_status.md),
[`gcd_school_zones()`](https://georgiacivicdata.org/r/reference/gcd_school_zones.md)

## Examples

``` r
if (FALSE) { # interactive()
# The Georgia State Capitol, by coordinates and by address
gcd_locate(lat = 33.7490, lon = -84.3880)
gcd_locate(address = "206 Washington St SW, Atlanta, GA 30334")

# Only the school for one grade
gcd_locate(lat = 33.7490, lon = -84.3880, grade = "9")
}
```

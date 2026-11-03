# Get the rows of a lookup table

Returns one of the platform's six lookup tables, the reference lists
every dataset's codes point to. They hold much more than names, and the
API never adds it to dataset rows:

- `"districts"`: district name, former names, type, Census id, county,
  address, coordinates, active flag.

- `"schools"`: school name, former names, level, grade span, county,
  NCES id, address, phone, website, coordinates, locale (city, suburb,
  town, rural), charter and active flags.

- `"counties"`: the 159 county names (without "County").

- `"tracts"`: 2020 Census tracts with county, land area and population.

- `"block_groups"`: 2020 block groups with tract, county, land area,
  population, housing units and households.

- `"demographics"`: each demographic group's label and category.

Use it to analyze results by locale, map schools, or browse what exists
("every school in Fulton County"). Unfiltered tables are cached for the
R session.

## Usage

``` r
gcd_dimension(
  name,
  ...,
  district = NULL,
  school = NULL,
  county = NULL,
  q = NULL,
  columns = NULL,
  n_max = Inf
)
```

## Arguments

- name:

  The lookup table: `"districts"`, `"schools"`, `"counties"`,
  `"tracts"`, `"block_groups"` or `"demographics"`.

- ...:

  Named filters on the table's key, enum and boolean columns, and
  `county_fips`, `district_code` or `tract_geoid` where the table has
  them. Each takes a vector (values are OR'd; filters are AND'd), for
  example `active = TRUE`, `district_type = "state_charter"` or
  `county_fips = "13121"`.

- district, school, county:

  Places by name, matched exactly against current and former names
  (ignoring case, accents and a trailing "County") and turned into
  codes. Character vectors; default `NULL`. Each applies only to tables
  with that code column.

- q:

  A single string: partial text search over the table's name columns,
  ignoring case and accents (`q = "eastside"`). Unlike the name
  arguments, it matches part of a name and returns every hit, so it is
  the tool for browsing. Default `NULL`.

- columns:

  A character vector of columns to return. Default `NULL`: all.

- n_max:

  The most rows to return. Default `Inf`: all.

## Value

A tibble ordered by the table's primary key, one row per district,
school, county, tract, block group or demographic group, typed from the
table's schema: codes (`district_code`, `school_code`, `county_fips`,
`tract_geoid`, `block_group_geoid`, `demographic`) and text columns are
character, coordinates and areas double, counts and `directory_year`
integer, `active` and `charter` logical. See
[`gcd_columns()`](https://georgiacivicdata.org/r/reference/gcd_columns.md)
for each table's columns.

## Joining schools

School codes repeat across districts, so join on `district_code` **and**
`school_code` together:

    schools <- gcd_dimension("schools",
                             columns = c("district_code", "school_code", "locale"))
    grad |>
      dplyr::left_join(schools, by = c("district_code", "school_code"))

## See also

[`gcd_columns()`](https://georgiacivicdata.org/r/reference/gcd_columns.md)
for a table's column dictionary;
[`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md),
whose results carry these tables' names beside their codes.

## Examples

``` r
if (FALSE) { # interactive()
gcd_dimension("counties")
gcd_dimension("schools", county = "Fulton", active = TRUE)
gcd_dimension("districts", district_type = "state_charter")
gcd_dimension("schools", q = "eastside",
              columns = c("district_code", "school_code", "school_name"))
}
```

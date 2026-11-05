# georgiacivicdata: Access Public Data from 'Georgia Civic Data'

An R client for the Georgia Civic Data REST API at
`https://georgiacivicdata.org/api/v1` (documentation:
<https://georgiacivicdata.org/docs>): cleaned public data about
Georgia's schools and communities, as tidy tibbles with place names
beside codes, typed from each dataset's schema.

## Functions

**Find data**

- [`gcd_datasets()`](https://georgiacivicdata.org/r/reference/gcd_datasets.md):
  the catalog, one row per dataset.

- [`gcd_search()`](https://georgiacivicdata.org/r/reference/gcd_search.md):
  ranked dataset search from plain words.

**Understand a dataset**

- [`gcd_describe()`](https://georgiacivicdata.org/r/reference/gcd_describe.md):
  everything about one dataset or lookup table.

- [`gcd_columns()`](https://georgiacivicdata.org/r/reference/gcd_columns.md):
  the column dictionary as a table.

- [`gcd_contract()`](https://georgiacivicdata.org/r/reference/gcd_contract.md):
  the formal ODCS data contract.

**Get data**

- [`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md):
  filtered rows, with names beside codes.

- [`gcd_values()`](https://georgiacivicdata.org/r/reference/gcd_values.md):
  which category combinations exist, with row counts.

**Lookup tables**

- [`gcd_dimension()`](https://georgiacivicdata.org/r/reference/gcd_dimension.md):
  districts, schools, counties, tracts, block groups and demographic
  groups, with their attributes.

**Geography and school zones**

- [`gcd_school_zones()`](https://georgiacivicdata.org/r/reference/gcd_school_zones.md):
  attendance-zone polygons.

- [`gcd_district_boundaries()`](https://georgiacivicdata.org/r/reference/gcd_district_boundaries.md):
  school district outlines.

- [`gcd_school_zone_status()`](https://georgiacivicdata.org/r/reference/gcd_school_zone_status.md):
  whether each school has a zone.

- [`gcd_school_zone_coverage()`](https://georgiacivicdata.org/r/reference/gcd_school_zone_coverage.md):
  how completely each district's zones were collected.

- [`gcd_locate()`](https://georgiacivicdata.org/r/reference/gcd_locate.md):
  the county, tract, block group, district and zoned schools for points
  or street addresses.

**Utilities**

- [`gcd_meta()`](https://georgiacivicdata.org/r/reference/gcd_meta.md)
  and
  [`gcd_citation()`](https://georgiacivicdata.org/r/reference/gcd_citation.md):
  the metadata and citation that travel with results.

- [`gcd_cache_clear()`](https://georgiacivicdata.org/r/reference/gcd_cache_clear.md):
  empty the session and disk caches.

## Missing values

A missing metric (`NA`) usually means the value was **suppressed** to
protect privacy (small counts), not that it is zero. Each dataset's
schema says which
([`gcd_describe()`](https://georgiacivicdata.org/r/reference/gcd_describe.md)),
and [`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md)
prints the API's advisory when a result holds suppressed values.

## Data license

The data is published under the Creative Commons Attribution 4.0
International license (CC BY 4.0,
<https://creativecommons.org/licenses/by/4.0/>). Credit "Georgia Civic
Data (georgiacivicdata.org)" and the original source;
[`gcd_citation()`](https://georgiacivicdata.org/r/reference/gcd_citation.md)
writes the citation. The package code is MIT-licensed.

## Options

- `gcd.quiet`: `TRUE` silences the advisory messages of
  [`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md)
  and the notes of the zone functions for the session.

- `gcd.cache`: `TRUE` turns on the disk cache of
  [`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md)
  for the session.

## See also

Useful links:

- <https://georgiacivicdata.org/r/>

- <https://github.com/shanejorr/georgia-data-rpackage>

- Report bugs at
  <https://github.com/shanejorr/georgia-data-rpackage/issues>

## Author

**Maintainer**: Shane Orr <shane@georgiacivicdata.org> \[copyright
holder\]

Authors:

- Shane Orr <shane@georgiacivicdata.org> \[copyright holder\]

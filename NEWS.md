# georgiacivicdata 0.1.0

* Initial CRAN submission.

## Features

* Find data: `gcd_datasets()` lists the catalog and `gcd_search()` ranks
  datasets from plain words, in English or Spanish.
* Understand a dataset: `gcd_describe()` (with a readable print method),
  `gcd_columns()` and `gcd_contract()`.
* Get data: `gcd_rows()` returns typed tibbles with place names beside
  codes, every category the filters don't exclude, the API's advisories as
  messages, and a `gcd_meta` attribute; large results download in full as
  CSV. `gcd_values()` lists the category combinations a filter covers.
* Lookup tables: `gcd_dimension()` returns districts, schools, counties,
  tracts, block groups and demographic groups.
* Places by name: `district`, `school` and `county` arguments match names
  exactly (ignoring case, accents and a trailing "County", and including
  former names) and stop with candidates when a name is ambiguous.
* Geography: `gcd_school_zones()`, `gcd_district_boundaries()`,
  `gcd_school_zone_status()` and `gcd_school_zone_coverage()`, as 'sf'
  objects or plain tibbles.
* `gcd_locate()` finds the county, tract, block group, school district and
  zoned schools for points, or for addresses geocoded locally with the U.S.
  Census batch geocoder (addresses never reach the Georgia Civic Data API).
* Utilities: `gcd_meta()`, `gcd_citation()` and `gcd_cache_clear()`, with an
  opt-in disk cache of row downloads that revalidates with the server's
  `ETag`.

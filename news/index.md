# Changelog

## georgiacivicdata 0.1.0

- Initial CRAN submission.

### Features

- Find data:
  [`gcd_datasets()`](https://georgiacivicdata.org/r/reference/gcd_datasets.md)
  lists the catalog and
  [`gcd_search()`](https://georgiacivicdata.org/r/reference/gcd_search.md)
  ranks datasets from plain words, in English or Spanish.
- Understand a dataset:
  [`gcd_describe()`](https://georgiacivicdata.org/r/reference/gcd_describe.md)
  (with a readable print method),
  [`gcd_columns()`](https://georgiacivicdata.org/r/reference/gcd_columns.md)
  and
  [`gcd_contract()`](https://georgiacivicdata.org/r/reference/gcd_contract.md).
  [`gcd_columns()`](https://georgiacivicdata.org/r/reference/gcd_columns.md)
  lists the joined name columns
  [`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md)
  returns by default (`labels = TRUE`), each after its code with `role`
  `"label"`.
- Get data:
  [`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md)
  returns typed tibbles with place names beside codes, every category
  the filters don’t exclude, the API’s advisories as messages, and a
  `gcd_meta` attribute; large results download in full as CSV.
  [`gcd_values()`](https://georgiacivicdata.org/r/reference/gcd_values.md)
  lists the category combinations a filter covers.
- Lookup tables:
  [`gcd_dimension()`](https://georgiacivicdata.org/r/reference/gcd_dimension.md)
  returns districts, schools, counties, tracts, block groups and
  demographic groups.
- Places by name: `district`, `school` and `county` arguments match
  names exactly (ignoring case, accents and a trailing “County”, and
  including former names) and stop with candidates when a name is
  ambiguous.
- Geography:
  [`gcd_school_zones()`](https://georgiacivicdata.org/r/reference/gcd_school_zones.md),
  [`gcd_district_boundaries()`](https://georgiacivicdata.org/r/reference/gcd_district_boundaries.md),
  [`gcd_school_zone_status()`](https://georgiacivicdata.org/r/reference/gcd_school_zone_status.md)
  and
  [`gcd_school_zone_coverage()`](https://georgiacivicdata.org/r/reference/gcd_school_zone_coverage.md),
  as ‘sf’ objects or plain tibbles.
- [`gcd_locate()`](https://georgiacivicdata.org/r/reference/gcd_locate.md)
  finds the county, tract, block group, school district and zoned
  schools for points, or for addresses geocoded locally with the U.S.
  Census batch geocoder (addresses never reach the Georgia Civic Data
  API).
- Utilities:
  [`gcd_meta()`](https://georgiacivicdata.org/r/reference/gcd_meta.md),
  [`gcd_citation()`](https://georgiacivicdata.org/r/reference/gcd_citation.md)
  and
  [`gcd_cache_clear()`](https://georgiacivicdata.org/r/reference/gcd_cache_clear.md),
  with an opt-in disk cache of row downloads that revalidates with the
  server’s `ETag`.

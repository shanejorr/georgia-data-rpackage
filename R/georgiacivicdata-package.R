#' georgiacivicdata: Access Public Data from 'Georgia Civic Data'
#'
#' @description
#' An R client for the Georgia Civic Data REST API at
#' `https://georgiacivicdata.org/api/v1` (documentation:
#' <https://georgiacivicdata.org/docs>): cleaned public data about
#' Georgia's schools and communities, as tidy tibbles with place names
#' beside codes, typed from each dataset's schema.
#'
#' @section Functions:
#' **Find data**
#' - [gcd_datasets()]: the catalog, one row per dataset.
#' - [gcd_search()]: ranked dataset search from plain words.
#'
#' **Understand a dataset**
#' - [gcd_describe()]: everything about one dataset or lookup table.
#' - [gcd_columns()]: the column dictionary as a table.
#' - [gcd_contract()]: the formal ODCS data contract.
#'
#' **Get data**
#' - [gcd_rows()]: filtered rows, with names beside codes.
#' - [gcd_values()]: which category combinations exist, with row counts.
#'
#' **Lookup tables**
#' - [gcd_dimension()]: districts, schools, counties, tracts, block groups
#'   and demographic groups, with their attributes.
#'
#' **Geography and school zones**
#' - [gcd_school_zones()]: attendance-zone polygons.
#' - [gcd_district_boundaries()]: school district outlines.
#' - [gcd_school_zone_status()]: whether each school has a zone.
#' - [gcd_school_zone_coverage()]: how completely each district's zones
#'   were collected.
#' - [gcd_locate()]: the county, tract, block group, district and zoned
#'   schools for points or street addresses.
#'
#' **Utilities**
#' - [gcd_meta()] and [gcd_citation()]: the metadata and citation that
#'   travel with results.
#' - [gcd_cache_clear()]: empty the session and disk caches.
#'
#' @section Missing values:
#' A missing metric (`NA`) usually means the value was **suppressed** to
#' protect privacy (small counts), not that it is zero. Each dataset's
#' schema says which ([gcd_describe()]), and [gcd_rows()] prints the API's
#' advisory when a result holds suppressed values.
#'
#' @section Data license:
#' The data is published under the Creative Commons Attribution 4.0
#' International license (CC BY 4.0,
#' <https://creativecommons.org/licenses/by/4.0/>). Credit "Georgia Civic
#' Data (georgiacivicdata.org)" and the original source; [gcd_citation()]
#' writes the citation. The package code is MIT-licensed.
#'
#' @section Options:
#' - `gcd.quiet`: `TRUE` silences the advisory messages of [gcd_rows()]
#'   and the notes of the zone functions for the session.
#' - `gcd.cache`: `TRUE` turns on the disk cache of [gcd_rows()] for the
#'   session.
#'
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom rlang %||%
## usethis namespace: end
NULL

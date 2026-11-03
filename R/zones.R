# School attendance zones and district boundaries.

#' The zone levels, in order
#' @noRd
zone_levels <- c("elementary", "middle", "high")

#' Grades as the API spells them, in order
#' @noRd
grade_codes <- c("pk", "k", sprintf("%02d", 1:12))

#' Normalize one grade: "5" -> "05", "K" -> "k", "PK" / "Pre-K" -> "pk"
#' @noRd
normalize_grade <- function(grade, call = rlang::caller_env()) {
  if (is.null(grade)) {
    return(NULL)
  }
  if (is.numeric(grade)) {
    grade <- as.character(grade)
  }
  if (!is_string(grade)) {
    cli::cli_abort("{.arg grade} must be one grade, such as {.str k}, {.str 05} or {.code 9}.",
                   call = call)
  }
  g <- gsub("[[:space:]-]", "", tolower(grade))
  g <- switch(g, kindergarten = "k", kk = "k", prek = "pk", prekindergarten = "pk", g)
  if (grepl("^[0-9]+$", g)) {
    g <- sprintf("%02d", as.integer(g))
  }
  if (!g %in% grade_codes) {
    cli::cli_abort(
      c("{.arg grade} must be one of {.val {grade_codes}}.",
        i = "{.str 5} and {.str K} are accepted too."),
      call = call
    )
  }
  g
}

#' Check a single year argument
#' @noRd
check_year1 <- function(year, call = rlang::caller_env()) {
  if (is.null(year)) {
    return(NULL)
  }
  if (!is.numeric(year) || length(year) != 1 || is.na(year) || year != trunc(year)) {
    cli::cli_abort("{.arg year} must be a single year, such as {.code 2027} (the 2026-27 school year).",
                   call = call)
  }
  format_number(year)
}

#' sf is needed for geometry
#' @noRd
check_sf <- function(geometry, call = rlang::caller_env()) {
  check_flag(geometry, call = call)
  if (geometry) {
    rlang::check_installed("sf", reason = "to return geometry (or use `geometry = FALSE`).",
                           call = call)
  }
}

#' Fetch a geometry route as `sf` (GeoJSON) or a tibble (JSON)
#'
#' @returns A list: `data` (sf or tibble) and `body` (the parsed JSON for
#'   `geometry = FALSE`, else `NULL`).
#' @noRd
fetch_geometry <- function(path, query, geometry, call = rlang::caller_env()) {
  query$format <- if (geometry) "geojson" else "json"
  req <- gcd_request(path, query = query, timeout = 600)
  if (geometry) {
    file <- tempfile(fileext = ".geojson")
    on.exit(unlink(file), add = TRUE)
    resp <- gcd_perform(req, path = file, call = call)
    if (!file.exists(file)) {
      writeBin(httr2::resp_body_raw(resp), file)
    }
    data <- sf::read_sf(file, quiet = TRUE)
    return(list(data = data, body = NULL))
  }
  body <- resp_json(gcd_perform(req, call = call), simplify = TRUE)
  data <- data_frame_or_null(body$data)
  data <- if (is.null(data)) tibble::tibble() else tibble::as_tibble(data)
  list(data = data, body = body)
}

#' Keep only the (district, school) pairs a school name resolved to
#' @noRd
keep_pairs <- function(df, schools) {
  if (is.null(schools) || !nrow(df)) {
    return(df)
  }
  keep <- paste(df$district_code, df$school_code) %in%
    paste(schools$district_code, schools$school_code)
  df[keep, ]
}

#' Codes from code and name arguments, for routes that take code lists
#' @noRd
geometry_codes <- function(district_code, school_code, district, school,
                           columns, call = rlang::caller_env()) {
  check_chr(district_code, call = call)
  check_chr(school_code, call = call)
  filters <- compact(list(district_code = district_code, school_code = school_code))
  places <- resolve_places(district, school, NULL, filters = filters,
                           columns = columns, call = call)
  list(
    district_code = unique(c(district_code, places$district_code,
                             places$schools$district_code)),
    school_code = unique(c(school_code, places$schools$school_code)),
    schools = places$schools
  )
}

#' Get school attendance zones
#'
#' @description
#' Attendance-zone polygons: the areas that assign a home to its zoned
#' elementary, middle and high school, one polygon per school, level and
#' grade run, for the current school year.
#'
#' **Zones differ in precision.** Some are the district's official GIS
#' layers; others are digitized from PDF maps, rebuilt from street lists,
#' or are the whole district outline (districts with one school per
#' grade). Read `method` and `accuracy_class` before treating zones as
#' equally exact, and see [gcd_school_zone_coverage()] for how completely
#' each district was collected. A zone is the default assignment, not an
#' official enrollment determination: confirm with the district.
#'
#' **A statewide pull is large**, especially at `resolution = "full"`.
#' Filter to a district and keep the `"display"` default for maps.
#'
#' @param district_code,school_code Character vectors of codes. Default
#'   `NULL`.
#' @param district,school Names, matched to codes as in [gcd_rows()]. A
#'   school name found in more than one district needs `district` too.
#'   Default `NULL`.
#' @param zone_level `"elementary"`, `"middle"` and/or `"high"`. Default
#'   `NULL`: all.
#' @param grade One grade: keep zones serving it (`"pk"`, `"k"`, `"01"` to
#'   `"12"`; `"5"` and `"K"` are accepted). Default `NULL`: all.
#' @param year The zones' school year as its ending year (2027 is
#'   2026-27). Default `NULL`: the current zones.
#' @param resolution `"display"` (default): simplified polygons for maps,
#'   much smaller; `"full"`: the source polygons the point lookup uses.
#' @param geometry `TRUE` (default) returns an `sf` object (needs the
#'   'sf' package); `FALSE` returns the attributes as a plain tibble.
#' @returns An `sf` object (or, with `geometry = FALSE`, a tibble), one row
#'   per zone, with columns `year` (integer), `district_code`,
#'   `district_name`, `school_code`, `school_name`, `zone_level`,
#'   `grade_low`, `grade_high` (`"pk"`, `"k"`, `"01"` ... `"12"`),
#'   `method` (how the zone was built), `accuracy_class`,
#'   `currency_status`, `boundary_vintage`, `source_url`, `retrieved_on`
#'   (Date), `area_sq_mi`, the bounding box (`bbox_xmin`, `bbox_ymin`,
#'   `bbox_xmax`, `bbox_ymax`), `source_school_name` (the name as the
#'   district's map spells it), then `positional_rmse_m`, `currency_note`,
#'   `source_publisher`, `nces_school_id`, `district_census_id`,
#'   `nces_lea_id` and the `geometry` (WGS 84). The API's disclaimer is
#'   the `note` attribute.
#' @family geography
#' @seealso [gcd_locate()] to find the zones a point falls in;
#'   [gcd_school_zone_status()] for schools without a zone;
#'   [gcd_describe()] with `"school_attendance_zones"` for every field.
#' @export
#' @examplesIf interactive() && requireNamespace("sf", quietly = TRUE)
#' zones <- gcd_school_zones(district = "Atlanta Public Schools",
#'                           zone_level = "high")
#' plot(zones["school_name"])
#'
#' gcd_school_zones(district_code = "630", geometry = FALSE)
gcd_school_zones <- function(district_code = NULL, school_code = NULL,
                             district = NULL, school = NULL,
                             zone_level = NULL, grade = NULL, year = NULL,
                             resolution = c("display", "full"),
                             geometry = TRUE) {
  resolution <- rlang::arg_match(resolution)
  check_sf(geometry)
  check_chr(zone_level)
  grade <- normalize_grade(grade)
  year <- check_year1(year)
  codes <- geometry_codes(district_code, school_code, district, school,
                          columns = c("district_code", "school_code"))
  query <- list(
    district_code = codes$district_code,
    school_code = codes$school_code,
    zone_level = zone_level,
    grade = grade,
    year = year,
    resolution = resolution
  )
  schema <- dataset_schema("school_attendance_zones")
  got <- fetch_geometry(c("datasets", "school_attendance_zones", "rows"),
                        compact(query), geometry)
  out <- keep_pairs(got$data, codes$schools)
  out <- apply_schema_types(out, schema_types(schema))
  out <- order_columns(out, c(
    "year", "district_code", "district_name", "school_code", "school_name",
    "zone_level", "grade_low", "grade_high", "method", "accuracy_class",
    "currency_status", "boundary_vintage", "source_url", "retrieved_on",
    "area_sq_mi", "bbox_xmin", "bbox_ymin", "bbox_xmax", "bbox_ymax",
    "source_school_name", "positional_rmse_m", "currency_note",
    "source_publisher", "nces_school_id", "district_census_id", "nces_lea_id"
  ))
  attr(out, "note") <- got$body$note %||% schema$note
  out
}

#' Get school district boundaries
#'
#' @description
#' The Census TIGER/Line outlines of Georgia's school districts, keyed to
#' district codes: unified districts, the secondary-only pieces some
#' districts serve (Fort Benning grades 9-12), and the Department of
#' Defense districts (which have no district code).
#'
#' @param district_code A character vector of district codes. Default
#'   `NULL`: every district.
#' @param district District names, matched to codes as in [gcd_rows()].
#'   Default `NULL`.
#' @inheritParams gcd_school_zones
#' @returns An `sf` object (or, with `geometry = FALSE`, a tibble), one row
#'   per district piece, with columns `district_code`, `district_name` (for
#'   Department of Defense districts, the Census name), `boundary_type`
#'   (`"unified"`, `"secondary_extension"` or `"dodea"`),
#'   `district_census_id`, `nces_lea_id`, `grade_low`, `grade_high`,
#'   `tiger_geoid`, `tiger_name`, `tiger_vintage`, `land_area_sq_mi`,
#'   `area_sq_mi`, the bounding box and the `geometry` (WGS 84).
#' @family geography
#' @seealso [gcd_school_zones()] for the zones inside each district.
#' @export
#' @examplesIf interactive() && requireNamespace("sf", quietly = TRUE)
#' gcd_district_boundaries(district = "Clay County")
#' gcd_district_boundaries(geometry = FALSE)
gcd_district_boundaries <- function(district_code = NULL, district = NULL,
                                    geometry = TRUE) {
  check_sf(geometry)
  codes <- geometry_codes(district_code, NULL, district, NULL,
                          columns = "district_code")
  got <- fetch_geometry(c("datasets", "school_district_boundaries", "rows"),
                        compact(list(district_code = codes$district_code)),
                        geometry)
  out <- got$data
  if (all(c("district_name", "tiger_name") %in% names(out))) {
    missing <- is.na(out$district_name)
    out$district_name[missing] <- out$tiger_name[missing]
  }
  order_columns(out, c(
    "district_code", "district_name", "boundary_type", "district_census_id",
    "nces_lea_id", "grade_low", "grade_high", "tiger_geoid", "tiger_name",
    "tiger_vintage", "land_area_sq_mi", "area_sq_mi", "bbox_xmin",
    "bbox_ymin", "bbox_xmax", "bbox_ymax"
  ))
}

#' Get each school's attendance-zone status
#'
#' @description
#' Whether each school of the standard districts has an attendance zone on
#' the platform and, if not, why: a magnet or charter school with no zone,
#' a district whose maps are not published yet, and so on. Answers "why
#' doesn't this school have a zone?" without inferring it from a missing
#' polygon.
#'
#' @inheritParams gcd_school_zones
#' @param zone_status `"zoned"`, `"no_zone"` and/or `"not_yet_collected"`.
#'   Default `NULL`: all.
#' @param no_zone_category Why a school has no zone (the API's categories,
#'   listed by [gcd_describe()] with `"school_attendance_zones"`). Default
#'   `NULL`: all.
#' @returns A tibble, one row per school, with columns `year` (integer),
#'   `district_code`, `district_name`, `school_code`, `school_name`,
#'   `zone_status`, `zone_levels` (the levels it is zoned for, as one
#'   string), `no_zone_category` and `reason`. The API's note on reading
#'   the table is the `note` attribute.
#' @family geography
#' @seealso [gcd_school_zones()] for the zones; [gcd_school_zone_coverage()]
#'   for each district's coverage.
#' @export
#' @examplesIf interactive()
#' gcd_school_zone_status(district = "Atlanta Public Schools")
#' gcd_school_zone_status(zone_status = "no_zone")
gcd_school_zone_status <- function(district_code = NULL, school_code = NULL,
                                   district = NULL, school = NULL,
                                   zone_status = NULL,
                                   no_zone_category = NULL) {
  check_chr(zone_status)
  check_chr(no_zone_category)
  codes <- geometry_codes(district_code, school_code, district, school,
                          columns = c("district_code", "school_code"))
  query <- list(
    district_code = codes$district_code,
    school_code = codes$school_code,
    zone_status = zone_status,
    no_zone_category = no_zone_category
  )
  got <- fetch_geometry(c("datasets", "school_attendance_zones", "school_status"),
                        compact(query), geometry = FALSE)
  out <- keep_pairs(got$data, codes$schools)
  if (!nrow(out)) {
    out <- tibble::tibble(
      year = integer(), district_code = character(), district_name = character(),
      school_code = character(), school_name = character(),
      zone_status = character(), zone_levels = character(),
      no_zone_category = character(), reason = character()
    )
  }
  out <- apply_schema_types(out, c(year = "integer"))
  out <- order_columns(out, c(
    "year", "district_code", "district_name", "school_code", "school_name",
    "zone_status", "zone_levels", "no_zone_category", "reason"
  ))
  attr(out, "note") <- got$body$note
  out
}

#' Get each district's attendance-zone coverage
#'
#' @description
#' How completely each standard district's attendance zones were
#' collected, one row per district and zone level: the source tier, the
#' status of each level, the share of the district's land and 2020
#' population the zones cover, how they were built, and the reason for
#' anything short of complete.
#'
#' The API returns one row per district with a column per level
#' (`level_status_elementary`, `pct_population_middle`, ...); this function
#' pivots those columns long. The district filter runs in R (the route
#' takes no filters; the table has about 180 rows).
#'
#' @inheritParams gcd_district_boundaries
#' @param geometry `FALSE` (default) returns a tibble; `TRUE` returns an
#'   `sf` object of the district outlines carrying the same fields (needs
#'   the 'sf' package).
#' @returns A tibble (or `sf` object), one row per district and zone level,
#'   with columns `year` (integer), `district_code`, `district_name`,
#'   `tier` (the source tier, A to E or N), `status` (the district's
#'   overall status), `zone_level`, `level_status` (`"zoned"`,
#'   `"one_school_per_grade"`, `"partial"`, `"not_available"`,
#'   `"served_by_other_district"`), `pct_land_area` and `pct_population`
#'   (0-1, the share the level's zones cover), `zone_count`, `methods`,
#'   `accuracy_classes`, `reason`, then `levels_covered`,
#'   `currency_statuses`, `best_lead`, `extension_note` and
#'   `served_elsewhere` (a list-column of tibbles: the other district's
#'   school serving that level, with `district_code`, `school_code` and
#'   `reason`).
#' @family geography
#' @seealso [gcd_school_zones()] for the zones.
#' @export
#' @examplesIf interactive()
#' gcd_school_zone_coverage(district = "Clay County")
#' coverage <- gcd_school_zone_coverage()
#' table(coverage$zone_level, coverage$level_status)
gcd_school_zone_coverage <- function(district_code = NULL, district = NULL,
                                     geometry = FALSE) {
  check_sf(geometry)
  codes <- geometry_codes(district_code, NULL, district, NULL,
                          columns = "district_code")
  got <- fetch_geometry(c("datasets", "school_attendance_zones", "coverage"),
                        list(), geometry)
  data <- got$data
  if (length(codes$district_code)) {
    data <- data[data$district_code %in% codes$district_code, ]
  }
  out <- pivot_coverage(data)
  attr(out, "note") <- got$body$note
  out
}

#' Pivot the per-level coverage columns long (keeps an `sf` geometry)
#' @noRd
pivot_coverage <- function(data) {
  is_sf <- inherits(data, "sf")
  geom <- NULL
  if (is_sf) {
    geom <- sf::st_geometry(data)
    data <- sf::st_drop_geometry(data)
  }
  data <- tibble::as_tibble(data)
  data$.row <- seq_len(nrow(data))
  served <- data$served_elsewhere
  if (is.null(served)) {
    served <- rep(list(NULL), nrow(data))
  }
  data$served_elsewhere <- NULL
  pattern <- paste0("^(.+)_(", paste(zone_levels, collapse = "|"), ")$")
  long <- tidyr::pivot_longer(
    data,
    cols = tidyr::matches(pattern),
    names_to = c(".value", "zone_level"),
    names_pattern = pattern
  )
  long$zone_level <- as.character(long$zone_level)
  long <- long[order(long$.row, match(long$zone_level, zone_levels)), ]
  long$served_elsewhere <- unname(Map(served_for_level, served[long$.row], long$zone_level))
  long <- apply_schema_types(long, c(year = "integer", zone_count = "integer",
                                     pct_land_area = "number",
                                     pct_population = "number"))
  out <- order_columns(long, c(
    "year", "district_code", "district_name", "tier", "status", "zone_level",
    "level_status", "pct_land_area", "pct_population", "zone_count",
    "methods", "accuracy_classes", "reason", "levels_covered",
    "currency_statuses", "best_lead", "extension_note", "served_elsewhere"
  ))
  rows <- out$.row
  out$.row <- NULL
  if (is_sf) {
    out$geometry <- geom[rows]
    out <- sf::st_as_sf(out, sf_column_name = "geometry")
  }
  out
}

#' The `served_elsewhere` entries for one level, as a tibble
#' @noRd
served_for_level <- function(entries, level) {
  empty <- tibble::tibble(district_code = character(), school_code = character(),
                          reason = character())
  if (is.character(entries) && length(entries) == 1 && !is.na(entries)) {
    entries <- jsonlite::fromJSON(entries, simplifyVector = TRUE)
  }
  if (is.null(entries) || !length(entries)) {
    return(empty)
  }
  if (!is.data.frame(entries)) {
    entries <- records_to_tibble(entries)
  }
  entries <- tibble::as_tibble(entries)
  if (!"zone_level" %in% names(entries)) {
    return(empty)
  }
  entries <- entries[entries$zone_level == level, ]
  entries[intersect(c("district_code", "school_code", "reason"), names(entries))]
}

#' Locate points or addresses
#'
#' @description
#' The county, 2020 Census tract and block group, school district and
#' zoned schools that points or street addresses fall in.
#'
#' Points are sent to the API's `POST /locate` route in batches of up to
#' 1,000, so coordinates never appear in URLs and nothing is cached.
#' **Addresses never reach the Georgia Civic Data API**: the package
#' geocodes them on your computer with the U.S. Census batch geocoder
#' (<https://geocoding.geo.census.gov/geocoder/>, benchmark
#' `Public_AR_Current`, the address data the API's own search uses; up to
#' 10,000 addresses per upload), then sends the coordinates as points. An
#' address the Census can't match is never sent. To geocode with another
#' service, geocode first (for example with the 'tidygeocoder' package)
#' and pass `lat` and `lon`.
#'
#' A zone is the default assignment, not the only option: a student may
#' attend another public school by transfer, or a charter, magnet or other
#' choice school. This is not an official enrollment determination;
#' confirm with the school district.
#'
#' @section Output:
#' A long tibble: **for each input, one row per place it falls in.** A
#' typical location gives seven rows: its county, tract, block group and
#' school district, then one row per zoned school. Rows for each input
#' come in a fixed order: county, tract, block group, district, then
#' elementary, middle and high schools by grade.
#'
#' A level can have more than one school row: some homes are zoned to one
#' elementary school for kindergarten to grade 2 and another for grades
#' 3-5. The `grades` column tells them apart; pass `grade` to keep only
#' the school for one grade.
#'
#' The `note` column is `NA` normally, and one plain sentence otherwise,
#' so a missing row is never silent:
#' - a level with no zone collected yet, a gap between zones, or a level
#'   served by another district gets a row with `NA` id, name and grades,
#'   and a note saying why;
#' - an input outside Georgia, a point the API rejects, or an address the
#'   Census can't match gets one row with `NA` geographic columns and the
#'   reason; one bad input never stops the batch;
#' - in a Department of Defense district the district row has an `NA` id
#'   and a note;
#' - school rows whose zone has a known pending change, or which overlap
#'   another school's zone, say so.
#'
#' @param lat,lon Numeric vectors of equal length: latitude and longitude
#'   in decimal degrees (WGS 84). Default `NULL`.
#' @param address Street addresses: a character vector of one-line
#'   addresses (`"206 Washington St SW, Atlanta, GA 30334"`), or a data
#'   frame with columns `street`, `city`, `state` and `zip`. Give either
#'   `lat` and `lon` or `address`, not both. Default `NULL`.
#' @param id Identifiers for the inputs, the same length, carried into the
#'   output so results join back to your data. Default `seq_along()` of
#'   the input.
#' @param grade Keep only school zones serving this grade (`"pk"`, `"k"`,
#'   `"01"` to `"12"`; `"5"` and `"K"` are accepted). Default `NULL`: every
#'   grade.
#' @param year The zones' school year as its ending year (2027 is
#'   2026-27). Default `NULL`: the current zones.
#' @returns A tibble with columns, in order:
#'   1. `id`.
#'   2. The input: `lat`, `lon` for points; for addresses `address`, the
#'      geocoder's `match_status` (`"match"`, `"no_match"`, `"tie"`),
#'      `match_type` (`"exact"`, `"non_exact"`), `matched_address`, and the
#'      geocoded `lat` and `lon`.
#'   3. `geographic_type`: `"county"`, `"tract"`, `"block_group"`,
#'      `"school_district"`, `"elementary_school"`, `"middle_school"` or
#'      `"high_school"`.
#'   4. `geographic_id`: county FIPS (`"13121"`), tract GEOID
#'      (`"13121003500"`), block group GEOID (`"131210035001"`), district
#'      code (`"761"`), or for a school `"DISTRICT-SCHOOL"` (`"761-4560"`),
#'      the form [gcd_rows()] takes as `school_id`.
#'   5. `geographic_name`: the place's name.
#'   6. `grades`: a school row's grade range (`"K-5"`, `"6-8"`, `"9-12"`);
#'      `NA` on other rows.
#'   7. `note`: `NA`, or why a row is missing or needs care.
#'
#'   Attributes `assignment_note` and `note` carry the API's notes on
#'   reading the zones.
#' @family geography
#' @seealso [gcd_school_zones()] for the zones' shapes and precision
#'   (`method`, `accuracy_class`); [gcd_rows()] with `school_id` for data
#'   on a located school.
#' @export
#' @examplesIf interactive()
#' # The Georgia State Capitol, by coordinates and by address
#' gcd_locate(lat = 33.7490, lon = -84.3880)
#' gcd_locate(address = "206 Washington St SW, Atlanta, GA 30334")
#'
#' # Only the school for one grade
#' gcd_locate(lat = 33.7490, lon = -84.3880, grade = "9")
gcd_locate <- function(lat = NULL, lon = NULL, address = NULL, id = NULL,
                       grade = NULL, year = NULL) {
  grade <- normalize_grade(grade)
  year <- check_year1(year)
  has_points <- !is.null(lat) || !is.null(lon)
  if (has_points && !is.null(address)) {
    cli::cli_abort("Give {.arg lat} and {.arg lon}, or {.arg address}, not both.")
  }
  if (!has_points && is.null(address)) {
    cli::cli_abort("Give {.arg lat} and {.arg lon}, or {.arg address}.")
  }
  if (has_points) {
    check_points(lat, lon)
    input <- tibble::tibble(lat = as.numeric(lat), lon = as.numeric(lon))
    notes <- ifelse(is.na(input$lat) | is.na(input$lon),
                    "No coordinates were given.", NA_character_)
  } else {
    addresses <- address_input(address)
    geo <- census_geocode(addresses)
    input <- tibble::tibble(address = addresses$address, geo)
    notes <- geocode_notes(geo$match_status)
  }
  n <- nrow(input)
  id <- check_ids(id, n)

  send <- which(!is.na(input$lat) & !is.na(input$lon))
  results <- vector("list", n)
  if (length(send)) {
    results[send] <- locate_points(input$lat[send], input$lon[send],
                                   grade = grade, year = year)
  }
  lookups <- locate_lookups(results)
  pieces <- lapply(seq_len(n), function(i) {
    rows <- if (is.null(results[[i]])) {
      failure_row(notes[[i]])
    } else {
      locate_rows(results[[i]], lookups)
    }
    rows$.input <- rep(i, nrow(rows))
    rows
  })
  long <- do.call(rbind, pieces)
  out <- tibble::tibble(id = id[long$.input], input[long$.input, ],
                        long[setdiff(names(long), ".input")])
  first <- Find(function(r) !is.null(r) && is.null(r$error), results)
  assignment_note <- first$assignment_note
  attr(out, "assignment_note") <- assignment_note
  attr(out, "note") <- first$note
  if (is_string(assignment_note) && !is_quiet() && first_time("assignment_note")) {
    cli::cli_inform(c(i = "{assignment_note}"))
  }
  out
}

#' @noRd
check_points <- function(lat, lon, call = rlang::caller_env()) {
  if (!is.numeric(lat) || !is.numeric(lon) || !length(lat) ||
      length(lat) != length(lon)) {
    cli::cli_abort("{.arg lat} and {.arg lon} must be numeric vectors of the same length.",
                   call = call)
  }
}

#' @noRd
check_ids <- function(id, n, call = rlang::caller_env()) {
  if (is.null(id)) {
    return(seq_len(n))
  }
  if (!is.atomic(id) || length(id) != n) {
    cli::cli_abort("{.arg id} must be a vector with one value per input ({n}).",
                   call = call)
  }
  id
}

#' Notes for addresses the geocoder didn't place
#' @noRd
geocode_notes <- function(status) {
  out <- rep(NA_character_, length(status))
  out[is.na(status)] <- "No address was given."
  out[status %in% "no_match"] <- "The U.S. Census geocoder found no match for this address."
  out[status %in% "tie"] <- "The U.S. Census geocoder found more than one possible match for this address."
  out
}

#' POST points to /locate in batches, checking the echoed ids
#'
#' The ids sent are the points' positions; the user's own ids never leave
#' the computer.
#' @returns A list of results, one per point, in input order.
#' @noRd
locate_points <- function(lat, lon, grade = NULL, year = NULL,
                          batch_size = 1000, call = rlang::caller_env()) {
  index <- seq_along(lat)
  batches <- split(index, ceiling(index / batch_size))
  progress <- NULL
  if (length(batches) > 1) {
    progress <- cli::cli_progress_bar("Locating points", total = length(batches))
  }
  out <- vector("list", length(lat))
  for (batch in batches) {
    points <- lapply(batch, function(i) {
      list(id = as.character(i), lat = lat[[i]], lon = lon[[i]])
    })
    body <- compact(list(points = points, grade = grade,
                         year = if (!is.null(year)) as.integer(year)))
    req <- gcd_request("locate", timeout = 600)
    req <- httr2::req_body_json(req, body, auto_unbox = TRUE, digits = NA)
    results <- resp_json(gcd_perform(req, call = call))$results
    echoed <- vapply(results, function(r) as.character(r$id %||% NA), character(1))
    if (length(results) != length(batch) || !identical(echoed, as.character(batch))) {
      abort_gcd(
        "The API's location results didn't match the points sent.",
        code = "locate_mismatch", call = call
      )
    }
    out[batch] <- results
    if (!is.null(progress)) {
      cli::cli_progress_update(id = progress)
    }
  }
  if (!is.null(progress)) {
    cli::cli_progress_done(id = progress)
  }
  out
}

#' The lookup tables needed to name the counties, tracts and block groups
#' found (read whole and locally, so no location leaves the API call)
#' @noRd
locate_lookups <- function(results) {
  ok <- Filter(function(r) !is.null(r) && is.null(r$error) &&
                 !identical(r$coverage_status, "outside_georgia"), results)
  if (!length(ok)) {
    return(list())
  }
  has <- function(field) any(vapply(ok, function(r) !is.null(r[[field]]), logical(1)))
  compact(list(
    counties = if (has("county_fips")) lookup_table("counties"),
    tracts = if (has("tract_geoid")) lookup_table("tracts"),
    block_groups = if (has("block_group_geoid")) lookup_table("block_groups")
  ))
}

#' One input's row when it couldn't be located
#' @noRd
failure_row <- function(note) {
  locate_frame(NA_character_, NA_character_, NA_character_, NA_character_, note)
}

#' @noRd
locate_frame <- function(type, id, name, grades = NA_character_,
                         note = NA_character_) {
  data.frame(
    geographic_type = as.character(type),
    geographic_id = as.character(id),
    geographic_name = as.character(name),
    grades = as.character(grades),
    note = as.character(note),
    stringsAsFactors = FALSE
  )
}

#' A name from a lookup table, by code
#' @noRd
lookup_name <- function(table, key, name_col, code) {
  if (is.null(code) || is.null(table)) {
    return(NA_character_)
  }
  table[[name_col]][match(code, table[[key]])]
}

#' The rows for one located point
#' @noRd
locate_rows <- function(r, lookups) {
  if (!is.null(r$error)) {
    return(failure_row(paste0(
      "The API couldn't locate this point: ", r$error$message %||% "invalid input", "."
    )))
  }
  if (identical(r$coverage_status, "outside_georgia")) {
    return(failure_row("The point is outside Georgia."))
  }
  rows <- list()
  if (!is.null(r$county_fips)) {
    rows$county <- locate_frame("county", r$county_fips,
                                lookup_name(lookups$counties, "county_fips",
                                            "county_name", r$county_fips))
  }
  if (!is.null(r$tract_geoid)) {
    rows$tract <- locate_frame("tract", r$tract_geoid,
                               lookup_name(lookups$tracts, "tract_geoid",
                                           "tract_name", r$tract_geoid))
  }
  if (!is.null(r$block_group_geoid)) {
    rows$block_group <- locate_frame(
      "block_group", r$block_group_geoid,
      lookup_name(lookups$block_groups, "block_group_geoid",
                  "block_group_name", r$block_group_geoid)
    )
  }
  district <- r$district
  dodea <- identical(district$boundary_type, "dodea")
  reason <- r$coverage_reason
  if (!is.null(district)) {
    rows$district <- locate_frame(
      "school_district",
      if (dodea) NA_character_ else district$district_code %||% NA_character_,
      district$district_name %||% NA_character_,
      note = if (dodea) {
        reason %||% "Department of Defense (DoDEA) schools serve this area; they publish no zones."
      } else {
        NA_character_
      }
    )
  }
  zones <- r$zones %||% list()
  level_rows <- list()
  for (level in zone_levels) {
    level_zones <- Filter(function(z) identical(z$zone_level, level), zones)
    if (length(level_zones)) {
      level_rows[[level]] <- zone_frame(level_zones, r)
      next
    }
    status <- r$level_status[[level]]
    if (!is.null(status) && !status %in% c("zoned", "one_school_per_grade")) {
      level_rows[[level]] <- locate_frame(
        paste0(level, "_school"), NA_character_, NA_character_,
        note = level_note(level, status, r, dodea)
      )
    }
  }
  if (!length(level_rows) && is_string(reason) && !dodea && !is.null(rows$district)) {
    rows$district$note <- reason
  }
  out <- do.call(rbind, c(unname(rows), unname(level_rows)))
  if (is.null(out)) {
    out <- failure_row(reason %||% "No place was found for this point.")
  }
  rownames(out) <- NULL
  out
}

#' Rows for the zones of one level, with warnings on the rows they concern
#' @noRd
zone_frame <- function(zones, r) {
  field <- function(f) vapply(zones, function(z) as.character(z[[f]] %||% NA), character(1))
  district_code <- field("district_code")
  school_code <- field("school_code")
  out <- locate_frame(
    paste0(field("zone_level"), "_school"),
    paste(district_code, school_code, sep = "-"),
    field("school_name"),
    format_grades(field("grade_low"), field("grade_high"))
  )
  stale <- field("currency_status") %in% "stale_known_changes"
  if (is_string(r$currency_warning) && any(stale)) {
    out$note[stale] <- add_note(out$note[stale], r$currency_warning)
  }
  overlap <- overlapping_zones(field("grade_low"), field("grade_high"),
                               paste(district_code, school_code))
  if (is_string(r$overlap_warning) && any(overlap)) {
    out$note[overlap] <- add_note(out$note[overlap], r$overlap_warning)
  }
  out
}

#' Zones of one level whose grade runs intersect another school's
#' @noRd
overlapping_zones <- function(lo, hi, school) {
  lo <- match(lo, grade_codes)
  hi <- match(hi, grade_codes)
  n <- length(lo)
  out <- rep(FALSE, n)
  for (i in seq_len(n)) {
    for (j in seq_len(n)) {
      if (i != j && school[i] != school[j] && !anyNA(c(lo[i], hi[i], lo[j], hi[j])) &&
          lo[i] <= hi[j] && lo[j] <= hi[i]) {
        out[i] <- TRUE
      }
    }
  }
  out
}

#' @noRd
add_note <- function(note, text) {
  ifelse(is.na(note), text, paste(note, text))
}

#' The note for a level with no zone row
#' @noRd
level_note <- function(level, status, r, dodea = FALSE) {
  reason <- reason_for_level(r$coverage_reason, level)
  with_reason <- function(text) {
    if (is_string(reason) && !dodea) paste(text, reason) else text
  }
  label <- paste0(toupper(substr(level, 1, 1)), substring(level, 2))
  switch(status,
    not_available = if (dodea) {
      paste0("No ", level, " school zone: Department of Defense (DoDEA) schools serve this area.")
    } else {
      with_reason(paste0("No ", level, " school zone has been collected for this district yet."))
    },
    gap = with_reason(paste0("This point lies in no ", level, " school zone.")),
    served_by_other_district = {
      entries <- Filter(function(s) identical(s$zone_level, level),
                        r$served_elsewhere %||% list())
      reasons <- unlist(lapply(entries, function(s) s$reason))
      if (length(reasons)) {
        paste(reasons, collapse = " ")
      } else if (length(entries)) {
        paste0(label, " students here are served by district ",
               entries[[1]]$district_code, ".")
      } else {
        paste0(label, " students here are served by another district.")
      }
    },
    with_reason(paste0(label, " school zone status: ", status, "."))
  )
}

#' The part of a coverage reason about one level
#'
#' The API's reasons often hold one paragraph per level ("Elementary: ...
#' Middle: ..."); a level's row quotes only its own part, or the whole
#' reason when it has no per-level parts.
#' @noRd
reason_for_level <- function(reason, level) {
  if (!is_string(reason)) {
    return(reason)
  }
  label <- paste0(toupper(substr(zone_levels, 1, 1)), substring(zone_levels, 2))
  pattern <- paste0("(^|(?<=[.!?] ))(", paste(label, collapse = "|"), "): ")
  starts <- gregexpr(pattern, reason, perl = TRUE)[[1]]
  if (starts[1] == -1) {
    return(reason)
  }
  ends <- c(starts[-1] - 1, nchar(reason))
  parts <- trimws(substring(reason, starts, ends))
  heads <- tolower(sub(":.*$", "", parts))
  mine <- parts[heads == level]
  if (!length(mine)) {
    return(if (starts[1] > 1) trimws(substr(reason, 1, starts[1] - 1)) else NULL)
  }
  paste(mine, collapse = " ")
}

#' "K-5", "PK-5", "6-8", "9-12" (one grade: "K", "9")
#' @noRd
format_grades <- function(lo, hi) {
  label <- function(g) {
    out <- ifelse(g %in% c("pk", "k"), toupper(g),
                  as.character(suppressWarnings(as.integer(g))))
    out[is.na(g)] <- NA_character_
    out
  }
  lo_l <- label(lo)
  hi_l <- label(hi)
  out <- ifelse(lo_l == hi_l, lo_l, paste0(lo_l, "-", hi_l))
  out[is.na(lo_l) | is.na(hi_l)] <- NA_character_
  out
}

# Lookup tables: gcd_dimension() and the cached full tables the name
# resolver and gcd_locate() read.

#' Get the rows of a lookup table
#'
#' @description
#' Returns one of the platform's six lookup tables, the reference lists
#' every dataset's codes point to. They hold much more than names, and the
#' API never adds it to dataset rows:
#'
#' - `"districts"`: district name, former names, type, Census id, county,
#'   address, coordinates, active flag.
#' - `"schools"`: school name, former names, level, grade span, county,
#'   NCES id, address, phone, website, coordinates, locale (city, suburb,
#'   town, rural), charter and active flags.
#' - `"counties"`: the 159 county names (without "County").
#' - `"tracts"`: 2020 Census tracts with county, land area and population.
#' - `"block_groups"`: 2020 block groups with tract, county, land area,
#'   population, housing units and households.
#' - `"demographics"`: each demographic group's label and category.
#'
#' Use it to analyze results by locale, map schools, or browse what exists
#' ("every school in Fulton County"). Unfiltered tables are cached for the
#' R session.
#'
#' @section Joining schools:
#' School codes repeat across districts, so join on `district_code` **and**
#' `school_code` together:
#'
#' ```r
#' schools <- gcd_dimension("schools",
#'                          columns = c("district_code", "school_code", "locale"))
#' grad |>
#'   dplyr::left_join(schools, by = c("district_code", "school_code"))
#' ```
#'
#' @param name The lookup table: `"districts"`, `"schools"`, `"counties"`,
#'   `"tracts"`, `"block_groups"` or `"demographics"`.
#' @param ... Named filters on the table's key, enum and boolean columns,
#'   and `county_fips`, `district_code` or `tract_geoid` where the table has
#'   them. Each takes a vector (values are OR'd; filters are AND'd), for
#'   example `active = TRUE`, `district_type = "state_charter"` or
#'   `county_fips = "13121"`.
#' @param district,school,county Places by name, matched exactly against
#'   current and former names (ignoring case, accents and a trailing
#'   "County") and turned into codes. Character vectors; default `NULL`.
#'   Each applies only to tables with that code column.
#' @param q A single string: partial text search over the table's name
#'   columns, ignoring case and accents (`q = "eastside"`). Unlike the name
#'   arguments, it matches part of a name and returns every hit, so it is
#'   the tool for browsing. Default `NULL`.
#' @param columns A character vector of columns to return. Default `NULL`:
#'   all.
#' @param n_max The most rows to return. Default `Inf`: all.
#' @returns A tibble ordered by the table's primary key, one row per
#'   district, school, county, tract, block group or demographic group,
#'   typed from the table's schema: codes (`district_code`, `school_code`,
#'   `county_fips`, `tract_geoid`, `block_group_geoid`, `demographic`) and
#'   text columns are character, coordinates and areas double, counts and
#'   `directory_year` integer, `active` and `charter` logical. See
#'   [gcd_columns()] for each table's columns.
#' @family lookup tables
#' @seealso [gcd_columns()] for a table's column dictionary; [gcd_rows()],
#'   whose results carry these tables' names beside their codes.
#' @export
#' @examplesIf interactive()
#' gcd_dimension("counties")
#' gcd_dimension("schools", county = "Fulton", active = TRUE)
#' gcd_dimension("districts", district_type = "state_charter")
#' gcd_dimension("schools", q = "eastside",
#'               columns = c("district_code", "school_code", "school_name"))
gcd_dimension <- function(name, ..., district = NULL, school = NULL,
                          county = NULL, q = NULL, columns = NULL,
                          n_max = Inf) {
  check_name_arg(name)
  if (!is.null(q) && (!is_string(q) || !nzchar(q))) {
    cli::cli_abort("{.arg q} must be a single string.")
  }
  check_chr(columns)
  check_n_max(n_max)
  filters <- encode_filters(rlang::list2(...))
  schema <- lookup_schema(name)
  table_columns <- names(schema_types(schema))
  places <- resolve_places(
    district, school, county,
    filters = filters, columns = table_columns,
    target = paste0("the lookup table \"", name, "\"")
  )

  query <- filters
  query$district_code <- unique(c(query$district_code, places$district_code,
                                  places$schools$district_code))
  query$county_fips <- unique(c(query$county_fips, places$county_fips))
  query$school_code <- unique(c(query$school_code, places$schools$school_code))
  query$q <- q
  request_columns <- columns
  if (!is.null(columns) && !is.null(places$schools)) {
    request_columns <- union(columns, c("district_code", "school_code"))
  }
  query$columns <- request_columns
  query <- compact(query)

  if (!length(query)) {
    out <- lookup_table(name)
    return(if (is.finite(n_max)) utils::head(out, n_max) else out)
  }
  limit <- if (is.null(places$schools)) n_max else Inf
  out <- fetch_dimension_rows(name, query, n_max = limit, schema = schema)
  if (!is.null(places$schools)) {
    keep <- paste(out$district_code, out$school_code) %in%
      paste(places$schools$district_code, places$schools$school_code)
    out <- out[keep, , drop = FALSE]
    if (!is.null(columns)) {
      out <- out[intersect(columns, names(out))]
    }
    if (is.finite(n_max)) {
      out <- utils::head(out, n_max)
    }
  }
  out
}

#' Every row of a lookup table, typed, cached for the session
#' @noRd
lookup_table <- function(name, call = rlang::caller_env()) {
  cache_get_or_set(paste0("lookup:", name), {
    fetch_dimension_rows(name, list(), schema = lookup_schema(name, call = call),
                         call = call)
  })
}

#' Page through `GET /dimensions/{name}/rows`
#' @noRd
fetch_dimension_rows <- function(name, query, n_max = Inf, schema,
                                 call = rlang::caller_env()) {
  types <- schema_types(schema)
  pages <- list()
  got <- 0
  repeat {
    page_query <- query
    page_query$limit <- format_number(min(n_max - got, 10000))
    if (got > 0) {
      page_query$offset <- format_number(got)
    }
    req <- gcd_request(c("dimensions", path_segment(name), "rows"),
                       query = page_query)
    body <- resp_json(gcd_perform(req, call = call), simplify = TRUE)
    page <- data_frame_or_null(body$data)
    if (!is.null(page)) {
      pages[[length(pages) + 1]] <- apply_schema_types(page, types)
    }
    got <- got + NROW(page)
    if (!isTRUE(body$pagination$has_more) || got >= n_max || !NROW(page)) {
      break
    }
  }
  if (!length(pages)) {
    cols <- query$columns %||% names(types)
    return(empty_typed(cols, types))
  }
  tibble::as_tibble(do.call(rbind, pages))
}

#' A simplified JSON `data` array as a data frame (NULL when empty)
#' @noRd
data_frame_or_null <- function(data) {
  if (is.data.frame(data) && nrow(data)) {
    return(data)
  }
  NULL
}

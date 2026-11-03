#' Get rows of a dataset
#'
#' @description
#' The core function: the rows of one dataset at one detail level, as a
#' tibble typed from the dataset's schema, with place names beside their
#' codes.
#'
#' **It returns every category and group the filters don't exclude.**
#' Nothing is pinned by default: no single demographic group, no single
#' subject. A call with only a dataset name returns the whole dataset at
#' its default detail level.
#'
#' @section Filters:
#' Give filters as named arguments in `...`; each value is a vector.
#' Values within one filter are OR'd; different filters are AND'd.
#' Accepted names:
#' - any categorical column: `subject = "mathematics"`,
#'   `demographic = c("all", "black")`;
#' - geography codes: `district_code`, `school_code`, `county_fips`,
#'   `tract_geoid`, `block_group_geoid`;
#' - `school_id`: schools as `"DISTRICT-SCHOOL"` codes
#'   (`school_id = c("761-0199", "660-0104")`), the form [gcd_locate()]
#'   returns (a school code alone is not unique across districts);
#' - lookup-table attributes: `district_type = "state_charter"`,
#'   `school_level = "high"`, `locale = "rural"`,
#'   `demographic_category = "race"`;
#' - metric bounds: `graduation_rate_min = 0.9`, `num_cohort_max = 50`
#'   (inclusive, in stored units).
#'
#' `NA` in a filter selects rows where a nullable column is empty;
#' logicals become `true` / `false`. The API validates every filter and
#' its errors name what went wrong; [gcd_describe()] lists each dataset's
#' filters and their values.
#'
#' @section Labels:
#' With `labels = TRUE` (the default) the rows carry the API's joined name
#' columns, each right after its code: `district_name`,
#' `district_census_id` and `district_type` after `district_code`;
#' `school_name` after `school_code`; `county_name`, `tract_name` and
#' `block_group_name` after their codes; `demographic_label` and
#' `demographic_category` after `demographic`. Codes are always kept:
#' school names repeat across districts, names change over time, and joins
#' run on codes.
#'
#' - Categorical values (`subject`, `grade_cluster`) are readable
#'   snake_case codes already; there are no separate labels for them.
#' - `demographic_category` (race, gender, economic_status, ...) is a
#'   grouping that arrives with the labels; filtering by it works either
#'   way.
#' - Other lookup-table attributes (school addresses, locale, coordinates)
#'   are not joined; get them from [gcd_dimension()] and join.
#'
#' `labels = FALSE` asks for the dataset's own columns only, for large
#' pulls. Either way, code columns that would be empty on every row (a
#' district row's `school_code`, a state row's geography codes) are left
#' out, so both settings give the same shape.
#'
#' @section Missing values and totals:
#' `NA` in a metric usually means the value was **suppressed** to protect
#' privacy (small counts), **not zero**; the schema's `null_semantics` says
#' which ([gcd_describe()]). Because nothing is pinned, results hold the
#' `all` totals beside the subgroups: never add a total to its subgroups.
#' The API's advisories say so when they apply, and print once per call as
#' messages (`quiet = TRUE` or `options(gcd.quiet = TRUE)` silences them;
#' they stay in `gcd_meta(x)$advisories`).
#'
#' Rates must be pooled from their counts, never averaged:
#' `sum(num_graduates) / sum(num_cohort)`, not `mean(graduation_rate)`.
#' [gcd_columns()] shows each metric's numerator and denominator.
#'
#' @section Large downloads and the disk cache:
#' Up to 10,000 rows come back as one JSON page. A larger result is
#' downloaded in full as CSV in one response (with a progress bar); the
#' metadata and advisories then come from the first JSON page and describe
#' its first 10,000 rows.
#'
#' With `cache = TRUE` (or `options(gcd.cache = TRUE)`), responses are kept
#' in `tools::R_user_dir("georgiacivicdata", "cache")` with their `ETag`.
#' Repeating a request asks the server whether the data changed: an
#' unchanged answer reuses the saved copy without downloading, and a new
#' data release downloads afresh. A response the server marks fresh (for
#' five minutes) is reused without asking. Clear it with
#' [gcd_cache_clear()].
#'
#' @section Data license:
#' The data is CC BY 4.0: credit Georgia Civic Data and the original
#' source, as [gcd_citation()] writes.
#'
#' @param name The dataset's name, such as
#'   `"graduation_rate_4_year_cohort"` (see [gcd_datasets()] and
#'   [gcd_search()]).
#' @param ... Named filters (see "Filters"). Unnamed arguments are an
#'   error.
#' @param year Years to keep, an integer vector. A run of consecutive years
#'   (`2019:2024`) is sent as a range; anything else (`c(2019, 2024)`) as
#'   exact years. Default `NULL`: all years.
#' @param detail The one level the rows describe, such as `"schools"`,
#'   `"districts"`, `"states"`, `"counties"` or `"tracts"`. Default `NULL`:
#'   the dataset's default (the finest level, except Census datasets, which
#'   default to counties). To combine levels, call once per level and bind
#'   the rows.
#' @param district,school,county Places by name, such as
#'   `district = "Fulton County"`, `school = "Roswell High School"`,
#'   `county = c("Fulton", "DeKalb")`. Matched exactly against current and
#'   former names (ignoring case, accents and a trailing "County"); an
#'   unknown or ambiguous name is an error that lists suggestions or
#'   candidates. A school name found in more than one district needs
#'   `district` too. For any one place, give its code or its name, not
#'   both. Default `NULL`.
#' @param labels `TRUE` (default) adds place names beside codes; `FALSE`
#'   returns codes only (see "Labels").
#' @param columns A character vector to return only some columns. Default
#'   `NULL`: all.
#' @param sort A character vector of columns to sort by on the server;
#'   prefix `-` for descending (`"-graduation_rate"`). Missing values sort
#'   last. Mostly useful with `n_max` for a top N. Default `NULL`: the
#'   dataset's own order (its grain).
#' @param n_max The most rows to return. Default `Inf`: all.
#' @param cache `TRUE` to use the disk cache (see "Large downloads and the
#'   disk cache"). Default `getOption("gcd.cache", FALSE)`.
#' @param quiet `TRUE` to silence the advisory messages. Default `FALSE`.
#' @returns A tibble of rows at one detail level, typed from the schema:
#'   codes and names character (leading zeros kept), `year` integer,
#'   counts integer, rates and proportions double (proportions on the 0-1
#'   scale), booleans logical. Columns come in grain order: `year`, each
#'   geography code followed by its names, `demographic` and its labels,
#'   other categorical columns, then metrics. [gcd_columns()] describes
#'   each column. The tibble carries a `gcd_meta` attribute (see
#'   [gcd_meta()]): dataset, title, detail, key metric, units,
#'   `null_semantics`, source, citation, license, advisories, data version,
#'   `updated_at` and the request URL.
#' @family get data
#' @seealso [gcd_values()] to see which category values exist under a
#'   filter; [gcd_describe()] and [gcd_columns()] to understand a dataset;
#'   [gcd_citation()] to cite it.
#' @export
#' @examplesIf interactive()
#' # Names and codes (the default), one district by name
#' grad <- gcd_rows(
#'   "graduation_rate_4_year_cohort",
#'   district = "Fulton County",
#'   demographic = c("all", "black", "hispanic"),
#'   year = 2020:2024
#' )
#'
#' # One school, by name within its district
#' gcd_rows("graduation_rate_4_year_cohort",
#'          district = "Fulton County", school = "Roswell High School",
#'          demographic = "all")
#'
#' # Statewide schools, one subject, codes only
#' gcd_rows("ccrpi_content_mastery", year = 2025, detail = "schools",
#'          grade_cluster = "high", subject = "mathematics", labels = FALSE)
#'
#' # Top 10 counties by unemployment
#' gcd_rows("employment", year = 2024, sort = "-unemployment_rate",
#'          n_max = 10)
gcd_rows <- function(name, ..., year = NULL, detail = NULL, district = NULL,
                     school = NULL, county = NULL, labels = TRUE,
                     columns = NULL, sort = NULL, n_max = Inf,
                     cache = getOption("gcd.cache", FALSE), quiet = FALSE) {
  check_name_arg(name)
  check_flag(labels)
  check_flag(cache)
  check_flag(quiet)
  check_n_max(n_max)
  check_query_args(detail, columns, sort)
  filters <- encode_filters(rlang::list2(...))
  years <- encode_years(year)
  schema <- table_schema(name, "gcd_rows")
  own_columns <- names(schema_types(schema))
  places <- resolve_places(
    district, school, county,
    filters = filters, columns = own_columns,
    target = paste0("the dataset \"", name, "\"")
  )
  request_columns <- columns %||% if (!labels) own_columns
  query <- dataset_query(filters, years, detail, places, request_columns, sort)

  fetched <- fetch_rows(name, query, n_max = n_max, cache = cache,
                        quiet = is_quiet(quiet))
  out <- shape_rows(fetched$data, schema, labels = labels, columns = columns,
                    omitted = fetched$meta$omitted_columns)
  meta <- rows_meta(fetched$meta, fetched$url)
  attr(out, "gcd_meta") <- meta
  if (!is_quiet(quiet)) {
    show_advisories(meta$advisories)
  }
  out
}

#' Fetch rows: one JSON page, or the whole result as CSV when it is larger
#' @noRd
fetch_rows <- function(name, query, n_max = Inf, cache = FALSE, quiet = FALSE,
                       call = rlang::caller_env()) {
  limit <- min(n_max, 10000)
  page_query <- c(query, list(limit = format_number(limit)))
  req <- dataset_request(name, "rows", page_query, cache = cache)
  url <- gcd_request(c("datasets", path_segment(name), "rows"),
                     query = page_query)$url
  body <- resp_json(gcd_perform(req, call = call), simplify = TRUE)
  out <- list(data = body$data, meta = body$meta, url = url)
  if (!isTRUE(body$pagination$has_more) || n_max <= limit) {
    return(out)
  }
  total <- body$pagination$total
  if (!quiet) {
    n <- if (is.finite(n_max)) min(total, n_max) else total
    total_txt <- format(total, big.mark = ",")
    n_txt <- format(n, big.mark = ",")
    if (n < total) {
      cli::cli_inform(c(i = "Downloading {total_txt} rows as CSV (keeping the first {n_txt})."))
    } else {
      cli::cli_inform(c(i = "Downloading {total_txt} rows as CSV."))
    }
  }
  csv_req <- dataset_request(name, "rows", c(query, list(format = "csv")),
                             timeout = 900, cache = cache)
  csv_req <- httr2::req_progress(csv_req, type = "down")
  out$data <- download_csv(csv_req, call = call)
  if (is.finite(n_max)) {
    out$data <- utils::head(out$data, n_max)
  }
  out
}

#' Stream a CSV response to a temporary file and read every column as text
#' @noRd
download_csv <- function(req, call = rlang::caller_env()) {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  resp <- gcd_perform(req, path = path, call = call)
  if (!file.exists(path)) {
    writeBin(httr2::resp_body_raw(resp), path)
  }
  readr::read_csv(
    path,
    col_types = readr::cols(.default = readr::col_character()),
    na = "",
    progress = FALSE,
    show_col_types = FALSE
  )
}

#' Type, order and trim the rows
#' @noRd
shape_rows <- function(data, schema, labels = TRUE, columns = NULL,
                       omitted = NULL) {
  types <- row_types(schema)
  if (is.data.frame(data) && nrow(data)) {
    df <- tibble::as_tibble(data)
  } else {
    expected <- columns %||% if (labels) names(types) else names(schema_types(schema))
    df <- empty_typed(setdiff(expected, unlist(omitted)), types)
  }
  df <- apply_schema_types(df, types)
  df <- relocate_labels(df, schema$foreign_keys)
  if (!labels && is.null(columns)) {
    df <- drop_empty_codes(df, code_columns(schema))
  }
  df
}

#' The `gcd_meta` attribute: the response's `meta` without its internal
#' key, plus the request URL
#' @noRd
rows_meta <- function(meta, url) {
  meta <- drop_internal(meta %||% list())
  advisories <- meta$advisories
  meta$advisories <- if (is.data.frame(advisories) && nrow(advisories)) {
    tibble::as_tibble(advisories)
  } else {
    tibble::tibble(code = character(), message = character())
  }
  meta$request_url <- url
  meta
}

#' Print each advisory once, as the API words it
#' @noRd
show_advisories <- function(advisories) {
  for (msg in advisories$message) {
    cli::cli_inform(c(i = "{msg}"))
  }
  invisible()
}

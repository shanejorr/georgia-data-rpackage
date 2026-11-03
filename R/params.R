# Building query parameters: years, list filters, NA and logical encoding,
# school ids, and the switch to POST for very long filter lists.

#' The token the API reads as "this column is NULL"
#' @noRd
null_token <- "__null__"

#' URLs longer than this go as `POST /datasets/{name}/query`
#' @noRd
max_url_chars <- 6000

#' Parameters the fetch strategy owns; refused in `...`
#' @noRd
reserved_params <- c("limit", "offset", "format", "fields", "verbosity", "source")

#' Encode one filter vector as the API's text values
#'
#' `NA` becomes `__null__`, logicals `true` / `false`, numbers plain
#' decimal text (never scientific notation), dates ISO 8601.
#' @noRd
encode_values <- function(x, arg, call = rlang::caller_env()) {
  if (is.factor(x)) {
    x <- as.character(x)
  }
  if (inherits(x, "Date")) {
    out <- format(x, "%Y-%m-%d")
  } else if (is.logical(x)) {
    out <- ifelse(x, "true", "false")
  } else if (is.numeric(x)) {
    out <- vapply(x, format_number, character(1))
  } else if (is.character(x)) {
    out <- x
  } else {
    cli::cli_abort(
      "Filter {.arg {arg}} must be a character, numeric, logical or Date vector, not {.obj_type_friendly {x}}.",
      call = call
    )
  }
  out[is.na(x)] <- null_token
  out
}

#' A number as plain decimal text
#' @noRd
format_number <- function(x) {
  if (is.na(x)) {
    return(NA_character_)
  }
  if (x == trunc(x) && abs(x) < 1e15) {
    return(format(x, scientific = FALSE, trim = TRUE, nsmall = 0))
  }
  out <- formatC(x, digits = 15, format = "f", drop0trailing = TRUE)
  sub("\\.$", "", out)
}

#' Encode the `year` argument
#'
#' One year, or a run of consecutive years, becomes `year` / `year_min` +
#' `year_max`; anything else an exact list.
#' @noRd
encode_years <- function(year, call = rlang::caller_env()) {
  if (is.null(year)) {
    return(list())
  }
  if (!is.numeric(year) || !length(year) || anyNA(year) ||
      any(year != trunc(year))) {
    cli::cli_abort("{.arg year} must be a vector of whole years, such as {.code 2024} or {.code 2019:2024}.",
                   call = call)
  }
  year <- sort(unique(as.integer(year)))
  if (length(year) == 1) {
    return(list(year = as.character(year)))
  }
  if (all(diff(year) == 1L)) {
    return(list(year_min = as.character(min(year)),
                year_max = as.character(max(year))))
  }
  list(year = as.character(year))
}

#' Encode the named filters given in `...`
#'
#' Unnamed arguments are an error; `NULL` filters are dropped; `school_id`
#' becomes the API's `school` pair filter.
#' @noRd
encode_filters <- function(dots, call = rlang::caller_env()) {
  if (!length(dots)) {
    return(list())
  }
  nms <- names(dots) %||% rep("", length(dots))
  if (any(!nzchar(nms))) {
    cli::cli_abort(
      c("Every filter in {.arg ...} must be named.",
        i = "For example {.code subject = \"mathematics\"} or {.code district_code = \"660\"}."),
      call = call
    )
  }
  if (anyDuplicated(nms)) {
    dup <- unique(nms[duplicated(nms)])
    cli::cli_abort("Filter {.arg {dup}} is given more than once.", call = call)
  }
  bad <- intersect(nms, reserved_params)
  if (length(bad)) {
    cli::cli_abort(
      c("{.arg {bad}} can't be given as a filter.",
        i = "The package chooses the page size and format; use {.arg n_max} to cap rows."),
      call = call
    )
  }
  if ("school" %in% nms) {
    cli::cli_abort(
      c("Use {.arg school_id} for schools as {.str DISTRICT-SCHOOL} codes.",
        i = "{.arg school} takes school names."),
      call = call
    )
  }
  dots <- compact(dots)
  out <- list()
  for (nm in names(dots)) {
    x <- dots[[nm]]
    if (!length(x)) {
      cli::cli_abort("Filter {.arg {nm}} is empty; give at least one value or leave it out.",
                     call = call)
    }
    if (is.list(x)) {
      cli::cli_abort("Filter {.arg {nm}} must be a vector, not a list.", call = call)
    }
    param <- if (nm == "school_id") "school" else nm
    out[[param]] <- unique(encode_values(x, arg = nm, call = call))
  }
  out
}

#' Combine the query for a dataset route (rows, values)
#'
#' @param filters Encoded filters from `encode_filters()`.
#' @param places Resolved places from `resolve_places()`.
#' @noRd
dataset_query <- function(filters, years, detail, places, columns = NULL,
                          sort = NULL) {
  query <- c(years, list(detail = detail), filters)
  if (length(places$district_code)) {
    query$district_code <- unique(c(query$district_code, places$district_code))
  }
  if (length(places$county_fips)) {
    query$county_fips <- unique(c(query$county_fips, places$county_fips))
  }
  if (length(places$school_pairs)) {
    query$school <- unique(c(query$school, places$school_pairs))
  }
  query$columns <- columns
  query$sort <- sort
  compact(query)
}

#' A request for a dataset route, switching to `POST /query` when the
#' URL would be too long
#'
#' Only the rows route has a POST twin; other routes stay GET.
#' @noRd
dataset_request <- function(name, route, query, timeout = 60, cache = FALSE) {
  req <- gcd_request(c("datasets", path_segment(name), route), query = query,
                     timeout = timeout, cache = cache)
  if (route == "rows" && nchar(req$url) > max_url_chars) {
    req <- gcd_request(c("datasets", path_segment(name), "query"),
                       timeout = timeout)
    req <- httr2::req_body_json(req, lapply(query, as.list), auto_unbox = TRUE)
  }
  req
}

#' Check the `detail`, `columns` and `sort` arguments
#' @noRd
check_query_args <- function(detail, columns, sort, call = rlang::caller_env()) {
  if (!is.null(detail) && (!is_string(detail) || !nzchar(detail))) {
    cli::cli_abort(
      c("{.arg detail} must be one detail level, such as {.str districts}.",
        i = "To combine levels, call once per level and bind the rows."),
      call = call
    )
  }
  check_chr(columns, arg = "columns", call = call)
  check_chr(sort, arg = "sort", call = call)
}

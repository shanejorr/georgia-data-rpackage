#' List the datasets in the catalog
#'
#' @description
#' The catalog of everything the API publishes, one row per dataset. With
#' no arguments it returns **every dataset**: all subject areas, detail
#' levels and years, tables and geometry alike. Each argument only narrows
#' the list (the filtering runs on the server). About 176 datasets: small
#' enough to `View()` or filter with dplyr.
#'
#' The six lookup tables (districts, schools, counties, tracts, block
#' groups, demographics) are not datasets and are not listed; see
#' [gcd_dimension()].
#'
#' @param main_topic A single subject area: `"education"`, `"census"`,
#'   `"health"` or `"immigration"`. Default `NULL`: all.
#' @param level Keep datasets that publish rows at this detail level, such
#'   as `"schools"`, `"districts"`, `"counties"` or `"tracts"`. Default
#'   `NULL`: all.
#' @param year Keep datasets that cover this year (a single number).
#'   Default `NULL`: all.
#' @param kind `"table"` or `"geometry"`. Default `NULL`: both.
#' @param details `FALSE` (default) gives the compact catalog. `TRUE` adds
#'   the long columns (description, source, grain and more).
#' @returns A tibble, one row per dataset, with columns:
#'   - `name`: the dataset's name, used by every other function.
#'   - `title`, `summary`: what it holds.
#'   - `kind`: `"table"` or `"geometry"`.
#'   - `main_topic`: the subject area.
#'   - `detail_levels`: list-column of the levels it publishes.
#'   - `year_min`, `year_max`: integer, the years covered.
#'
#'   With `details = TRUE`, also: `description`, `source`, `source_url`,
#'   `grain` (list-column: the columns that identify a row),
#'   `default_detail`, `year_gaps` (list-column of missing years),
#'   `update_frequency`, `search_aliases_en` and `search_aliases_es`
#'   (list-columns of everyday search phrases), and `updated_at` (POSIXct,
#'   UTC). Geometry datasets have `NA` where a field doesn't apply.
#' @family find data
#' @seealso [gcd_search()] to rank datasets by plain words;
#'   [gcd_describe()] for one dataset.
#' @export
#' @examplesIf interactive()
#' gcd_datasets()
#' gcd_datasets(main_topic = "education", level = "schools")
#' gcd_datasets(kind = "geometry", details = TRUE)
gcd_datasets <- function(main_topic = NULL, level = NULL, year = NULL,
                         kind = NULL, details = FALSE) {
  check_catalog_filters(main_topic, level, year)
  if (!is.null(kind)) {
    kind <- rlang::arg_match(kind, c("table", "geometry"))
  }
  check_flag(details)
  query <- list(
    main_topic = main_topic,
    level = level,
    year = if (!is.null(year)) format_number(year),
    kind = kind,
    fields = if (details) "full"
  )
  catalog <- gcd_get_meta("datasets", query = query)
  catalog_tibble(catalog$data, details = details)
}

#' The catalog's records as the documented tibble
#' @noRd
catalog_tibble <- function(records, details = FALSE) {
  records <- lapply(records, drop_internal)
  for (i in seq_along(records)) {
    aliases <- records[[i]]$search_aliases
    records[[i]]$search_aliases_en <- aliases$en %||% list()
    records[[i]]$search_aliases_es <- aliases$es %||% list()
  }
  compact_fields <- c("name", "title", "summary", "kind", "main_topic",
                      "detail_levels", "year_min", "year_max")
  full_fields <- c("description", "source", "source_url", "grain",
                   "default_detail", "year_gaps", "update_frequency",
                   "search_aliases_en", "search_aliases_es", "updated_at")
  list_cols <- c("detail_levels", "grain", "year_gaps", "search_aliases_en",
                 "search_aliases_es")
  fields <- c(compact_fields, if (details) full_fields)
  out <- records_to_tibble(records, fields = fields, list_cols = list_cols)
  types <- c(name = "string", title = "string", summary = "string",
             kind = "string", main_topic = "string", year_min = "integer",
             year_max = "integer", description = "string", source = "string",
             source_url = "string", default_detail = "string",
             update_frequency = "string", updated_at = "timestamp")
  out <- apply_schema_types(out, types)
  if ("year_gaps" %in% names(out)) {
    out$year_gaps <- lapply(out$year_gaps, function(x) as.integer(unlist(x)))
  }
  out
}

#' Check the catalog and search filters
#' @noRd
check_catalog_filters <- function(main_topic, level, year,
                                  call = rlang::caller_env()) {
  if (!is.null(main_topic) && !is_string(main_topic)) {
    cli::cli_abort("{.arg main_topic} must be a single string, such as {.str education}.",
                   call = call)
  }
  if (!is.null(level) && !is_string(level)) {
    cli::cli_abort("{.arg level} must be a single string, such as {.str schools}.",
                   call = call)
  }
  if (!is.null(year) && (!is.numeric(year) || length(year) != 1 ||
                         is.na(year) || year != trunc(year))) {
    cli::cli_abort("{.arg year} must be a single year, such as {.code 2024}.",
                   call = call)
  }
}

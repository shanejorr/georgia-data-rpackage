#' List the category combinations a filter covers
#'
#' @description
#' Which combinations of category values exist, and how many rows each
#' has, under the same filters as [gcd_rows()]. It answers "which subjects
#' exist in 2016 at district level?" or "which demographic groups does this
#' county have rows for?" without downloading the rows. The schema's
#' `valid_values` list every value a column has ever used; `gcd_values()`
#' lists what exists **for this filter**, which is what you need when a
#' filter returns zero rows.
#'
#' The API returns at most 500 combinations; the function warns when that
#' cap is reached.
#'
#' @inheritParams gcd_rows
#' @param columns One or more categorical columns (or `"demographic"`),
#'   such as `"subject"` or `c("subject", "grade_cluster")`.
#' @param ... Named filters, exactly as in [gcd_rows()].
#' @returns A tibble, most rows first, with one column per requested
#'   column (typed from the schema; `NA` where the column is empty for
#'   those rows) and `n_rows` (integer), the number of rows with that
#'   combination.
#' @family get data
#' @seealso [gcd_rows()] for the rows themselves; [gcd_describe()] for
#'   every filter and its allowed values.
#' @export
#' @examplesIf interactive()
#' gcd_values("ccrpi_content_mastery", "subject", year = 2016,
#'            detail = "districts")
#' gcd_values("graduation_rate_4_year_cohort", "demographic",
#'            district = "Fulton County", year = 2024)
gcd_values <- function(name, columns, ..., year = NULL, detail = NULL,
                       district = NULL, school = NULL, county = NULL) {
  check_name_arg(name)
  check_chr(columns, allow_null = FALSE)
  check_query_args(detail, NULL, NULL)
  filters <- encode_filters(rlang::list2(...))
  years <- encode_years(year)
  schema <- table_schema(name, "gcd_values")
  places <- resolve_places(
    district, school, county,
    filters = filters, columns = names(schema_types(schema)),
    target = paste0("the dataset \"", name, "\"")
  )
  query <- dataset_query(filters, years, detail, places, columns = columns)
  body <- gcd_get_json(c("datasets", path_segment(name), "values"),
                       query = query)
  fields <- c(as.character(unlist(body$columns %||% columns)), "count")
  out <- records_to_tibble(body$data, fields = fields)
  types <- row_types(schema)
  out <- apply_schema_types(out, c(types[intersect(names(types), fields)],
                                   count = "integer"))
  names(out)[names(out) == "count"] <- "n_rows"
  if (isTRUE(body$truncated)) {
    total <- body$total_combinations
    cli::cli_warn(c(
      "Only the {nrow(out)} most common combinations are shown (the API returns at most 500{if (!is.null(total)) paste0(' of ', total) else ''}).",
      i = "Add filters to narrow them."
    ))
  }
  out
}

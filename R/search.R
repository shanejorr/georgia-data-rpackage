#' Search the catalog
#'
#' @description
#' Ranked dataset search from plain words, in English or Spanish ("jobless
#' rate", "kids missing school", "desempleo"). Use it when you know what
#' you are looking for but not what the dataset is called.
#'
#' Search is hybrid: keyword matching plus matching by meaning. The query
#' text is sent to the Georgia Civic Data API, which embeds it with Voyage
#' AI for the meaning half and never logs it. This is the one function
#' whose results can't be reproduced by filtering [gcd_datasets()] locally,
#' and the ranking can change between releases of the platform.
#'
#' @param query Plain words, a single string.
#' @param main_topic,level,year The same filters as [gcd_datasets()]: a
#'   subject area, a detail level and a year. Default `NULL`: no filter.
#' @param n The number of matches to return, 1 to 100. Default 20.
#' @returns A tibble, one row per match, best first, with columns:
#'   - `rank`: integer, 1 is the best match.
#'   - `name`, `title`, `summary`, `main_topic`: the dataset.
#'   - `detail_levels`: list-column of the levels it publishes.
#'   - `year_min`, `year_max`: integer, the years covered.
#'   - `score`: double, the match score.
#'   - `matched_on`: list-column of what matched (aliases, columns,
#'     summary, ...).
#'   - `matched_columns`: list-column of the dataset's columns that matched.
#'
#'   Attributes `confidence` (`"high"`, `"medium"` or `"low"`),
#'   `retrieval` (a list: `mode` and `reranked`) and `total_matches`
#'   describe the search. On low confidence the function says that nothing
#'   in the catalog may fit; it also names any lookup tables that matched.
#' @family find data
#' @seealso [gcd_datasets()] for the full catalog; [gcd_describe()] and
#'   [gcd_columns()] to understand a match.
#' @export
#' @examplesIf interactive()
#' gcd_search("high school graduation")
#' gcd_search("desempleo", n = 5)
#' gcd_search("chronic absence", level = "districts")
gcd_search <- function(query, main_topic = NULL, level = NULL, year = NULL,
                       n = 20) {
  if (!is_string(query) || !nzchar(trimws(query))) {
    cli::cli_abort("{.arg query} must be a single, non-empty string.")
  }
  check_catalog_filters(main_topic, level, year)
  if (!is.numeric(n) || length(n) != 1 || is.na(n) || n < 1 || n > 100 ||
      n != trunc(n)) {
    cli::cli_abort("{.arg n} must be a whole number from 1 to 100.")
  }
  body <- gcd_get_json("search", query = list(
    q = query,
    limit = format_number(n),
    main_topic = main_topic,
    level = level,
    year = if (!is.null(year)) format_number(year)
  ))
  out <- search_tibble(body$matches)
  attr(out, "confidence") <- body$confidence
  attr(out, "retrieval") <- body$retrieval
  attr(out, "total_matches") <- body$total_matches
  search_messages(body)
  out
}

#' The search matches as the documented tibble
#' @noRd
search_tibble <- function(matches) {
  fields <- c("name", "title", "summary", "main_topic", "detail_levels",
              "year_min", "year_max", "score", "matched_on", "matched_columns")
  out <- records_to_tibble(
    lapply(matches, drop_internal),
    fields = fields,
    list_cols = c("detail_levels", "matched_on", "matched_columns")
  )
  out <- apply_schema_types(out, c(
    name = "string", title = "string", summary = "string",
    main_topic = "string", year_min = "integer", year_max = "integer",
    score = "number"
  ))
  tibble::add_column(out, rank = seq_len(nrow(out)), .before = 1)
}

#' Confidence, retrieval and lookup-table hints
#' @noRd
search_messages <- function(body) {
  if (is_quiet()) {
    return(invisible())
  }
  if (identical(body$confidence, "low")) {
    cli::cli_inform(c("!" = "Nothing in the catalog may fit this query."))
  }
  mode <- body$retrieval$mode
  if (is_string(mode) && mode != "hybrid") {
    cli::cli_inform(c(
      i = "Search fell back to keywords only, so matches by meaning are missing."
    ))
  }
  tables <- unlist(lapply(body$dimension_matches, function(d) {
    if (length(d$matched_on)) d$name
  }))
  if (length(tables)) {
    cli::cli_inform(c(
      i = "Lookup tables that match: {.val {tables}}. See {.fn gcd_dimension}."
    ))
  }
  invisible()
}

# Schemas: fetching them, typing data frames from them, and placing the
# joined label columns.

#' Fields internal to the platform, dropped from everything the package
#' returns (`gcd_contract()` alone returns the contract verbatim)
#' @noRd
internal_fields <- c("sub_topic", "topic", "key")

#' Drop the internal fields from a named list (or each of a list of lists)
#' @noRd
drop_internal <- function(x) {
  if (is.list(x) && !is.null(names(x))) {
    x[intersect(names(x), internal_fields)] <- NULL
  }
  x
}

#' The names of the lookup tables (cached `GET /dimensions`)
#' @noRd
lookup_table_names <- function(call = rlang::caller_env()) {
  listing <- gcd_get_meta("dimensions", call = call)
  vapply(listing$data, function(d) d$name, character(1))
}

#' What kind of resource a name is: "table", "geometry" or "lookup"
#'
#' Lookup tables are recognized from the cached list of lookup tables;
#' anything else is asked of `GET /datasets/{name}` (an unknown name gives
#' the API's own `TOPIC_NOT_FOUND` error, with suggestions).
#' @noRd
resource_kind <- function(name, call = rlang::caller_env()) {
  if (name %in% lookup_table_names(call = call)) {
    return("lookup")
  }
  dataset_schema(name, call = call)$kind %||% "table"
}

#' The schema of a dataset or geometry dataset (cached)
#' @noRd
dataset_schema <- function(name, call = rlang::caller_env()) {
  gcd_get_meta(c("datasets", path_segment(name)), call = call)
}

#' The schema of a lookup table (cached)
#' @noRd
lookup_schema <- function(name, call = rlang::caller_env()) {
  gcd_get_meta(c("dimensions", path_segment(name)), call = call)
}

#' A dataset's schema, refusing geometry datasets and lookup tables with a
#' pointer to the right function
#' @noRd
table_schema <- function(name, fn, call = rlang::caller_env()) {
  check_name_arg(name, arg = "name", call = call)
  if (name %in% lookup_table_names(call = call)) {
    abort_gcd(
      c("{.val {name}} is a lookup table, not a dataset.",
        i = "Use {.code gcd_dimension({.str {name}})} to get its rows."),
      code = "not_a_dataset", call = call
    )
  }
  schema <- dataset_schema(name, call = call)
  if (identical(schema$kind, "geometry")) {
    fun <- if (name == "school_district_boundaries") {
      "gcd_district_boundaries()"
    } else {
      "gcd_school_zones()"
    }
    abort_gcd(
      c("{.val {name}} is a geometry dataset, which {.fn {fn}} doesn't read.",
        i = "Use {.code {fun}} instead."),
      code = "not_a_dataset", call = call
    )
  }
  schema
}

#' Column types (column -> API type) from a schema's columns or fields
#' @noRd
schema_types <- function(schema) {
  cols <- schema$columns %||% schema$fields %||% list()
  types <- vapply(cols, function(c) c$type %||% "string", character(1))
  names(types) <- vapply(cols, function(c) c$name, character(1))
  types
}

#' The joined label columns a dataset's rows carry (all character)
#' @noRd
label_columns <- function(schema) {
  unique(unlist(lapply(schema$foreign_keys, function(fk) {
    unlist(fk$attribute_columns_added)
  })))
}

#' The full set of column types for a dataset's rows, joined labels included
#' @noRd
row_types <- function(schema) {
  types <- schema_types(schema)
  labels <- setdiff(label_columns(schema), names(types))
  c(types, stats::setNames(rep("string", length(labels)), labels))
}

#' Type a data frame's columns from the schema
#'
#' The one typing function for every result, whether it was parsed from
#' JSON or read from CSV as character. `types` maps column names to API
#' types: `string` (character; codes keep their leading zeros), `integer`
#' (integer, or double when a value exceeds `.Machine$integer.max`),
#' `number` (double), `boolean` (logical), `date` (Date) and
#' `timestamp` / `datetime` (POSIXct, UTC). Columns the schema does not
#' name are left as they are, except all-`NA` logical ones, which become
#' character.
#' @noRd
apply_schema_types <- function(df, types) {
  for (col in names(df)) {
    if (is.list(df[[col]])) {
      next
    }
    type <- if (col %in% names(types)) types[[col]] else NA_character_
    df[[col]] <- convert_type(df[[col]], type)
  }
  df
}

#' Convert one column to an API type
#' @noRd
convert_type <- function(x, type) {
  if (is.na(type)) {
    if (is.logical(x) && all(is.na(x))) {
      return(as.character(x))
    }
    return(x)
  }
  switch(type,
    string = as.character(x),
    integer = as_integer_safe(x),
    number = as_number(x),
    boolean = as_logical_value(x),
    date = as.Date(as.character(x)),
    timestamp = ,
    datetime = parse_utc(x),
    x
  )
}

#' @noRd
as_number <- function(x) {
  if (is.character(x)) {
    x <- suppressWarnings(as.numeric(x))
  }
  as.double(x)
}

#' Integers that stay integer unless a value is out of R's integer range
#' @noRd
as_integer_safe <- function(x) {
  x <- as_number(x)
  ok <- x[!is.na(x)]
  if (length(ok) && (any(abs(ok) > .Machine$integer.max) || any(ok != trunc(ok)))) {
    return(x)
  }
  as.integer(x)
}

#' @noRd
as_logical_value <- function(x) {
  if (is.logical(x)) {
    return(x)
  }
  if (is.numeric(x)) {
    return(x != 0)
  }
  x <- tolower(as.character(x))
  out <- rep(NA, length(x))
  out[x %in% c("true", "t", "1")] <- TRUE
  out[x %in% c("false", "f", "0")] <- FALSE
  out
}

#' Place each foreign key's joined label columns right after its code
#'
#' Driven by the schema's `foreign_keys[].attribute_columns_added`, so no
#' list of label columns is hardcoded.
#' @noRd
relocate_labels <- function(df, foreign_keys) {
  for (fk in foreign_keys) {
    df <- move_after(df, unlist(fk$attribute_columns_added), fk$column)
  }
  df
}

#' The code columns of a dataset (foreign keys to the lookup tables)
#' @noRd
code_columns <- function(schema) {
  cols <- schema$columns %||% list()
  roles <- vapply(cols, function(c) c$role %||% "", character(1))
  names <- vapply(cols, function(c) c$name, character(1))
  names[startsWith(roles, "fk_")]
}

#' Drop code columns that are `NA` on every row (kept when there are no rows)
#' @noRd
drop_empty_codes <- function(df, codes) {
  if (!nrow(df)) {
    return(df)
  }
  empty <- vapply(intersect(codes, names(df)), function(col) {
    all(is.na(df[[col]]))
  }, logical(1))
  df[setdiff(names(df), names(empty)[empty])]
}

#' An empty tibble with the given columns, typed
#' @noRd
empty_typed <- function(columns, types) {
  df <- tibble::as_tibble(stats::setNames(
    rep(list(character()), length(columns)),
    columns
  ))
  apply_schema_types(df, types)
}

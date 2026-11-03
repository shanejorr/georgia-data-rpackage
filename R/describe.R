#' Describe a dataset or lookup table
#'
#' @description
#' Everything about one dataset, lookup table or geometry dataset: what it
#' holds, its source, years, detail levels, the columns that identify a
#' row (the grain), its key metric, every filter, and the notes its data
#' contract declares (limitations, series breaks, groups that must not be
#' added up, and so on). Printing the result shows a readable summary.
#'
#' Read the **"Pick one value of"** line: it names categorical columns
#' with no total (such as `grade_cluster`), whose values must not be mixed
#' in one summary. [gcd_rows()] returns every value of them unless you
#' filter one.
#'
#' The `$filters` table is also how to discover the filters that are not
#' columns of the dataset: lookup-table attributes such as
#' `district_type`, `school_level`, `locale` and `demographic_category`.
#'
#' @param name A dataset, lookup table or geometry dataset name, such as
#'   `"graduation_rate_4_year_cohort"`, `"schools"` or
#'   `"school_attendance_zones"`. Names are unique across all three kinds.
#' @returns A `gcd_description` object: a named list with a print method.
#'   Components include `name`, `kind` (`"table"`, `"geometry"` or
#'   `"lookup"`), `title`, `summary`, `description`, `source`,
#'   `source_url`, `years` (integer), `year_gaps`, `detail_levels`,
#'   `default_detail`, `grain`, `key_metric`, and:
#'   - `$columns`: the column dictionary, as [gcd_columns()] returns it.
#'   - `$filters`: a tibble of every filter parameter: `param`, `kind`
#'     (categorical, foreign_key, dimension_attribute, metric_bound, year,
#'     detail, ...), `values` (list-column of allowed values),
#'     `multi_value`, `has_total`, `total_value`, `requires_single_value`
#'     and `nullable`.
#'   - `$notes`: the contract's declarations that are present, each a
#'     tibble or a string: `limitations`, `year_meaning`, `null_semantics`,
#'     `series_breaks`, `non_additive`, `partitions`, `pooled_rates`,
#'     `year_window`, `value_implications`, `pooled_min_count` (and
#'     `assignment_note` for the zones).
#'   - `$raw`: the full parsed schema response.
#' @family describe a dataset
#' @seealso [gcd_columns()] for the column table alone; [gcd_values()] for
#'   the category values present under a filter; [gcd_contract()] for the
#'   formal contract.
#' @export
#' @examplesIf interactive()
#' gcd_describe("graduation_rate_4_year_cohort")
#' gcd_describe("ccrpi_content_mastery")$filters
#' gcd_describe("schools")
gcd_describe <- function(name) {
  check_name_arg(name)
  kind <- resource_kind(name)
  out <- switch(kind,
    lookup = describe_lookup(lookup_schema(name)),
    geometry = describe_geometry(dataset_schema(name)),
    describe_table(dataset_schema(name))
  )
  structure(out, class = "gcd_description")
}

#' Get a dataset's column dictionary
#'
#' @description
#' The columns of a dataset, lookup table or geometry dataset as a tidy
#' table: what each column means, its type, its unit and, for metrics,
#' whether it is a numerator or denominator. This is the place to check
#' "what does `pct_proficient_learner_or_above` mean, and is it 0-1?".
#'
#' @inheritParams gcd_describe
#' @returns A tibble, one row per column, with columns:
#'   - `column`: the column name.
#'   - `label`: a short display name.
#'   - `type`: `"integer"`, `"number"`, `"string"`, `"boolean"` or
#'     `"date"`, which [gcd_rows()] maps to integer, double, character,
#'     logical and Date.
#'   - `role`: `"year"`, a foreign key (`"fk_district"`, `"fk_school"`,
#'     ...), `"categorical"` or `"metric"` for datasets; `"key"` or
#'     `"attribute"` for lookup tables.
#'   - `unit`: `"count"`, `"proportion"` (0-1 scale), a rate unit, ...
#'   - `is_key_metric`: logical, `TRUE` for the dataset's headline metric.
#'   - `metric_component`: `"numerator"` or `"denominator"` for the counts
#'     a rate is built from.
#'   - `nullable`: logical.
#'   - `valid_values`: list-column of a categorical column's values.
#'   - `description`: the full definition.
#'   - `null_meaning`: what a missing value means in this column.
#'
#'   Fields that don't apply (labels and units for lookup tables, most
#'   fields for geometry datasets) are `NA`.
#' @family describe a dataset
#' @seealso [gcd_describe()] for the whole schema.
#' @export
#' @examplesIf interactive()
#' gcd_columns("graduation_rate_4_year_cohort")
#' gcd_columns("schools")
gcd_columns <- function(name) {
  check_name_arg(name)
  kind <- resource_kind(name)
  schema <- if (kind == "lookup") lookup_schema(name) else dataset_schema(name)
  columns_tibble(schema, kind)
}

#' Get a dataset's data contract
#'
#' @description
#' The dataset's formal, versioned contract in the Open Data Contract
#' Standard (ODCS v3.2): its schema, quality rules, `version` and
#' `schema_hash`. For data engineers building pipelines and anyone citing
#' the exact schema. Most users want [gcd_describe()] instead.
#'
#' Datasets and the `school_attendance_zones` geometry dataset have
#' contracts; lookup tables and `school_district_boundaries` do not.
#'
#' @inheritParams gcd_describe
#' @param file A path. If given, the contract is written there verbatim as
#'   YAML and the path is returned invisibly. Default `NULL`: return the
#'   contract as a list.
#' @returns The contract as a nested list (parsed from its JSON form), or,
#'   with `file`, the path invisibly.
#' @family describe a dataset
#' @seealso [gcd_describe()] for a readable summary.
#' @export
#' @examplesIf interactive()
#' contract <- gcd_contract("graduation_rate_4_year_cohort")
#' contract$version
#' gcd_contract("graduation_rate_4_year_cohort", file = tempfile(fileext = ".yaml"))
gcd_contract <- function(name, file = NULL) {
  check_name_arg(name)
  if (!is.null(file) && !is_string(file)) {
    cli::cli_abort("{.arg file} must be a single path.")
  }
  kind <- resource_kind(name)
  if (kind == "lookup") {
    abort_gcd(
      c("Lookup tables have no contract route.",
        i = "Use {.code gcd_describe({.str {name}})} for the schema of {.val {name}}."),
      code = "no_contract"
    )
  }
  if (kind == "geometry" && is.null(dataset_schema(name)$endpoints$contract)) {
    abort_gcd(
      c("The geometry dataset {.val {name}} has no contract route.",
        i = "Use {.code gcd_describe({.str {name}})} for its fields."),
      code = "no_contract"
    )
  }
  path <- c("datasets", path_segment(name), "contract")
  if (is.null(file)) {
    return(gcd_get_meta(path, query = list(format = "json")))
  }
  req <- gcd_request(path, query = list(format = "yaml"))
  resp <- gcd_perform(req)
  writeBin(httr2::resp_body_raw(resp), file)
  invisible(file)
}

# Builders --------------------------------------------------------------------

#' @noRd
describe_table <- function(schema) {
  list(
    name = schema$name,
    kind = "table",
    title = schema$title,
    summary = schema$summary,
    description = schema$description,
    main_topic = schema$main_topic,
    source = schema$source,
    source_url = schema$source_url,
    update_frequency = schema$update_frequency,
    updated_at = if (!is.null(schema$updated_at)) parse_utc(schema$updated_at),
    years = as.integer(unlist(schema$available_years)),
    year_gaps = as.integer(unlist(schema$year_gaps)),
    detail_levels = as.character(unlist(schema$detail_levels)),
    default_detail = schema$default_detail,
    grain = as.character(unlist(schema$grain)),
    key_metric = schema$key_metric,
    columns = columns_tibble(schema, "table"),
    filters = filters_tibble(schema),
    notes = notes_list(schema),
    raw = drop_internal(schema)
  )
}

#' @noRd
describe_lookup <- function(schema) {
  list(
    name = schema$name,
    kind = "lookup",
    title = schema$name,
    description = schema$description,
    primary_key = as.character(unlist(schema$primary_key)),
    search_columns = as.character(unlist(schema$search$columns)),
    columns = columns_tibble(schema, "lookup"),
    filters = lookup_filters_tibble(schema),
    notes = compact(list(
      notes = schema$notes,
      semantics = schema$semantics
    )),
    raw = drop_internal(schema)
  )
}

#' @noRd
describe_geometry <- function(schema) {
  description <- schema$description
  purpose <- if (is.list(description)) description$purpose else description
  list(
    name = schema$name,
    kind = "geometry",
    title = gsub("_", " ", schema$name),
    description = purpose,
    source = schema$source,
    crs = schema$crs,
    grain = as.character(unlist(schema$grain)),
    formats = as.character(unlist(schema$formats)),
    columns = columns_tibble(schema, "geometry"),
    filters = geometry_filters_tibble(schema),
    notes = compact(list(
      limitations = schema$limitations,
      note = schema$note,
      assignment_note = schema$assignment_note
    )),
    raw = drop_internal(schema)
  )
}

#' The column dictionary for any kind of schema
#' @noRd
columns_tibble <- function(schema, kind) {
  cols <- if (kind == "geometry") schema$fields else schema$columns
  key_metric <- schema$key_metric %||% NA_character_
  field <- function(f) {
    simplify_field(lapply(cols, function(c) c[[f]]))
  }
  if (!length(cols)) {
    return(tibble::tibble(
      column = character(), label = character(), type = character(),
      role = character(), unit = character(), is_key_metric = logical(),
      metric_component = character(), nullable = logical(),
      valid_values = list(), description = character(),
      null_meaning = character()
    ))
  }
  values_field <- if (kind == "geometry") "enum" else "valid_values"
  out <- tibble::tibble(
    column = field("name"),
    label = field("label"),
    type = field("type"),
    role = field("role"),
    unit = field("unit"),
    is_key_metric = NA,
    metric_component = field("metric_component"),
    nullable = field("nullable"),
    valid_values = lapply(cols, function(c) flatten_value(c[[values_field]])),
    description = field("description"),
    null_meaning = field("null_meaning")
  )
  out$is_key_metric <- !is.na(key_metric) & out$column == key_metric
  apply_schema_types(out, c(
    column = "string", label = "string", type = "string", role = "string",
    unit = "string", metric_component = "string", nullable = "boolean",
    description = "string", null_meaning = "string"
  ))
}

#' The filters table of a dataset schema
#' @noRd
filters_tibble <- function(schema) {
  fields <- c("param", "kind", "values", "multi_value", "has_total",
              "total_value", "requires_single_value", "nullable")
  out <- records_to_tibble(schema$filters, fields = fields, list_cols = "values")
  apply_schema_types(out, c(
    param = "string", kind = "string", multi_value = "boolean",
    has_total = "boolean", total_value = "string",
    requires_single_value = "boolean", nullable = "boolean"
  ))
}

#' The filters table of a lookup-table schema (plus the `q` search)
#' @noRd
lookup_filters_tibble <- function(schema) {
  filters <- schema$filters
  key <- unlist(schema$primary_key)
  cols <- schema$columns
  col_type <- stats::setNames(
    vapply(cols, function(c) c$type %||% "string", character(1)),
    vapply(cols, function(c) c$name, character(1))
  )
  kinds <- vapply(filters, function(f) {
    if (f$param %in% key) {
      "key"
    } else if (identical(col_type[[f$param]], "boolean")) {
      "boolean"
    } else if (length(f$values)) {
      "enum"
    } else {
      "foreign_key"
    }
  }, character(1))
  out <- tibble::tibble(
    param = vapply(filters, function(f) f$param, character(1)),
    kind = unname(kinds),
    values = lapply(filters, function(f) flatten_value(f$values)),
    multi_value = vapply(filters, function(f) isTRUE(f$multi_value), logical(1)),
    has_total = NA, total_value = NA_character_,
    requires_single_value = FALSE, nullable = NA
  )
  if (!is.null(schema$search$param)) {
    out <- rbind(out, tibble::tibble(
      param = schema$search$param, kind = "search", values = list(character()),
      multi_value = FALSE, has_total = NA, total_value = NA_character_,
      requires_single_value = FALSE, nullable = NA
    ))
  }
  out
}

#' The filters table of a geometry schema (the API gives a name -> text map)
#' @noRd
geometry_filters_tibble <- function(schema) {
  filters <- schema$filters %||% list()
  enums <- stats::setNames(
    lapply(schema$fields, function(f) flatten_value(f$enum)),
    vapply(schema$fields, function(f) f$name, character(1))
  )
  params <- names(filters)
  kind <- vapply(params, function(p) {
    if (p %in% c("format", "resolution")) {
      "option"
    } else if (p == "year") {
      "year"
    } else if (p == "grade") {
      "grade"
    } else if (endsWith(p, "_code")) {
      "foreign_key"
    } else {
      "categorical"
    }
  }, character(1))
  values <- lapply(params, function(p) {
    v <- filters[[p]]
    if (is.list(v)) flatten_value(v) else enums[[p]] %||% character()
  })
  multi <- vapply(filters, function(v) {
    is_string(v) && grepl("comma list", v, fixed = TRUE)
  }, logical(1))
  tibble::tibble(
    param = params, kind = unname(kind), values = values,
    multi_value = unname(multi), has_total = NA, total_value = NA_character_,
    requires_single_value = FALSE, nullable = NA
  )
}

#' The contract declarations present in a dataset schema
#' @noRd
notes_list <- function(schema) {
  as_tbl <- function(x, list_cols = character()) {
    if (!length(x)) {
      return(NULL)
    }
    records_to_tibble(x, list_cols = list_cols)
  }
  one_row <- function(x) {
    if (is.null(x) || !length(x)) {
      return(NULL)
    }
    records_to_tibble(list(x))
  }
  implications <- NULL
  if (length(schema$value_implications)) {
    implications <- tibble::tibble(
      when = lapply(schema$value_implications, function(v) lapply(v$when, unlist)),
      implies = lapply(schema$value_implications, function(v) lapply(v$implies, unlist)),
      excludes = lapply(schema$value_implications, function(v) lapply(v$excludes, unlist)),
      reason = vapply(schema$value_implications,
                      function(v) v$reason %||% NA_character_, character(1))
    )
  }
  compact(list(
    limitations = if (is_string(schema$limitations) && nzchar(schema$limitations)) schema$limitations,
    year_meaning = if (is_string(schema$year_meaning) && nzchar(schema$year_meaning)) schema$year_meaning,
    null_semantics = if (length(schema$null_semantics)) schema$null_semantics,
    series_breaks = as_tbl(schema$series_breaks, list_cols = "metrics"),
    non_additive = as_tbl(schema$non_additive,
                          list_cols = intersect(c("metrics", "values", "with"),
                                                unique(unlist(lapply(schema$non_additive, names))))),
    partitions = as_tbl(schema$partitions),
    pooled_rates = as_tbl(schema$pooled_rates),
    year_window = one_row(schema$year_window),
    value_implications = implications,
    pooled_min_count = one_row(schema$pooled_min_count)
  ))
}

# Print -----------------------------------------------------------------------

#' @export
print.gcd_description <- function(x, ...) {
  lines <- switch(x$kind,
    lookup = describe_lines_lookup(x),
    geometry = describe_lines_geometry(x),
    describe_lines_table(x)
  )
  cli::cat_line(lines)
  invisible(x)
}

#' Format one line of output with cli markup
#' @noRd
fmt <- function(..., .envir = parent.frame()) {
  cli::format_inline(..., .envir = .envir)
}

#' @noRd
describe_lines_table <- function(x) {
  years <- year_span(x$years)
  gaps <- x$year_gaps
  details <- ifelse(x$detail_levels == x$default_detail %||% "",
                    paste0(x$detail_levels, " (default)"), x$detail_levels)
  single <- x$filters$param[x$filters$requires_single_value %in% TRUE]
  lines <- c(
    cli::rule(left = paste0(x$title, " (", x$name, ")")),
    if (is_string(x$summary)) x$summary,
    "",
    fmt("{.strong Source:} {x$source %||% 'unknown'}"),
    fmt("{.strong Years:} {years}{if (length(gaps)) paste0(' (no data for ', paste(gaps, collapse = ', '), ')') else ''}"),
    fmt("{.strong Detail levels:} {paste(details, collapse = ', ')}"),
    fmt("{.strong Grain:} {paste(x$grain, collapse = ', ')}"),
    if (is_string(x$key_metric)) fmt("{.strong Key metric:} {x$key_metric}"),
    if (length(single)) fmt("{.strong Pick one value of:} {paste(single, collapse = ', ')} (no total; don't mix values in one summary)"),
    fmt("{.strong Columns:} {nrow(x$columns)} (see {.code $columns}); {.strong filters:} {nrow(x$filters)} (see {.code $filters})"),
    notes_lines(x$notes)
  )
  lines
}

#' @noRd
describe_lines_lookup <- function(x) {
  c(
    cli::rule(left = paste0("Lookup table: ", x$name)),
    if (is_string(x$description)) x$description,
    "",
    fmt("{.strong Primary key:} {paste(x$primary_key, collapse = ' + ')}"),
    fmt("{.strong Columns:} {paste(x$columns$column, collapse = ', ')}"),
    fmt("{.strong Filters:} {paste(x$filters$param, collapse = ', ')}"),
    if (length(x$search_columns)) fmt("{.strong Text search} ({.code q}) {.strong over:} {paste(x$search_columns, collapse = ', ')}"),
    fmt("Get the rows with {.code gcd_dimension({.str {x$name}})}.")
  )
}

#' @noRd
describe_lines_geometry <- function(x) {
  notes <- x$notes
  c(
    cli::rule(left = paste0("Geometry dataset: ", x$name)),
    if (is_string(x$description)) x$description,
    "",
    if (is_string(x$source)) fmt("{.strong Source:} {x$source}"),
    if (is_string(x$crs)) fmt("{.strong CRS:} {x$crs}"),
    if (length(x$grain)) fmt("{.strong Grain:} {paste(x$grain, collapse = ', ')}"),
    fmt("{.strong Fields:} {nrow(x$columns)} (see {.code $columns}); {.strong filters:} {paste(x$filters$param, collapse = ', ')}"),
    if (length(notes)) c("", cli::rule(left = "Notes")),
    if (is_string(notes$limitations)) paste0("* Limitations: ", notes$limitations),
    if (is_string(notes$assignment_note)) paste0("* ", notes$assignment_note),
    if (is_string(notes$note)) paste0("* ", notes$note)
  )
}

#' Bullet lines for the contract declarations
#' @noRd
notes_lines <- function(notes) {
  if (!length(notes)) {
    return(character())
  }
  out <- character()
  ns <- notes$null_semantics
  if (isTRUE(ns$suppressed_to_null)) {
    from <- ns$zero_is_real_from_year
    zero <- if (isTRUE(ns$zero_is_real)) {
      "zeros are real"
    } else if (!is.null(from)) {
      paste0("zeros are real from ", from, " on")
    } else {
      "a zero may be suppressed too"
    }
    out <- c(out, paste0("* Missing values: NA means suppressed (small counts), not zero; ", zero, "."))
  }
  if (!is.null(notes$limitations)) {
    out <- c(out, paste0("* Limitations: ", notes$limitations))
  }
  if (!is.null(notes$year_meaning)) {
    out <- c(out, paste0("* Year meaning: ", notes$year_meaning))
  }
  sb <- notes$series_breaks
  if (!is.null(sb)) {
    out <- c(out, paste0("* Series break in ", sb$year, ": ", sb$reason))
  }
  na <- notes$non_additive
  if (!is.null(na)) {
    out <- c(out, paste0("* Not additive (", na$column, "): ", na$reason))
  }
  pt <- notes$partitions
  if (!is.null(pt)) {
    out <- c(out, paste0("* Partition (", pt$column, "): ", pt$reason))
  }
  pr <- notes$pooled_rates
  if (!is.null(pr)) {
    scale <- if ("scale" %in% names(pr)) pr$scale else NA
    suffix <- ifelse(is.na(scale) | scale %in% 1, "", paste0(" x ", scale))
    out <- c(out, paste0("* Pooled rate: ", pr$column, " = sum(", pr$numerator,
                         ") / sum(", pr$denominator, ")", suffix))
  }
  yw <- notes$year_window
  if (!is.null(yw)) {
    out <- c(out, paste0("* Year window: each figure pools ", yw$years,
                         " years, named by the window's end year",
                         if (isTRUE(yw$overlapping)) " (windows overlap: not an annual series)" else "",
                         "."))
  }
  vi <- notes$value_implications
  if (!is.null(vi)) {
    out <- c(out, paste0("* Value implication: ", vi$reason))
  }
  pm <- notes$pooled_min_count
  if (!is.null(pm)) {
    out <- c(out, paste0("* Pooled minimum count (", pm$count, "): ", pm$reason))
  }
  if (!length(out)) {
    return(character())
  }
  c("", cli::rule(left = "Notes"), out)
}

#' "2004-2025", "2024", or "none"
#' @noRd
year_span <- function(years) {
  if (!length(years)) {
    return("none listed")
  }
  if (length(years) == 1) {
    return(as.character(years))
  }
  paste0(min(years), "-", max(years))
}

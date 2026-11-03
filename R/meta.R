#' Get the metadata carried by a result
#'
#' @description
#' Every tibble from [gcd_rows()] carries the response's metadata as an
#' attribute: what the rows are, where they come from and how to cite
#' them. `gcd_meta()` returns it.
#'
#' Many dplyr verbs drop attributes, so read the metadata from the result
#' as it came back. [gcd_citation()] also accepts a dataset name.
#'
#' @param x A tibble returned by [gcd_rows()].
#' @returns A named list: `dataset` (the name), `title`, `detail`,
#'   `key_metric`, `units` (a named list of each metric's unit),
#'   `null_semantics` (what a missing value means), `source`,
#'   `source_url`, `citation`, `license`, `schema` (the schema's path),
#'   `advisories` (a tibble of `code` and `message`), `year_meaning`,
#'   `omitted_columns` (columns left out because they were empty), `data_version`,
#'   `updated_at` and `request_url`. Fields the API didn't send are absent.
#' @family utilities
#' @seealso [gcd_citation()] to cite the data.
#' @export
#' @examplesIf interactive()
#' grad <- gcd_rows("graduation_rate_4_year_cohort", district = "Fulton County",
#'                  year = 2024, demographic = "all")
#' gcd_meta(grad)$advisories
gcd_meta <- function(x) {
  meta <- attr(x, "gcd_meta", exact = TRUE)
  if (is.null(meta)) {
    abort_gcd(
      c("{.arg x} carries no Georgia Civic Data metadata.",
        i = "Metadata comes with results of {.fn gcd_rows}; many dplyr verbs drop it.",
        i = "{.fn gcd_citation} also takes a dataset name."),
      code = "no_metadata"
    )
  }
  meta
}

#' Cite a dataset
#'
#' @description
#' The citation for data from Georgia Civic Data, ready to paste:
#'
#' "\{title\}. Georgia Civic Data (georgiacivicdata.org), CC BY 4.0.
#' \{dataset URL\}. Original source: \{source\}."
#'
#' @section License and attribution:
#' The data is published under the Creative Commons Attribution 4.0
#' International license (CC BY 4.0,
#' <https://creativecommons.org/licenses/by/4.0/>). You may share and adapt
#' it for any purpose, including commercially, as long as you give credit:
#' name Georgia Civic Data (georgiacivicdata.org) and the original source,
#' link the license, and say if you changed the data. The citation covers
#' all three. The license covers Georgia Civic Data's cleaning,
#' standardization, compilation and documentation; the source data stays
#' under its original publisher's terms.
#'
#' @param x A tibble returned by [gcd_rows()], or a dataset name.
#' @returns A single string: the citation. For a result of [gcd_rows()] it
#'   is the API's own citation; for a name it is built from the dataset's
#'   schema in the same format.
#' @family utilities
#' @seealso [gcd_meta()] for all the metadata.
#' @export
#' @examplesIf interactive()
#' gcd_citation("graduation_rate_4_year_cohort")
#'
#' grad <- gcd_rows("graduation_rate_4_year_cohort", district = "Fulton County",
#'                  year = 2024, demographic = "all")
#' gcd_citation(grad)
gcd_citation <- function(x) {
  if (is_string(x)) {
    if (x %in% lookup_table_names()) {
      abort_gcd("{.val {x}} is a lookup table; cite the dataset that uses it.",
                code = "no_citation")
    }
    schema <- dataset_schema(x)
    title <- schema$title %||% catalog_title(x)
    return(format_citation(title, schema$name %||% x, schema$source))
  }
  if (!is.data.frame(x)) {
    cli::cli_abort("{.arg x} must be a result of {.fn gcd_rows} or a dataset name.")
  }
  meta <- gcd_meta(x)
  if (is_string(meta$citation)) {
    return(meta$citation)
  }
  format_citation(meta$title, meta$dataset, meta$source)
}

#' The citation in the platform's format
#' @noRd
format_citation <- function(title, name, source) {
  source <- source %||% "unknown"
  end <- if (grepl("[.!?]$", source)) "" else "."
  paste0(
    title %||% name, ". Georgia Civic Data (georgiacivicdata.org), CC BY 4.0. ",
    gcd_base_url, "/datasets/", name, ". Original source: ", source, end
  )
}

#' A dataset's title from the (cached) catalog
#' @noRd
catalog_title <- function(name) {
  catalog <- gcd_get_meta("datasets")
  for (d in catalog$data) {
    if (identical(d$name, name)) {
      return(d$title)
    }
  }
  NULL
}

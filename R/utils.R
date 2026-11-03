# Small shared helpers.

#' Drop `NULL` elements from a list
#' @noRd
compact <- function(x) {
  x[!vapply(x, is.null, logical(1))]
}

#' Is `x` a single non-missing string?
#' @noRd
is_string <- function(x) {
  is.character(x) && length(x) == 1 && !is.na(x)
}

#' Is `x` NULL or a single `TRUE`/`FALSE`?
#' @noRd
check_flag <- function(x, arg = rlang::caller_arg(x),
                       call = rlang::caller_env()) {
  if (!rlang::is_bool(x)) {
    cli::cli_abort("{.arg {arg}} must be {.code TRUE} or {.code FALSE}.",
                   call = call)
  }
  invisible(x)
}

#' Check a single string argument
#' @noRd
check_name_arg <- function(x, arg = rlang::caller_arg(x),
                           call = rlang::caller_env()) {
  if (!is_string(x) || !nzchar(x)) {
    cli::cli_abort("{.arg {arg}} must be a single string, such as a dataset name.",
                   call = call)
  }
  invisible(x)
}

#' Check an optional character vector argument (NULL, or non-empty
#' character without NA)
#' @noRd
check_chr <- function(x, arg = rlang::caller_arg(x),
                      call = rlang::caller_env(), allow_null = TRUE) {
  if (is.null(x) && allow_null) {
    return(invisible(NULL))
  }
  if (is.factor(x)) {
    x <- as.character(x)
  }
  if (!is.character(x) || length(x) == 0 || anyNA(x) || !all(nzchar(x))) {
    cli::cli_abort(
      "{.arg {arg}} must be a character vector of non-empty, non-missing values.",
      call = call
    )
  }
  invisible(x)
}

#' Check `n_max`-style arguments: a single number >= 1 (Inf allowed)
#' @noRd
check_n_max <- function(x, arg = rlang::caller_arg(x),
                        call = rlang::caller_env()) {
  if (!is.numeric(x) || length(x) != 1 || is.na(x) || x < 1) {
    cli::cli_abort("{.arg {arg}} must be a single number of at least 1, or {.code Inf}.",
                   call = call)
  }
  invisible(x)
}

#' Turn a list of JSON values into a vector or a list-column
#'
#' Each element of `vals` is one record's value of one field. When every
#' value is `NULL` or a length-one atomic, the result is an atomic vector
#' (`NULL` becomes `NA`); otherwise a list-column whose elements are atomic
#' vectors where possible.
#' @noRd
simplify_field <- function(vals, as_list = FALSE) {
  is_scalar <- vapply(
    vals,
    function(v) is.null(v) || (is.atomic(v) && length(v) == 1),
    logical(1)
  )
  if (!as_list && all(is_scalar)) {
    vals[vapply(vals, is.null, logical(1))] <- list(NA)
    return(unlist(vals, use.names = FALSE))
  }
  lapply(vals, flatten_value)
}

#' A JSON array of scalars becomes an atomic vector; anything else is kept
#' @noRd
flatten_value <- function(v) {
  if (is.null(v)) {
    return(character())
  }
  if (is.list(v) && length(v) == 0) {
    return(character())
  }
  if (is.list(v) && is.null(names(v)) &&
      all(vapply(v, function(e) is.atomic(e) && length(e) == 1, logical(1)))) {
    return(unlist(v, use.names = FALSE))
  }
  v
}

#' A list of JSON records (named lists) as a tibble
#'
#' Scalar fields become vectors; arrays and objects become list-columns.
#' `list_cols` forces fields to list-columns even when every value is
#' scalar. `fields` fixes the columns and their order (missing fields are
#' `NA`).
#' @noRd
records_to_tibble <- function(records, fields = NULL, list_cols = character()) {
  if (is.null(fields)) {
    fields <- unique(unlist(lapply(records, names)))
  }
  if (length(records) == 0) {
    cols <- lapply(fields, function(f) if (f %in% list_cols) list() else logical())
    names(cols) <- fields
    return(tibble::as_tibble(cols))
  }
  cols <- lapply(fields, function(f) {
    simplify_field(lapply(records, function(r) r[[f]]), as_list = f %in% list_cols)
  })
  names(cols) <- fields
  tibble::as_tibble(cols)
}

#' Move columns `cols` to sit right after column `after`
#' @noRd
move_after <- function(df, cols, after) {
  cols <- intersect(cols, names(df))
  if (!length(cols) || !after %in% names(df)) {
    return(df)
  }
  rest <- setdiff(names(df), cols)
  df[append(rest, cols, after = match(after, rest))]
}

#' Put the named columns first (those present), in order, then the rest
#' @noRd
order_columns <- function(df, first) {
  first <- intersect(first, names(df))
  df[c(first, setdiff(names(df), first))]
}

#' Is the advisory and note output silenced?
#' @noRd
is_quiet <- function(quiet = FALSE) {
  isTRUE(quiet) || isTRUE(getOption("gcd.quiet", FALSE))
}

#' Parse ISO 8601 timestamps ("2026-10-29T20:17:55+00:00") as UTC POSIXct
#' @noRd
parse_utc <- function(x) {
  x <- as.character(x)
  offset <- rep(0, length(x))
  m <- regmatches(x, regexec("([+-])(\\d{2}):?(\\d{2})$", x))
  has_offset <- lengths(m) == 4
  if (any(has_offset)) {
    parts <- do.call(rbind, m[has_offset])
    sign <- ifelse(parts[, 2] == "-", -1, 1)
    offset[has_offset] <- sign * (as.numeric(parts[, 3]) * 3600 +
                                    as.numeric(parts[, 4]) * 60)
  }
  x <- sub("(Z|[+-]\\d{2}:?\\d{2})$", "", x)
  out <- as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%OS", tz = "UTC")
  plain <- is.na(out) & !is.na(x)
  if (any(plain)) {
    out[plain] <- as.POSIXct(x[plain], format = "%Y-%m-%d %H:%M:%OS", tz = "UTC")
  }
  out - offset
}

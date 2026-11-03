# Session cache (metadata) and the opt-in disk cache (rows).

#' Package-level state: cached metadata and once-per-session flags
#' @noRd
the <- new.env(parent = emptyenv())
the$meta <- new.env(parent = emptyenv())
the$shown <- new.env(parent = emptyenv())

#' Get a cached metadata value, or compute and store it
#' @noRd
cache_get_or_set <- function(key, expr) {
  if (exists(key, envir = the$meta, inherits = FALSE)) {
    return(get(key, envir = the$meta, inherits = FALSE))
  }
  value <- force(expr)
  assign(key, value, envir = the$meta)
  value
}

#' GET a JSON metadata resource, cached for the session by URL
#' @noRd
gcd_get_meta <- function(path, query = list(), call = rlang::caller_env()) {
  req <- gcd_request(path, query = query)
  cache_get_or_set(
    paste0("json:", req$url),
    resp_json(gcd_perform(req, call = call))
  )
}

#' Has this once-per-session message been shown? Marks it shown.
#' @noRd
first_time <- function(key) {
  if (exists(key, envir = the$shown, inherits = FALSE)) {
    return(FALSE)
  }
  assign(key, TRUE, envir = the$shown)
  TRUE
}

#' The disk cache directory for row responses
#'
#' `getOption("gcd.cache_dir")` overrides the standard user cache folder
#' (tests point it at a temporary directory).
#' @noRd
gcd_cache_dir <- function() {
  getOption("gcd.cache_dir", tools::R_user_dir("georgiacivicdata", "cache"))
}

#' Clear the session cache and the disk cache
#'
#' Empties the in-memory cache of metadata (the catalog, dataset schemas
#' and lookup tables) kept for the R session, and deletes the opt-in disk
#' cache of row downloads (see the `cache` argument of [gcd_rows()]).
#' Location lookups are never cached, so there is nothing to clear for
#' them.
#'
#' The disk cache lives in `tools::R_user_dir("georgiacivicdata", "cache")`.
#' It is only ever written when you ask for it, with `cache = TRUE` or
#' `options(gcd.cache = TRUE)`.
#'
#' @returns `NULL`, invisibly.
#' @family utilities
#' @seealso [gcd_rows()] for the disk cache.
#' @export
#' @examplesIf interactive()
#' gcd_cache_clear()
gcd_cache_clear <- function() {
  rm(list = ls(the$meta, all.names = TRUE), envir = the$meta)
  rm(list = ls(the$shown, all.names = TRUE), envir = the$shown)
  dir <- gcd_cache_dir()
  if (dir.exists(dir)) {
    unlink(dir, recursive = TRUE)
  }
  invisible(NULL)
}

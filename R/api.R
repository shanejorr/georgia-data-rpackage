# The HTTP layer: one request builder, performers for JSON and files, and
# the error-envelope parser that turns API errors into classed conditions.

#' The API's base URL (no option to change it, by design)
#' @noRd
gcd_base_url <- "https://georgiacivicdata.org/api/v1"

#' Statuses retried automatically (rate limits and gateway hiccups)
#' @noRd
transient_statuses <- c(429L, 502L, 503L, 504L)

#' The package's user agent
#' @noRd
gcd_user_agent <- function() {
  paste0(
    "georgiacivicdata/", utils::packageVersion("georgiacivicdata"),
    " (+https://github.com/shanejorr/georgia-data-rpackage)"
  )
}

#' Build a request to the API
#'
#' @param path Path below the base URL, as a character vector of segments
#'   (each is URL-escaped) or one string of already-safe segments.
#' @param query Named list of query values; vectors are comma-joined.
#' @param timeout Seconds.
#' @param cache Use the opt-in disk cache (GET only).
#' @noRd
gcd_request <- function(path, query = list(), timeout = 60, cache = FALSE) {
  req <- httr2::request(gcd_base_url)
  req <- httr2::req_url_path_append(req, path)
  query <- compact(query)
  if (length(query)) {
    req <- httr2::req_url_query(req, !!!query, .multi = "comma")
  }
  req <- gcd_request_policies(req, timeout = timeout)
  if (isTRUE(cache)) {
    req <- httr2::req_cache(req, path = gcd_cache_dir())
  }
  req
}

#' User agent, timeout, retries and error handling shared by every request
#' (the Census geocoder requests use it too)
#' @noRd
gcd_request_policies <- function(req, timeout = 60, max_tries = 4,
                                 max_seconds = 180) {
  req <- httr2::req_user_agent(req, gcd_user_agent())
  req <- httr2::req_timeout(req, timeout)
  req <- httr2::req_retry(
    req,
    max_tries = max_tries,
    max_seconds = max_seconds,
    retry_on_failure = TRUE,
    is_transient = gcd_is_transient,
    after = gcd_retry_after
  )
  httr2::req_error(req, is_error = function(resp) FALSE)
}

#' Is a response worth retrying?
#' @noRd
gcd_is_transient <- function(resp) {
  httr2::resp_status(resp) %in% transient_statuses
}

#' How long to wait before a retry, honoring `Retry-After`, with a message
#' @noRd
gcd_retry_after <- function(resp) {
  wait <- httr2::resp_retry_after(resp)
  status <- httr2::resp_status(resp)
  what <- if (status == 429L) {
    "The API's rate limit was reached"
  } else {
    paste0("The server is busy (HTTP ", status, ")")
  }
  if (is.na(wait)) {
    cli::cli_inform(c(i = "{what}; retrying shortly."))
  } else {
    cli::cli_inform(c(i = "{what}; retrying in {wait} second{?s}."))
  }
  wait
}

#' Perform a request, turning failures into classed conditions
#'
#' @param path Optional file to stream the body into.
#' @param service Which service is called, for the "unavailable" message.
#' @noRd
gcd_perform <- function(req, path = NULL, call = rlang::caller_env(),
                        service = "api") {
  resp <- tryCatch(
    httr2::req_perform(req, path = path),
    httr2_failure = function(cnd) {
      abort_unavailable(cnd, call = call, service = service)
    }
  )
  if (httr2::resp_status(resp) >= 400) {
    if (service == "api") {
      abort_api_error(resp, call = call)
    } else {
      abort_service_error(resp, call = call, service = service)
    }
  }
  resp
}

#' Parse a JSON response body
#' @noRd
resp_json <- function(resp, simplify = FALSE) {
  jsonlite::fromJSON(
    httr2::resp_body_string(resp, encoding = "UTF-8"),
    simplifyVector = simplify
  )
}

#' GET a JSON resource
#' @noRd
gcd_get_json <- function(path, query = list(), timeout = 60, simplify = FALSE,
                         call = rlang::caller_env()) {
  req <- gcd_request(path, query = query, timeout = timeout)
  resp_json(gcd_perform(req, call = call), simplify = simplify)
}

#' Escape one path segment (a dataset or table name)
#' @noRd
path_segment <- function(x) {
  curl::curl_escape(x)
}

# Conditions ------------------------------------------------------------------

#' Turn an API error response into a `gcd_error` condition
#' @noRd
abort_api_error <- function(resp, call = rlang::caller_env()) {
  status <- httr2::resp_status(resp)
  envelope <- tryCatch(resp_json(resp)$error, error = function(e) NULL)
  if (!is.list(envelope)) {
    envelope <- NULL
  }
  code <- envelope$code %||% paste0("HTTP_", status)
  api_message <- envelope$message %||% httr2::resp_status_desc(resp) %||%
    "The request failed."
  details <- envelope$details
  if (!is.list(details)) {
    details <- list()
  }
  dym <- unlist(details$did_you_mean)
  hint <- details$hint
  moved <- details$moved_to
  available <- unlist(details$available)
  valid <- unlist(details$valid)
  wait <- if (status == 429L) httr2::resp_retry_after(resp) else NA

  bullets <- c("{api_message}")
  if (status >= 500) {
    bullets <- c(
      "The Georgia Civic Data API couldn't answer (HTTP {status}).",
      x = "{api_message}",
      i = "Try again in a few minutes."
    )
  }
  if (status == 429L) {
    bullets <- c(
      "The Georgia Civic Data API's rate limit was reached.",
      i = if (is.na(wait)) "Try again shortly." else "Try again in {wait} second{?s}."
    )
  }
  if (length(dym)) {
    bullets <- c(bullets, i = "Did you mean: {.val {dym}}?")
  }
  if (is_string(hint)) {
    bullets <- c(bullets, i = "{hint}")
  }
  if (is_string(moved)) {
    bullets <- c(bullets, i = "Moved to {.url {moved}}.")
  }
  if (length(available)) {
    bullets <- c(bullets, i = "Available: {.val {available}}.")
  }
  if (length(valid)) {
    bullets <- c(bullets, i = "Valid values: {.val {valid}}.")
  }
  class <- c(
    paste0("gcd_error_", tolower(code)),
    if (status >= 500) "gcd_error_unavailable",
    "gcd_error"
  )
  cli::cli_abort(
    bullets,
    class = unique(class),
    code = code,
    status = status,
    details = details,
    call = call
  )
}

#' The API (or the Census geocoder) could not be reached at all
#' @noRd
abort_unavailable <- function(parent, call = rlang::caller_env(),
                              service = "api") {
  what <- service_label(service)
  cli::cli_abort(
    c(
      "Couldn't reach {what}.",
      i = "Check your internet connection, or try again later."
    ),
    class = c("gcd_error_unavailable", "gcd_error"),
    code = "UNAVAILABLE",
    status = NA_integer_,
    details = list(),
    parent = parent,
    call = call
  )
}

#' An HTTP error from a service other than the API (the Census geocoder)
#' @noRd
abort_service_error <- function(resp, call = rlang::caller_env(),
                                service = "census") {
  status <- httr2::resp_status(resp)
  what <- service_label(service)
  class <- c(
    paste0("gcd_error_", service),
    if (status >= 500 || status == 429L) "gcd_error_unavailable",
    "gcd_error"
  )
  cli::cli_abort(
    c("{what} returned an error (HTTP {status}).",
      i = "Try again later."),
    class = class,
    code = paste0("HTTP_", status),
    status = status,
    details = list(),
    call = call
  )
}

#' @noRd
service_label <- function(service) {
  switch(service,
    census = "the U.S. Census geocoder",
    "the Georgia Civic Data API"
  )
}

#' Raise a package-side `gcd_error` (no HTTP involved)
#' @noRd
abort_gcd <- function(message, code, ..., details = list(),
                      call = rlang::caller_env(), .envir = parent.frame()) {
  cli::cli_abort(
    message,
    class = c(paste0("gcd_error_", tolower(code)), "gcd_error"),
    code = toupper(code),
    status = NA_integer_,
    details = details,
    ...,
    call = call,
    .envir = .envir
  )
}

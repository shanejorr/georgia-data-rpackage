# Address geocoding with the U.S. Census batch geocoder, on the user's own
# computer: addresses never reach the Georgia Civic Data API.

#' The Census batch geocoder (locations, current address ranges)
#' @noRd
census_batch_url <- "https://geocoding.geo.census.gov/geocoder/locations/addressbatch"

#' The Census benchmark the API's own address search uses
#' @noRd
census_benchmark <- "Public_AR_Current"

#' The most records the Census accepts per batch file
#' @noRd
census_batch_max <- 10000

#' Normalize the `address` argument
#'
#' A character vector of one-line addresses goes into the street field
#' alone (the Census matches those as well as split fields); a data frame
#' needs `street`, `city`, `state` and `zip` columns.
#' @returns A tibble: `address` (one line), `street`, `city`, `state`, `zip`.
#' @noRd
address_input <- function(address, call = rlang::caller_env()) {
  if (is.data.frame(address)) {
    need <- c("street", "city", "state", "zip")
    missing <- setdiff(need, names(address))
    if (length(missing)) {
      cli::cli_abort(
        c("A data frame {.arg address} needs columns {.field {need}}.",
          x = "Missing: {.field {missing}}."),
        call = call
      )
    }
    if (!nrow(address)) {
      cli::cli_abort("{.arg address} has no rows.", call = call)
    }
    fields <- lapply(address[need], function(x) {
      x <- trimws(as.character(x))
      x[!is.na(x) & !nzchar(x)] <- NA
      x
    })
    one_line <- paste_address(fields$street, fields$city, fields$state, fields$zip)
    return(tibble::tibble(address = one_line, street = fields$street,
                          city = fields$city, state = fields$state,
                          zip = fields$zip))
  }
  if (!is.character(address) || !length(address)) {
    cli::cli_abort(
      "{.arg address} must be a character vector of one-line addresses, or a data frame with {.field street}, {.field city}, {.field state} and {.field zip}.",
      call = call
    )
  }
  street <- trimws(address)
  street[!is.na(street) & !nzchar(street)] <- NA
  tibble::tibble(address = address, street = street, city = NA_character_,
                 state = NA_character_, zip = NA_character_)
}

#' "street, city, state zip" from the parts present
#' @noRd
paste_address <- function(street, city, state, zip) {
  state_zip <- trimws(paste(ifelse(is.na(state), "", state),
                            ifelse(is.na(zip), "", zip)))
  parts <- cbind(street, city, ifelse(nzchar(state_zip), state_zip, NA))
  out <- apply(parts, 1, function(p) paste(p[!is.na(p)], collapse = ", "))
  out[is.na(street)] <- NA
  out
}

#' Geocode addresses with the Census batch geocoder
#'
#' @param input A tibble from `address_input()`.
#' @returns A tibble in input order: `match_status` (`"match"`,
#'   `"no_match"`, `"tie"`, or `NA` when no address was given),
#'   `match_type` (`"exact"`, `"non_exact"`), `matched_address`, `lat`,
#'   `lon`.
#' @noRd
census_geocode <- function(input, call = rlang::caller_env()) {
  n <- nrow(input)
  out <- tibble::tibble(
    match_status = rep(NA_character_, n),
    match_type = NA_character_,
    matched_address = NA_character_,
    lat = NA_real_,
    lon = NA_real_
  )
  todo <- which(!is.na(input$street))
  if (!length(todo)) {
    return(out)
  }
  batches <- split(todo, ceiling(seq_along(todo) / census_batch_max))
  progress <- NULL
  if (length(batches) > 1) {
    progress <- cli::cli_progress_bar("Geocoding addresses",
                                      total = length(batches))
  }
  for (batch in batches) {
    parsed <- census_batch(input[batch, ], ids = batch, call = call)
    rows <- match(parsed$id, as.character(batch))
    keep <- !is.na(rows)
    out[batch[rows[keep]], ] <- parsed[keep, names(out)]
    if (!is.null(progress)) {
      cli::cli_progress_update(id = progress)
    }
  }
  if (!is.null(progress)) {
    cli::cli_progress_done(id = progress)
  }
  out
}

#' Send one batch file to the Census and parse the answer
#' @noRd
census_batch <- function(rows, ids, call = rlang::caller_env()) {
  file <- tempfile(fileext = ".csv")
  on.exit(unlink(file), add = TRUE)
  csv <- census_csv(ids, rows)
  writeLines(csv, file, useBytes = TRUE)
  req <- httr2::request(census_batch_url)
  req <- gcd_request_policies(req, timeout = 1800, max_tries = 3,
                              max_seconds = 3600)
  req <- httr2::req_body_multipart(
    req,
    addressFile = curl::form_file(file, type = "text/csv"),
    benchmark = census_benchmark
  )
  resp <- gcd_perform(req, call = call, service = "census")
  parse_census(httr2::resp_body_string(resp, encoding = "UTF-8"), call = call)
}

#' The upload: id, street, city, state, ZIP, every field quoted
#' @noRd
census_csv <- function(ids, rows) {
  quote <- function(x) {
    x <- ifelse(is.na(x), "", x)
    paste0("\"", gsub("\"", "\"\"", x, fixed = TRUE), "\"")
  }
  enc2utf8(paste(quote(as.character(ids)), quote(rows$street), quote(rows$city),
                 quote(rows$state), quote(rows$zip), sep = ","))
}

#' Parse the Census response CSV (no header; unmatched rows are short)
#' @noRd
parse_census <- function(text, call = rlang::caller_env()) {
  cols <- c("id", "input", "match_status", "match_type", "matched_address",
            "coordinates", "tiger_line_id", "side")
  empty <- tibble::tibble(id = character(), match_status = character(),
                          match_type = character(), matched_address = character(),
                          lat = numeric(), lon = numeric())
  if (!nzchar(trimws(text))) {
    return(empty)
  }
  raw <- tryCatch(
    utils::read.csv(text = text, header = FALSE, col.names = cols,
                    colClasses = "character", fill = TRUE, na.strings = "",
                    encoding = "UTF-8"),
    error = function(e) NULL
  )
  if (is.null(raw)) {
    cli::cli_abort("Couldn't read the U.S. Census geocoder's response.",
                   class = c("gcd_error_census", "gcd_error"), call = call)
  }
  coords <- strsplit(ifelse(is.na(raw$coordinates), "", raw$coordinates), ",",
                     fixed = TRUE)
  lon <- suppressWarnings(as.numeric(vapply(coords, function(x) x[1] %||% NA_character_, character(1))))
  lat <- suppressWarnings(as.numeric(vapply(coords, function(x) if (length(x) > 1) x[2] else NA_character_, character(1))))
  status <- tolower(raw$match_status)
  tibble::tibble(
    id = trimws(raw$id),
    match_status = status,
    match_type = tolower(raw$match_type),
    matched_address = raw$matched_address,
    lat = ifelse(status == "match", lat, NA_real_),
    lon = ifelse(status == "match", lon, NA_real_)
  )
}

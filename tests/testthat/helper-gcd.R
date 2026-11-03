# Shared test helpers.

shorten_url <- function(url) {
  url <- sub("^https://georgiacivicdata\\.org/api/v1/datasets/", "https://g/d/", url)
  url <- sub("^https://georgiacivicdata\\.org/api/v1/dimensions/", "https://g/m/", url)
  sub("^https://georgiacivicdata\\.org/api/v1/", "https://g/", url)
}

gcd_redactor <- function(x) {
  x$url <- shorten_url(x$url)
  if (inherits(x, "httr2_response")) {
    keep <- c("content-type", "etag", "x-total-count", "retry-after")
    headers <- x$headers
    type <- headers[["content-type"]] %||% headers[["Content-Type"]] %||% ""
    if (startsWith(type, "application/yaml")) {
      # httptest2 stores text types as plain files; YAML would be dput() bytes
      headers[["content-type"]] <- "text/plain"
      headers[["Content-Type"]] <- NULL
    }
    x$headers <- structure(
      headers[tolower(names(headers)) %in% keep],
      class = class(headers)
    )
  }
  x
}

# A fresh session cache, a temporary disk cache, and default options.
# The list of lookup tables is seeded so fixtures don't each record it.
local_gcd_state <- function(env = parent.frame(), seed_tables = TRUE) {
  skip_if_not_installed("withr")
  saved_meta <- as.list(the$meta, all.names = TRUE)
  saved_shown <- as.list(the$shown, all.names = TRUE)
  rm(list = ls(the$meta, all.names = TRUE), envir = the$meta)
  rm(list = ls(the$shown, all.names = TRUE), envir = the$shown)
  withr::defer({
    rm(list = ls(the$meta, all.names = TRUE), envir = the$meta)
    rm(list = ls(the$shown, all.names = TRUE), envir = the$shown)
    list2env(saved_meta, the$meta)
    list2env(saved_shown, the$shown)
  }, envir = env)
  withr::local_options(
    gcd.cache_dir = withr::local_tempdir(.local_envir = env),
    gcd.quiet = NULL,
    gcd.cache = NULL,
    .local_envir = env
  )
  if (seed_tables) {
    seed_meta("dimensions", list(data = lapply(
      c("districts", "schools", "block_groups", "counties", "demographics", "tracts"),
      function(n) list(name = n)
    )))
  }
  invisible()
}

# Put a parsed JSON value into the session cache under its URL.
seed_meta <- function(path, value, query = list()) {
  req <- gcd_request(path, query = query)
  assign(paste0("json:", req$url), value, envir = the$meta)
}

# Small lookup tables for the resolver and gcd_locate() (public names and
# codes; no addresses).
test_tables <- function() {
  list(
    districts = tibble::tibble(
      district_code = c("660", "761", "630", "634", "638", "644", "7830613", "9901", "9902"),
      district_name = c("Fulton County", "Atlanta Public Schools", "Clay County",
                        "Coffee County", "Coweta County", "DeKalb County",
                        "BIA Charter School", "Sample Academy", "Other Academy"),
      former_names = c(NA, NA, NA, NA, NA, NA, "Brookhaven Innovation Academy",
                       NA, "Sample Academy"),
      county_fips = c("13121", "13121", "13061", "13069", "13077", "13089",
                      "13135", "13121", "13121"),
      active = c(TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE)
    ),
    schools = tibble::tibble(
      district_code = c("660", "660", "660", "660", "634", "638", "630", "761", "761", "644"),
      school_code = c("0191", "0106", "2060", "3066", "0282", "2052", "0104", "0199", "4560", "0101"),
      school_name = c("Roswell High School", "Milton High School", "Milton High School",
                      "Riverwood International Charter School", "Eastside Elementary School",
                      "Eastside Elementary School", "Clay County Middle School",
                      "Centennial Academy (Charter)", "Midtown High School",
                      "José Martí Academy"),
      former_names = c(NA, NA, NA, "Riverwood High School", NA, NA, NA, NA,
                       "Henry W. Grady High School", NA),
      active = c(TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE)
    ),
    counties = tibble::tibble(
      county_fips = c("13001", "13061", "13089", "13121"),
      county_name = c("Appling", "Clay", "DeKalb", "Fulton")
    ),
    tracts = tibble::tibble(
      tract_geoid = "13121003500",
      tract_name = "Census Tract 35",
      county_fips = "13121"
    ),
    block_groups = tibble::tibble(
      block_group_geoid = "131210035001",
      block_group_name = "Block Group 1, Census Tract 35, Fulton County"
    )
  )
}

# Seed the cached lookup tables the resolver and gcd_locate() read.
local_test_tables <- function(env = parent.frame()) {
  tables <- test_tables()
  for (name in names(tables)) {
    assign(paste0("lookup:", name), tables[[name]], envir = the$meta)
  }
  invisible(tables)
}

# A JSON response for httr2's mocking.
json_response <- function(body, status = 200L, headers = list()) {
  httr2::response(
    status_code = status,
    headers = c(list(`Content-Type` = "application/json"), headers),
    body = charToRaw(enc2utf8(as.character(
      jsonlite::toJSON(body, auto_unbox = TRUE, null = "null", na = "null", digits = NA)
    )))
  )
}

# An API error envelope response.
error_response <- function(status, code, message, details = NULL,
                           headers = list()) {
  json_response(
    list(error = list(code = code, message = message, details = details)),
    status = status, headers = headers
  )
}

# Mock responses by URL pattern: a named list of pattern -> response (or a
# function of the request).
local_routes <- function(routes, env = parent.frame()) {
  httr2::local_mocked_responses(function(req) {
    for (pattern in names(routes)) {
      if (grepl(pattern, req$url, fixed = TRUE)) {
        route <- routes[[pattern]]
        return(if (is.function(route)) route(req) else route)
      }
    }
    rlang::abort(paste("Unexpected request:", req$url))
  }, env = env)
}

# The parsed JSON fixture files kept beside the tests.
fixture_json <- function(file) {
  jsonlite::fromJSON(test_path("fixtures", file), simplifyVector = FALSE)
}

skip_if_no_mocks <- function() {
  skip_if_not_installed("httptest2")
}

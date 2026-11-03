test_that("the user agent names the package and its repository", {
  expect_match(gcd_user_agent(),
               "^georgiacivicdata/[0-9.]+ \\(\\+https://github.com/shanejorr/georgia-data-rpackage\\)$")
})

test_that("gcd_request() builds the URL with comma-joined lists", {
  req <- gcd_request(c("datasets", "employment", "rows"),
                     query = list(county_fips = c("13121", "13089"), year = "2024",
                                  skipped = NULL))
  expect_equal(req$url, paste0(gcd_base_url,
                               "/datasets/employment/rows?county_fips=13121,13089&year=2024"))
  expect_equal(req$options$useragent, gcd_user_agent())
  expect_equal(req$policies$retry_max_tries, 4)
  expect_true(is.function(req$policies$retry_is_transient))
  expect_null(req$policies$cache_path)
})

test_that("cache = TRUE turns on httr2's ETag cache in the cache folder", {
  local_gcd_state()
  req <- gcd_request("datasets", cache = TRUE)
  expect_equal(req$policies$cache_path, gcd_cache_dir())
})

test_that("path_segment() escapes names", {
  expect_equal(path_segment("a b/c"), "a%20b%2Fc")
})

test_that("429 and gateway errors are retried, honoring Retry-After", {
  expect_true(gcd_is_transient(httr2::response(429)))
  expect_true(gcd_is_transient(httr2::response(503)))
  expect_false(gcd_is_transient(httr2::response(400)))
  expect_false(gcd_is_transient(httr2::response(500)))
  expect_snapshot({
    wait <- gcd_retry_after(httr2::response(429, headers = list(`Retry-After` = "7")))
    wait
    wait <- gcd_retry_after(httr2::response(503))
    wait
  })
})

test_that("API error envelopes become classed conditions", {
  local_gcd_state()
  local_routes(list(
    "datasets/graduation_rate/rows" = error_response(
      404, "TOPIC_NOT_FOUND", "No dataset 'graduation_rate'",
      list(did_you_mean = list("ccrpi_graduation_rate", "graduation_rate_4_year_cohort"))
    ),
    "datasets/counties/contract" = error_response(
      404, "TOPIC_NOT_FOUND", "No dataset 'counties'",
      list(hint = "'counties' is a lookup table: /api/v1/dimensions/counties")
    ),
    "dimensions/countys" = error_response(
      404, "DIM_NOT_FOUND", "No lookup table 'countys'",
      list(available = list("counties", "tracts"))
    ),
    "old/path" = error_response(404, "NOT_FOUND", "Gone", list(moved_to = "/api/v1/datasets")),
    "locate" = error_response(400, "INVALID_GRADE", "unknown grade; use pk, k or 01-12",
                              list(valid = list("pk", "k", "01"))),
    "datasets/slow/rows" = error_response(503, "QUERY_TIMEOUT", "The query took too long"),
    "datasets/busy/rows" = error_response(429, "RATE_LIMITED", "Too many requests",
                                          headers = list(`Retry-After` = "30")),
    "datasets/html/rows" = httr2::response(502, headers = list(`Content-Type` = "text/html"),
                                           body = charToRaw("<html>Bad gateway</html>"))
  ))
  get <- function(path) gcd_get_json(path)
  expect_snapshot(error = TRUE, get(c("datasets", "graduation_rate", "rows")))
  expect_snapshot(error = TRUE, get(c("datasets", "counties", "contract")))
  expect_snapshot(error = TRUE, get(c("dimensions", "countys")))
  expect_snapshot(error = TRUE, get(c("old", "path")))
  expect_snapshot(error = TRUE, get("locate"))
  expect_snapshot(error = TRUE, get(c("datasets", "slow", "rows")))
  expect_snapshot(error = TRUE, get(c("datasets", "busy", "rows")))
  expect_snapshot(error = TRUE, get(c("datasets", "html", "rows")))

  err <- tryCatch(get(c("datasets", "graduation_rate", "rows")), error = identity)
  expect_s3_class(err, c("gcd_error_topic_not_found", "gcd_error"))
  expect_equal(err$code, "TOPIC_NOT_FOUND")
  expect_equal(err$status, 404L)
  expect_equal(unlist(err$details$did_you_mean)[1], "ccrpi_graduation_rate")

  err <- tryCatch(get(c("datasets", "slow", "rows")), error = identity)
  expect_s3_class(err, "gcd_error_query_timeout")
  expect_s3_class(err, "gcd_error_unavailable")
  err <- tryCatch(get(c("datasets", "html", "rows")), error = identity)
  expect_s3_class(err, "gcd_error_http_502")
})

test_that("a transport failure is gcd_error_unavailable", {
  local_gcd_state()
  httr2::local_mocked_responses(function(req) {
    rlang::catch_cnd(rlang::abort("Could not resolve host", class = "httr2_failure"))
  })
  expect_snapshot(error = TRUE, gcd_get_json("datasets"))
  err <- tryCatch(gcd_get_json("datasets"), error = identity)
  expect_s3_class(err, "gcd_error_unavailable")
  expect_s3_class(err$parent, "httr2_failure")
})

test_that("Census errors name the Census geocoder", {
  resp <- httr2::response(503)
  expect_snapshot(error = TRUE, abort_service_error(resp, service = "census"))
  err <- tryCatch(abort_service_error(resp, service = "census"), error = identity)
  expect_s3_class(err, c("gcd_error_census", "gcd_error_unavailable", "gcd_error"))
  expect_snapshot(error = TRUE, abort_unavailable(simpleError("x"), service = "census"))
})

test_that("gcd_get_meta() caches by URL", {
  local_gcd_state()
  calls <- 0
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1
    json_response(list(data = list(), count = 0))
  })
  gcd_get_meta("datasets", query = list(kind = "geometry"))
  gcd_get_meta("datasets", query = list(kind = "geometry"))
  expect_equal(calls, 1)
  gcd_get_meta("datasets", query = list(kind = "table"))
  expect_equal(calls, 2)
})

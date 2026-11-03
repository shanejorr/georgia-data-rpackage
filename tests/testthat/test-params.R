test_that("encode_values() writes NA, logicals, numbers and dates as text", {
  expect_equal(encode_values(c("all", NA), "x"), c("all", "__null__"))
  expect_equal(encode_values(c(TRUE, FALSE, NA), "x"), c("true", "false", "__null__"))
  expect_equal(encode_values(c(0.9, 2024, 1e-7, 123456789012), "x"),
               c("0.9", "2024", "0.0000001", "123456789012"))
  expect_equal(encode_values(2024L, "x"), "2024")
  expect_equal(encode_values(factor("b"), "x"), "b")
  expect_equal(encode_values(as.Date("2026-01-02"), "x"), "2026-01-02")
  expect_snapshot(error = TRUE, encode_values(list(1), "subject"))
})

test_that("format_number() never uses scientific notation", {
  expect_equal(format_number(1e6), "1000000")
  expect_equal(format_number(0.25), "0.25")
  expect_equal(format_number(-3), "-3")
  expect_true(is.na(format_number(NA_real_)))
})

test_that("encode_years() sends runs as ranges and the rest as lists", {
  expect_equal(encode_years(NULL), list())
  expect_equal(encode_years(2024), list(year = "2024"))
  expect_equal(encode_years(2019:2024), list(year_min = "2019", year_max = "2024"))
  expect_equal(encode_years(c(2024, 2019:2023)), list(year_min = "2019", year_max = "2024"))
  expect_equal(encode_years(c(2019, 2024)), list(year = c("2019", "2024")))
  expect_equal(encode_years(c(2020, 2020)), list(year = "2020"))
  expect_snapshot(error = TRUE, encode_years("2024"))
  expect_snapshot(error = TRUE, encode_years(2024.5))
})

test_that("encode_filters() encodes named filters and renames school_id", {
  out <- encode_filters(list(
    demographic = c("all", "black", "all"),
    school_id = "761-0199",
    active = TRUE,
    graduation_rate_min = 0.9,
    assessment_type = NA,
    skipped = NULL
  ))
  expect_equal(out, list(
    demographic = c("all", "black"),
    school = "761-0199",
    active = "true",
    graduation_rate_min = "0.9",
    assessment_type = "__null__"
  ))
  expect_equal(encode_filters(list()), list())
})

test_that("encode_filters() refuses unnamed, empty, reserved and list filters", {
  expect_snapshot(error = TRUE, encode_filters(list("all")))
  expect_snapshot(error = TRUE, encode_filters(list(subject = character())))
  expect_snapshot(error = TRUE, encode_filters(list(limit = 5)))
  expect_snapshot(error = TRUE, encode_filters(list(school = "761-0199")))
  expect_snapshot(error = TRUE, encode_filters(list(subject = list("a"))))
  expect_snapshot(error = TRUE, encode_filters(stats::setNames(list(1, 2), c("a", "a"))))
})

test_that("dataset_query() merges years, filters, places and options", {
  places <- list(district_code = "660", county_fips = NULL,
                 school_pairs = "660-0191")
  q <- dataset_query(list(demographic = "all"), list(year = "2024"),
                     "schools", places, columns = c("year", "school_code"),
                     sort = "-year")
  expect_equal(q, list(
    year = "2024", detail = "schools", demographic = "all",
    district_code = "660", school = "660-0191",
    columns = c("year", "school_code"), sort = "-year"
  ))
  expect_length(dataset_query(list(), list(), NULL, list()), 0)
})

test_that("dataset_request() switches to POST /query for very long URLs", {
  short <- dataset_request("employment", "rows", list(county_fips = "13121"))
  expect_equal(httr2::req_get_method(short), "GET")
  expect_match(short$url, "datasets/employment/rows\\?county_fips=13121$")

  tracts <- sprintf("13121%06d", seq_len(600))
  long <- dataset_request("employment", "rows", list(tract_geoid = tracts, detail = "tracts"))
  expect_equal(httr2::req_get_method(long), "POST")
  expect_match(long$url, "datasets/employment/query$")
  body <- long$body$data
  expect_length(body$tract_geoid, 600)
  expect_equal(body$detail, list("tracts"))

  values <- dataset_request("employment", "values", list(tract_geoid = tracts))
  expect_equal(httr2::req_get_method(values), "GET")
})

test_that("check_query_args() wants one detail level", {
  expect_snapshot(error = TRUE, check_query_args(c("states", "districts"), NULL, NULL))
  expect_snapshot(error = TRUE, check_query_args(NULL, c("year", NA), NULL))
})

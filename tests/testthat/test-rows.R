test_that("gcd_rows() returns typed rows with names beside codes", {
  skip_if_no_mocks()
  local_gcd_state()
  local_test_tables()
  httptest2::with_mock_dir("m/rows", {
    expect_snapshot(
      out <- gcd_rows("graduation_rate_4_year_cohort",
                      district = "Fulton County", school = "Roswell High School",
                      year = 2024, demographic = c("all", "black"))
    )
  })
  expect_s3_class(out, "tbl_df")
  expect_named(out, c("year", "district_code", "district_name", "district_census_id",
                      "district_type", "school_code", "school_name", "demographic",
                      "demographic_label", "demographic_category", "num_graduates",
                      "num_cohort", "graduation_rate"))
  expect_type(out$year, "integer")
  expect_type(out$num_graduates, "integer")
  expect_type(out$graduation_rate, "double")
  expect_true(all(out$graduation_rate <= 1, na.rm = TRUE))
  expect_equal(unique(out$school_code), "0191")
  expect_equal(unique(out$district_census_id), "02280")
  expect_setequal(out$demographic, c("all", "black"))

  meta <- gcd_meta(out)
  expect_equal(meta$dataset, "graduation_rate_4_year_cohort")
  expect_null(meta[["key"]])
  expect_s3_class(meta$advisories, "tbl_df")
  expect_match(meta$request_url, "school=660-0191")
  expect_match(gcd_citation(out), "^Four-Year Cohort Graduation Rate\\. Georgia Civic Data")
})

test_that("labels = FALSE gives the same shape without the names", {
  skip_if_no_mocks()
  local_gcd_state()
  httptest2::with_mock_dir("m/rows2", {
    with <- gcd_rows("graduation_rate_4_year_cohort", district_code = "660",
                     detail = "districts", year = 2024, demographic = "all",
                     quiet = TRUE)
    without <- gcd_rows("graduation_rate_4_year_cohort", district_code = "660",
                        detail = "districts", year = 2024, demographic = "all",
                        labels = FALSE, quiet = TRUE)
    states <- gcd_rows("graduation_rate_4_year_cohort", detail = "states",
                       year = 2024, sort = "-graduation_rate", n_max = 3,
                       quiet = TRUE)
  })
  expect_false("school_code" %in% names(with))
  expect_equal(names(without),
               setdiff(names(with), c("district_name", "district_census_id",
                                      "district_type", "demographic_label",
                                      "demographic_category")))
  expect_equal(without$num_graduates, with$num_graduates)
  expect_equal(nrow(states), 3)
  expect_false("district_code" %in% names(states))
  expect_true(all(diff(states$graduation_rate[!is.na(states$graduation_rate)]) <= 0))
})

test_that("results larger than one page download as CSV", {
  local_gcd_state()
  seed_grad_schema()
  csv <- paste(
    "year,district_code,school_code,demographic,num_graduates,num_cohort,graduation_rate,district_name,district_census_id,district_type,school_name,demographic_label,demographic_category",
    "2024,660,0103,all,100,110,0.9090909090909091,Fulton County,02280,standard,A School,All,aggregate",
    "2024,660,0104,all,,,,Fulton County,02280,standard,B School,All,aggregate",
    "2024,660,0105,all,3000000000,3000000001,0.99,Fulton County,02280,standard,C School,All,aggregate",
    sep = "\n"
  )
  seen <- character()
  local_routes(list("rows" = function(req) {
    seen <<- c(seen, req$url)
    if (grepl("format=csv", req$url)) {
      return(httr2::response(200, headers = list(`Content-Type` = "text/csv"),
                             body = charToRaw(csv)))
    }
    json_response(list(
      data = list(list(year = 2024, district_code = "660", school_code = "0103",
                       demographic = "all")),
      pagination = list(limit = 1, offset = 0, total = 3, returned = 1, has_more = TRUE),
      meta = list(dataset = "graduation_rate_4_year_cohort", key = "a/b/c",
                  title = "Four-Year Cohort Graduation Rate",
                  advisories = list(list(code = "x", message = "An advisory.")))
    ))
  }))
  expect_snapshot(out <- gcd_rows("graduation_rate_4_year_cohort", district_code = "660"))
  expect_equal(nrow(out), 3)
  expect_identical(out$school_code, c("0103", "0104", "0105"))
  expect_identical(out$num_graduates[1:2], c(100, NA))
  expect_type(out$num_graduates, "double")
  expect_type(out$year, "integer")
  expect_equal(names(out)[1:5], c("year", "district_code", "district_name",
                                  "district_census_id", "district_type"))
  expect_match(seen[1], "limit=10000")
  expect_false(grepl("limit", seen[2]))
  expect_equal(gcd_meta(out)$advisories$code, "x")

  # a cap above one page keeps the first n_max rows of the CSV
  capped <- gcd_rows("graduation_rate_4_year_cohort", district_code = "660",
                     n_max = 10002, quiet = TRUE)
  expect_equal(nrow(capped), 3)
  # n_max within one page asks for that many rows and never downloads CSV
  seen <- character()
  gcd_rows("graduation_rate_4_year_cohort", district_code = "660", n_max = 1, quiet = TRUE)
  expect_length(seen, 1)
  expect_match(seen, "limit=1$")
})

test_that("long filter lists go as POST /query and empty results keep their columns", {
  local_gcd_state()
  seed_grad_schema()
  sent <- NULL
  local_routes(list("graduation_rate_4_year_cohort/query" = function(req) {
    sent <<- req
    json_response(list(
      data = list(),
      pagination = list(limit = 10000, offset = 0, total = 0, returned = 0, has_more = FALSE),
      meta = list(dataset = "graduation_rate_4_year_cohort",
                  omitted_columns = list("school_code", "school_name"),
                  advisories = list())
    ))
  }))
  codes <- sprintf("%07d", seq_len(800))
  out <- gcd_rows("graduation_rate_4_year_cohort", district_code = codes,
                  detail = "districts", year = c(2019, 2024))
  expect_equal(httr2::req_get_method(sent), "POST")
  expect_length(sent$body$data$district_code, 800)
  expect_equal(sent$body$data$year, list("2019", "2024"))
  expect_equal(nrow(out), 0)
  expect_false("school_code" %in% names(out))
  expect_true(all(c("district_name", "graduation_rate") %in% names(out)))
  expect_type(out$graduation_rate, "double")
  expect_equal(nrow(gcd_meta(out)$advisories), 0)
})

test_that("cache = TRUE sends the rows request through the disk cache", {
  local_gcd_state()
  seed_grad_schema()
  paths <- list()
  local_routes(list("rows" = function(req) {
    paths <<- c(paths, list(req$policies$cache_path))
    json_response(list(data = list(), pagination = list(has_more = FALSE), meta = list()))
  }))
  gcd_rows("graduation_rate_4_year_cohort", year = 2024, cache = TRUE)
  withr::local_options(gcd.cache = TRUE)
  gcd_rows("graduation_rate_4_year_cohort", year = 2024)
  gcd_rows("graduation_rate_4_year_cohort", year = 2024, cache = FALSE)
  expect_equal(paths[[1]], gcd_cache_dir())
  expect_equal(paths[[2]], gcd_cache_dir())
  expect_null(paths[[3]])
})

test_that("advisories are silenced by quiet and the option", {
  local_gcd_state()
  seed_grad_schema()
  local_routes(list("rows" = json_response(list(
    data = list(list(year = 2024)),
    pagination = list(has_more = FALSE),
    meta = list(advisories = list(list(code = "a", message = "Watch out.")))
  ))))
  expect_message(gcd_rows("graduation_rate_4_year_cohort"), "Watch out")
  expect_silent(gcd_rows("graduation_rate_4_year_cohort", quiet = TRUE))
  withr::local_options(gcd.quiet = TRUE)
  expect_silent(out <- gcd_rows("graduation_rate_4_year_cohort"))
  expect_equal(gcd_meta(out)$advisories$message, "Watch out.")
})

test_that("gcd_rows() checks its arguments before any request", {
  local_gcd_state()
  expect_snapshot(error = TRUE, gcd_rows("x", "all"))
  expect_snapshot(error = TRUE, gcd_rows("x", limit = 10))
  expect_snapshot(error = TRUE, gcd_rows("x", detail = c("states", "districts")))
  expect_snapshot(error = TRUE, gcd_rows("x", n_max = 0))
  expect_snapshot(error = TRUE, gcd_rows("x", labels = "no"))
  expect_snapshot(error = TRUE, gcd_rows("counties"))
})

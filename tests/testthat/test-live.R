# End-to-end calls against the production API. They run only when
# GCD_LIVE_TESTS=true (the weekly GitHub Actions workflow), never on CRAN
# and never offline, to keep traffic off the platform's usage metric.

skip_if_not_live <- function() {
  skip_if_not(identical(Sys.getenv("GCD_LIVE_TESTS"), "true"), "GCD_LIVE_TESTS is not true")
  skip_on_cran()
  skip_if_offline("georgiacivicdata.org")
}

test_that("live: the catalog, search and a schema", {
  skip_if_not_live()
  local_gcd_state(seed_tables = FALSE)
  catalog <- gcd_datasets()
  expect_gt(nrow(catalog), 100)
  expect_setequal(unique(catalog$kind), c("table", "geometry"))
  expect_gt(nrow(gcd_search("graduation", n = 5)), 0)
  d <- gcd_describe("graduation_rate_4_year_cohort")
  expect_equal(d$key_metric, "graduation_rate")
  expect_true(all(c("districts", "schools", "states") %in% d$detail_levels))
})

test_that("live: rows by name, typed, with metadata", {
  skip_if_not_live()
  local_gcd_state(seed_tables = FALSE)
  out <- gcd_rows("graduation_rate_4_year_cohort", district = "Fulton County",
                  school = "Roswell High School", demographic = "all",
                  year = 2024, quiet = TRUE)
  expect_equal(nrow(out), 1)
  expect_equal(out$school_code, "0191")
  expect_type(out$graduation_rate, "double")
  expect_match(gcd_citation(out), "Georgia Civic Data")
})

test_that("live: a result over 10,000 rows downloads as CSV", {
  skip_if_not_live()
  local_gcd_state(seed_tables = FALSE)
  out <- gcd_rows("graduation_rate_4_year_cohort", year = 2023:2024,
                  detail = "schools", labels = FALSE, quiet = TRUE)
  expect_gt(nrow(out), 10000)
  expect_type(out$year, "integer")
  expect_true(all(nchar(out$school_code) == 4))
})

test_that("live: the disk cache revalidates with the ETag", {
  skip_if_not_live()
  local_gcd_state(seed_tables = FALSE)
  signals <- character()
  record <- function(cnd) signals <<- c(signals, class(cnd)[1])
  withCallingHandlers(
    {
      first <- gcd_rows("employment", county_fips = "13121", year = 2024,
                        cache = TRUE, quiet = TRUE)
      second <- gcd_rows("employment", county_fips = "13121", year = 2024,
                         cache = TRUE, quiet = TRUE)
    },
    httr2_cache_save = record,
    httr2_cache_cached = record,
    httr2_cache_not_modified = record
  )
  expect_true("httr2_cache_save" %in% signals)
  expect_true(any(c("httr2_cache_cached", "httr2_cache_not_modified") %in% signals))
  expect_equal(first, second, ignore_attr = TRUE)
  expect_gt(length(list.files(gcd_cache_dir())), 0)
})

test_that("live: zones, coverage and a located landmark", {
  skip_if_not_live()
  skip_if_not_installed("sf")
  local_gcd_state(seed_tables = FALSE)
  zones <- gcd_school_zones(district_code = "630")
  expect_s3_class(zones, "sf")
  expect_gt(nrow(gcd_school_zone_coverage()), 100)
  here <- gcd_locate(lat = 33.749, lon = -84.388)
  expect_equal(here$geographic_type[1:4], c("county", "tract", "block_group", "school_district"))
  expect_equal(here$geographic_name[1], "Fulton")
})

test_that("live: the State Capitol's address geocodes through the Census", {
  skip_if_not_live()
  local_gcd_state(seed_tables = FALSE)
  out <- gcd_locate(address = "206 Washington St SW, Atlanta, GA 30334")
  expect_equal(unique(out$match_status), "match")
  expect_equal(out$geographic_id[out$geographic_type == "county"], "13121")
})

seed_zone_schema <- function() {
  seed_recorded("m/descg/g/d/school_attendance_zones.json",
                c("datasets", "school_attendance_zones"))
}

zone_columns <- c(
  "year", "district_code", "district_name", "school_code", "school_name",
  "zone_level", "grade_low", "grade_high", "method", "accuracy_class",
  "currency_status", "boundary_vintage", "source_url", "retrieved_on",
  "area_sq_mi", "bbox_xmin", "bbox_ymin", "bbox_xmax", "bbox_ymax",
  "source_school_name"
)

test_that("normalize_grade() accepts the usual spellings", {
  expect_equal(normalize_grade("5"), "05")
  expect_equal(normalize_grade(9), "09")
  expect_equal(normalize_grade("K"), "k")
  expect_equal(normalize_grade("Kindergarten"), "k")
  expect_equal(normalize_grade("Pre-K"), "pk")
  expect_equal(normalize_grade("12"), "12")
  expect_null(normalize_grade(NULL))
  expect_snapshot(error = TRUE, normalize_grade("13"))
  expect_snapshot(error = TRUE, normalize_grade(c("1", "2")))
  expect_snapshot(error = TRUE, check_year1("2027"))
})

test_that("gcd_school_zones() returns zone attributes without sf", {
  skip_if_no_mocks()
  local_gcd_state()
  seed_zone_schema()
  httptest2::with_mock_dir("m/zone", {
    out <- gcd_school_zones(district_code = "630", geometry = FALSE)
  })
  expect_s3_class(out, "tbl_df")
  expect_false(inherits(out, "sf"))
  expect_equal(names(out)[seq_along(zone_columns)], zone_columns)
  expect_type(out$year, "integer")
  expect_s3_class(out$retrieved_on, "Date")
  expect_equal(unique(out$district_name), "Clay County")
  expect_match(attr(out, "note"), "Not an official enrollment determination")
})

test_that("gcd_school_zones() returns sf with geometry", {
  skip_if_no_mocks()
  skip_if_not_installed("sf")
  local_gcd_state()
  seed_zone_schema()
  httptest2::with_mock_dir("m/zoneg", {
    out <- gcd_school_zones(district_code = "630", zone_level = "middle")
  })
  expect_s3_class(out, "sf")
  expect_equal(names(out)[seq_along(zone_columns)], zone_columns)
  expect_equal(sf::st_crs(out)$epsg, 4326L)
  expect_true(all(out$zone_level == "middle"))
  expect_s3_class(out$retrieved_on, "Date")
})

test_that("school names become code filters and exact pairs for zones", {
  local_gcd_state()
  local_test_tables()
  seed_zone_schema()
  sent <- NULL
  local_routes(list("school_attendance_zones/rows" = function(req) {
    sent <<- req$url
    json_response(list(
      data = list(
        list(year = 2027, district_code = "634", school_code = "0282", zone_level = "elementary"),
        list(year = 2027, district_code = "634", school_code = "2052", zone_level = "elementary"),
        list(year = 2027, district_code = "638", school_code = "2052", zone_level = "elementary")
      ),
      count = 3, note = "A note."
    ))
  }))
  out <- gcd_school_zones(school = "Eastside Elementary School",
                          district = c("Coffee County", "Coweta County"),
                          grade = "K", year = 2027, resolution = "full",
                          geometry = FALSE)
  expect_match(sent, "district_code=634,638")
  expect_match(sent, "school_code=0282,2052")
  expect_match(sent, "grade=k")
  expect_match(sent, "resolution=full")
  expect_match(sent, "format=json")
  expect_equal(paste(out$district_code, out$school_code), c("634 0282", "638 2052"))
})

test_that("geometry = TRUE without sf points to geometry = FALSE", {
  local_mocked_bindings(check_installed = function(pkg, reason, call) {
    cli::cli_abort("The package {.pkg {pkg}} is required {reason}", call = call)
  }, .package = "rlang")
  expect_snapshot(error = TRUE, gcd_school_zones(geometry = TRUE))
  expect_snapshot(error = TRUE, gcd_school_zones(geometry = "yes"))
})

test_that("gcd_district_boundaries() fills Department of Defense names", {
  local_gcd_state()
  local_routes(list("school_district_boundaries/rows" = json_response(list(
    data = list(
      list(district_code = NULL, district_census_id = "00002", nces_lea_id = "1300002",
           boundary_type = "dodea", tiger_name = "Fort Benning Schools",
           district_name = NULL),
      list(district_code = "630", district_census_id = "01200", nces_lea_id = "1301200",
           boundary_type = "unified", tiger_name = "Clay County School District",
           district_name = "Clay County")
    ),
    count = 2
  ))))
  out <- gcd_district_boundaries(geometry = FALSE)
  expect_equal(names(out)[1:5], c("district_code", "district_name", "boundary_type",
                                  "district_census_id", "nces_lea_id"))
  expect_equal(out$district_name, c("Fort Benning Schools", "Clay County"))
  expect_true(is.na(out$district_code[1]))
})

test_that("gcd_district_boundaries() reads one district as sf", {
  skip_if_no_mocks()
  skip_if_not_installed("sf")
  local_gcd_state()
  local_test_tables()
  httptest2::with_mock_dir("m/bnd", {
    out <- gcd_district_boundaries(district = "Clay County")
  })
  expect_s3_class(out, "sf")
  expect_equal(out$district_code, "630")
  expect_equal(out$boundary_type, "unified")
})

test_that("gcd_school_zone_status() returns one row per school", {
  skip_if_no_mocks()
  local_gcd_state()
  httptest2::with_mock_dir("m/stat", {
    out <- gcd_school_zone_status(district_code = "630")
  })
  expect_named(out, c("year", "district_code", "district_name", "school_code",
                      "school_name", "zone_status", "zone_levels",
                      "no_zone_category", "reason"))
  expect_type(out$year, "integer")
  expect_true(all(out$district_code == "630"))
  expect_match(attr(out, "note"), "zoned")
})

test_that("gcd_school_zone_status() keeps exact school pairs and empty results", {
  local_gcd_state()
  local_test_tables()
  local_routes(list("school_status" = function(req) {
    if (grepl("zone_status=no_zone", req$url)) {
      return(json_response(list(data = list(), count = 0, note = "n")))
    }
    json_response(list(data = list(
      list(year = 2027, district_code = "660", school_code = "0191", zone_status = "zoned"),
      list(year = 2027, district_code = "660", school_code = "9999", zone_status = "zoned")
    ), count = 2, note = "n"))
  }))
  out <- gcd_school_zone_status(school = "Roswell High School")
  expect_equal(out$school_code, "0191")
  empty <- gcd_school_zone_status(zone_status = "no_zone")
  expect_equal(nrow(empty), 0)
  expect_named(empty, c("year", "district_code", "district_name", "school_code",
                        "school_name", "zone_status", "zone_levels",
                        "no_zone_category", "reason"))
})

test_that("gcd_school_zone_coverage() pivots the per-level columns long", {
  local_gcd_state()
  local_test_tables()
  local_routes(list("coverage" = httr2::response(
    200, headers = list(`Content-Type` = "application/json"),
    body = readBin(test_path("fixtures", "coverage.json"), "raw", 1e6)
  )))
  out <- gcd_school_zone_coverage(district_code = c("601", "630"))
  expect_equal(unique(gcd_school_zone_coverage(district = "Clay County")$district_code), "630")
  expect_equal(nrow(out), 6)
  expect_equal(names(out)[1:13], c(
    "year", "district_code", "district_name", "tier", "status", "zone_level",
    "level_status", "pct_land_area", "pct_population", "zone_count", "methods",
    "accuracy_classes", "reason"
  ))
  expect_false(any(grepl("_(elementary|middle|high)$", names(out))))
  expect_equal(out$zone_level, rep(c("elementary", "middle", "high"), 2))
  expect_type(out$zone_count, "integer")
  clay_high <- out[out$district_code == "630" & out$zone_level == "high", ]
  expect_equal(clay_high$level_status, "served_by_other_district")
  expect_equal(clay_high$served_elsewhere[[1]]$district_code, "720")
  expect_equal(nrow(out$served_elsewhere[[1]]), 0)
  expect_match(attr(out, "note"), "Not an official")
  all_rows <- gcd_school_zone_coverage()
  expect_equal(nrow(all_rows), 9)
})

test_that("gcd_school_zone_coverage(geometry = TRUE) keeps the outlines", {
  skip_if_not_installed("sf")
  local_gcd_state()
  local_routes(list("coverage" = httr2::response(
    200, headers = list(`Content-Type` = "application/geo+json"),
    body = readBin(test_path("fixtures", "coverage.geojson"), "raw", 1e6)
  )))
  out <- gcd_school_zone_coverage(district_code = "630", geometry = TRUE)
  expect_s3_class(out, "sf")
  expect_equal(nrow(out), 3)
  expect_equal(attr(out, "sf_column"), "geometry")
  expect_equal(out$served_elsewhere[[3]]$school_code, "0201")
})

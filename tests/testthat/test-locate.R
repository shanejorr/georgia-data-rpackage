capitol <- function() fixture_json("locate-capitol.json")

test_that("format_grades() writes short grade ranges", {
  expect_equal(format_grades(c("k", "pk", "06", "09", "k", NA), c("05", "05", "08", "12", "k", "05")),
               c("K-5", "PK-5", "6-8", "9-12", "K", NA))
})

test_that("overlapping_zones() finds schools whose grade runs intersect", {
  expect_equal(overlapping_zones(c("k", "03"), c("02", "05"), c("a", "b")), c(FALSE, FALSE))
  expect_equal(overlapping_zones(c("k", "k"), c("05", "05"), c("a", "b")), c(TRUE, TRUE))
  expect_equal(overlapping_zones(c("k", "k"), c("05", "05"), c("a", "a")), c(FALSE, FALSE))
})

test_that("reason_for_level() quotes one level's part of a reason", {
  r <- "Elementary: No map. More text. Middle: Two schools share it."
  expect_equal(reason_for_level(r, "middle"), "Middle: Two schools share it.")
  expect_equal(reason_for_level(r, "elementary"), "Elementary: No map. More text.")
  expect_null(reason_for_level(r, "high"))
  expect_equal(reason_for_level("Plain.", "high"), "Plain.")
  expect_null(reason_for_level(NULL, "high"))
})

test_that("locate_rows() lays out one point's places", {
  lookups <- test_tables()
  out <- locate_rows(capitol(), lookups)
  expect_equal(out$geographic_type, c("county", "tract", "block_group", "school_district",
                                      "elementary_school", "middle_school", "high_school"))
  expect_equal(out$geographic_id, c("13121", "13121003500", "131210035001", "761",
                                    "761-0199", "761-0199", "761-4560"))
  expect_equal(out$geographic_name[1:4], c("Fulton", "Census Tract 35",
                                           "Block Group 1, Census Tract 35, Fulton County",
                                           "Atlanta Public Schools"))
  expect_equal(out$grades, c(NA, NA, NA, NA, "K-5", "6-8", "9-12"))
  expect_true(all(is.na(out$note)))
})

test_that("levels without a zone get a row with a note", {
  r <- capitol()
  r$zones <- r$zones[1]
  r$level_status <- list(elementary = "zoned", middle = "not_available",
                         high = "served_by_other_district")
  r$coverage_reason <- "Middle: No map is published."
  r$served_elsewhere <- list(list(zone_level = "high", district_code = "720",
                                  school_code = "0201",
                                  reason = "Clay County operates no high school."))
  out <- locate_rows(r, test_tables())
  expect_equal(out$geographic_type[5:7], c("elementary_school", "middle_school", "high_school"))
  expect_true(all(is.na(out$geographic_id[6:7])))
  expect_snapshot(cat(out$note[6:7], sep = "\n"))

  r$level_status <- list(elementary = "zoned", middle = "gap", high = "served_by_other_district")
  r$coverage_reason <- NULL
  r$served_elsewhere <- list(list(zone_level = "high", district_code = "720"))
  out <- locate_rows(r, test_tables())
  expect_snapshot(cat(out$note[6:7], sep = "\n"))
  expect_equal(level_note("high", "served_by_other_district", list()),
               "High students here are served by another district.")
  expect_equal(level_note("high", "partial", list()), "High school zone status: partial.")
})

test_that("Department of Defense districts and warnings are noted", {
  r <- capitol()
  r$district <- list(district_code = NULL, district_name = "Fort Benning Schools",
                     boundary_type = "dodea")
  r$coverage_reason <- "Department of Defense (DoDEA) schools serve this area; they are not Georgia public school districts and publish no zones."
  r$zones <- list()
  r$level_status <- list(elementary = "not_available")
  out <- locate_rows(r, test_tables())
  district <- out[out$geographic_type == "school_district", ]
  expect_true(is.na(district$geographic_id))
  expect_equal(district$geographic_name, "Fort Benning Schools")
  expect_match(district$note, "^Department of Defense")
  expect_match(out$note[out$geographic_type == "elementary_school"], "DoDEA")

  r <- capitol()
  r$zones[[3]]$currency_status <- "stale_known_changes"
  r$currency_warning <- "A change is pending."
  r$zones[[2]]$zone_level <- "elementary"
  r$zones[[2]]$school_code <- "0200"
  r$zones[[2]]$grade_low <- "k"
  r$overlap_warning <- "Two zones overlap."
  out <- locate_rows(r, test_tables())
  expect_equal(out$note[out$geographic_type == "high_school"], "A change is pending.")
  expect_equal(out$note[out$geographic_type == "elementary_school"],
               rep("Two zones overlap.", 2))
})

test_that("failures give one row with the reason", {
  expect_equal(locate_rows(list(id = "1", error = list(code = "INVALID_COORDINATES",
                                                        message = "lat/lon out of range")), list())$note,
               "The API couldn't locate this point: lat/lon out of range.")
  expect_equal(locate_rows(list(coverage_status = "outside_georgia"), list())$note,
               "The point is outside Georgia.")
  r <- list(coverage_status = "not_zoned", coverage_reason = "No zone serves pre-K.",
            district = list(district_code = "761", district_name = "Atlanta Public Schools"))
  out <- locate_rows(r, list())
  expect_equal(out$note, "No zone serves pre-K.")
  expect_equal(locate_rows(list(coverage_status = "gap"), list())$note,
               "No place was found for this point.")
})

test_that("gcd_locate() locates points in one POST", {
  skip_if_no_mocks()
  local_gcd_state()
  local_test_tables()
  httptest2::with_mock_dir("m/loc", {
    expect_snapshot(out <- gcd_locate(lat = c(33.749, 36.1627, 200),
                                      lon = c(-84.388, -86.7816, 0)))
    again <- gcd_locate(lat = 33.749, lon = -84.388, id = "capitol", grade = "9")
  })
  expect_named(out, c("id", "lat", "lon", "geographic_type", "geographic_id",
                      "geographic_name", "grades", "note"))
  expect_equal(out$id, c(rep(1L, 7), 2L, 3L))
  expect_equal(out$note[8:9], c("The point is outside Georgia.",
                                "The API couldn't locate this point: lat/lon out of range."))
  expect_match(attr(out, "assignment_note"), "default assignment")
  expect_equal(again$id, rep("capitol", 5))
  expect_equal(again$geographic_type[5], "high_school")
})

test_that("gcd_locate() sends batches and checks the echoed ids", {
  local_gcd_state()
  bodies <- list()
  local_routes(list("locate" = function(req) {
    body <- req$body$data
    bodies[[length(bodies) + 1]] <<- body
    json_response(list(results = lapply(body$points, function(p) {
      list(id = p$id, coverage_status = "outside_georgia",
           assignment_note = "A zone is the default assignment.", note = "Not official.")
    })))
  }))
  out <- locate_points(c(1, 2, 3), c(4, 5, 6), batch_size = 2, grade = "05", year = "2027")
  expect_length(bodies, 2)
  expect_equal(vapply(bodies[[1]]$points, function(p) p$id, ""), c("1", "2"))
  expect_equal(bodies[[2]]$points[[1]]$id, "3")
  expect_equal(bodies[[1]]$grade, "05")
  expect_equal(bodies[[1]]$year, 2027L)
  expect_length(out, 3)

  expect_snapshot(res <- gcd_locate(lat = c(31, NA), lon = c(-83, -84)))
  expect_equal(res$note, c("The point is outside Georgia.", "No coordinates were given."))
  expect_silent(gcd_locate(lat = 31, lon = -83))

  local_routes(list("locate" = json_response(list(results = list(list(id = "9"))))))
  expect_snapshot(error = TRUE, gcd_locate(lat = 31, lon = -83))
})

test_that("gcd_locate() checks its inputs", {
  expect_snapshot(error = TRUE, gcd_locate())
  expect_snapshot(error = TRUE, gcd_locate(lat = 1, lon = 2, address = "x"))
  expect_snapshot(error = TRUE, gcd_locate(lat = 1:2, lon = 1))
  expect_snapshot(error = TRUE, gcd_locate(lat = "33", lon = "-84"))
  expect_snapshot(error = TRUE, gcd_locate(lat = 1, lon = 2, id = 1:2))
  expect_snapshot(error = TRUE, gcd_locate(lat = 1, lon = 2, grade = "13"))
})

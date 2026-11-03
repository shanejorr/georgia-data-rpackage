test_that("gcd_datasets() returns the compact catalog, typed", {
  skip_if_no_mocks()
  local_gcd_state()
  httptest2::with_mock_dir("m/cat", {
    out <- gcd_datasets(main_topic = "immigration")
  })
  expect_s3_class(out, "tbl_df")
  expect_named(out, c("name", "title", "summary", "kind", "main_topic",
                      "detail_levels", "year_min", "year_max"))
  expect_gt(nrow(out), 0)
  expect_true(all(out$main_topic == "immigration"))
  expect_type(out$detail_levels, "list")
  expect_type(out$detail_levels[[1]], "character")
  expect_type(out$year_min, "integer")
  expect_false(any(c("sub_topic", "topic", "key") %in% names(out)))
})

test_that("details = TRUE adds the long columns", {
  skip_if_no_mocks()
  local_gcd_state()
  httptest2::with_mock_dir("m/catf", {
    out <- gcd_datasets(main_topic = "immigration", details = TRUE)
    geo <- gcd_datasets(kind = "geometry", details = TRUE)
  })
  expect_named(out, c("name", "title", "summary", "kind", "main_topic",
                      "detail_levels", "year_min", "year_max", "description",
                      "source", "source_url", "grain", "default_detail",
                      "year_gaps", "update_frequency", "search_aliases_en",
                      "search_aliases_es", "updated_at"))
  expect_s3_class(out$updated_at, "POSIXct")
  expect_type(out$grain[[1]], "character")
  expect_type(out$year_gaps[[1]], "integer")
  expect_type(out$search_aliases_es, "list")
  expect_equal(sort(geo$name), c("school_attendance_zones", "school_district_boundaries"))
  expect_true(all(geo$kind == "geometry"))
  expect_true(all(is.na(geo$updated_at)))
})

test_that("gcd_datasets() checks its arguments", {
  expect_snapshot(error = TRUE, gcd_datasets(kind = "tables"))
  expect_snapshot(error = TRUE, gcd_datasets(main_topic = c("census", "health")))
  expect_snapshot(error = TRUE, gcd_datasets(level = 1))
  expect_snapshot(error = TRUE, gcd_datasets(year = 2019:2020))
  expect_snapshot(error = TRUE, gcd_datasets(details = NA))
})

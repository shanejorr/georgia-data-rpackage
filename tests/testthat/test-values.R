test_that("gcd_values() lists combinations with row counts", {
  skip_if_no_mocks()
  local_gcd_state()
  local_test_tables()
  httptest2::with_mock_dir("m/vals", {
    out <- gcd_values("graduation_rate_4_year_cohort", "demographic",
                      district = "Fulton County", year = 2024, detail = "districts")
  })
  expect_named(out, c("demographic", "n_rows"))
  expect_type(out$n_rows, "integer")
  expect_true("all" %in% out$demographic)
  expect_true(all(diff(out$n_rows) <= 0))
})

test_that("gcd_values() warns at the 500-combination cap and types values", {
  local_gcd_state()
  seed_grad_schema()
  local_routes(list("values" = json_response(list(
    dataset = "graduation_rate_4_year_cohort", columns = list("year", "demographic"),
    total_combinations = 900, truncated = TRUE,
    data = list(list(year = 2024, demographic = "all", count = 10),
                list(year = 2023, demographic = NULL, count = 2))
  ))))
  expect_snapshot(out <- gcd_values("graduation_rate_4_year_cohort",
                                    c("year", "demographic")))
  expect_identical(out$year, c(2024L, 2023L))
  expect_identical(out$demographic, c("all", NA))
  expect_identical(out$n_rows, c(10L, 2L))
})

test_that("gcd_values() needs columns", {
  expect_snapshot(error = TRUE, gcd_values("x"))
  expect_snapshot(error = TRUE, gcd_values("x", character()))
})

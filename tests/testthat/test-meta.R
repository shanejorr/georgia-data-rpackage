test_that("gcd_meta() needs a result from gcd_rows()", {
  expect_snapshot(error = TRUE, gcd_meta(data.frame(a = 1)))
  x <- structure(data.frame(a = 1), gcd_meta = list(dataset = "d"))
  expect_equal(gcd_meta(x), list(dataset = "d"))
})

test_that("gcd_citation() uses the API's citation or builds one", {
  with_citation <- structure(data.frame(a = 1), gcd_meta = list(citation = "Cite me."))
  expect_equal(gcd_citation(with_citation), "Cite me.")
  without <- structure(data.frame(a = 1), gcd_meta = list(
    title = "Unemployment (ACS)", dataset = "employment",
    source = "U.S. Census Bureau, American Community Survey 5-Year Estimates"
  ))
  expect_snapshot(cat(gcd_citation(without)))
  expect_snapshot(error = TRUE, gcd_citation(list(1)))
})

test_that("gcd_citation() takes a dataset name", {
  local_gcd_state()
  seed_grad_schema()
  seed_meta(c("datasets", "school_attendance_zones"),
            list(name = "school_attendance_zones", kind = "geometry",
                 source = "School district attendance-zone maps."))
  seed_meta("datasets", list(data = list(
    list(name = "school_attendance_zones", title = "School Attendance Zones")
  )))
  expect_snapshot({
    cat(gcd_citation("graduation_rate_4_year_cohort"))
    cat(gcd_citation("school_attendance_zones"))
  })
  expect_snapshot(error = TRUE, gcd_citation("counties"))
})

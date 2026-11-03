test_that("normalize_place() ignores case, accents, spacing and 'County'", {
  expect_equal(
    normalize_place(c(" Fulton County ", "FULTON", "fulton  county", "DeKalb")),
    c("fulton", "fulton", "fulton", "dekalb")
  )
  # precomposed and decomposed accents, curly apostrophes
  expect_equal(normalize_place("José Martí"), "jose marti")
  expect_equal(normalize_place("José Martí"), "jose marti")
  expect_equal(normalize_place("O’Neal"), "o'neal")
  expect_equal(normalize_place("Ångström Łódź"), "angstrom lodz")
  # only a trailing "County" is dropped
  expect_equal(normalize_place("County Line Elementary"), "county line elementary")
})

test_that("cli_escape() doubles braces", {
  expect_equal(cli_escape("a {b} c"), "a {{b}} c")
})

test_that("district and county names resolve to codes", {
  local_gcd_state()
  local_test_tables()
  out <- resolve_places(district = c("fulton", "Atlanta Public Schools"),
                        county = "DeKalb County")
  expect_equal(out$district_code, c("660", "761"))
  expect_equal(out$county_fips, "13089")
  expect_null(out$school_pairs)
  expect_equal(resolve_places(), list(district_code = NULL, county_fips = NULL,
                                      school_pairs = NULL, schools = NULL))
})

test_that("former names match", {
  local_gcd_state()
  local_test_tables()
  out <- resolve_places(district = "Brookhaven Innovation Academy")
  expect_equal(out$district_code, "7830613")
  out <- resolve_places(school = "Riverwood High School", district = "Fulton County")
  expect_equal(out$school_pairs, "660-3066")
})

test_that("school names resolve to DISTRICT-SCHOOL pairs", {
  local_gcd_state()
  local_test_tables()
  out <- resolve_places(school = "Roswell High School")
  expect_equal(out$school_pairs, "660-0191")
  expect_null(out$district_code)
  out <- resolve_places(school = "Eastside Elementary School",
                        district = c("Coffee County", "Coweta County"))
  expect_equal(out$school_pairs, c("634-0282", "638-2052"))
  out <- resolve_places(school = "jose marti academy",
                        filters = list(district_code = "644"))
  expect_equal(out$school_pairs, "644-0101")
})

test_that("ambiguous names stop with the candidates", {
  local_gcd_state()
  local_test_tables()
  expect_snapshot(error = TRUE, resolve_places(school = "Eastside Elementary School"))
  expect_snapshot(error = TRUE, resolve_places(school = "Milton High School", district = "Fulton"))
  expect_snapshot(error = TRUE, resolve_places(district = "Sample Academy"))
  err <- tryCatch(resolve_places(school = "Eastside Elementary School"),
                  error = identity)
  expect_s3_class(err, "gcd_error_place_ambiguous")
  expect_s3_class(err, "gcd_error")
  expect_length(err$details$candidates, 2)
})

test_that("unknown names stop with suggestions", {
  local_gcd_state()
  local_test_tables()
  local_routes(list(
    "dimensions/districts/rows" = json_response(list(data = list())),
    "dimensions/schools/rows" = json_response(list(data = list(
      list(school_name = "Roswell High School")
    )))
  ))
  expect_snapshot(error = TRUE, resolve_places(district = "Fultn County"))
  expect_snapshot(error = TRUE, resolve_places(school = "Roswell High", district = "Fulton County"))
  expect_snapshot(error = TRUE, resolve_places(school = "Midtown High School", district = "Fulton County"))
  err <- tryCatch(resolve_places(district = "Fultn"), error = identity)
  expect_s3_class(err, "gcd_error_place_not_found")
  expect_equal(err$details$suggestions, "Fulton County")
})

test_that("a failed suggestion search still gives the not-found error", {
  local_gcd_state()
  local_test_tables()
  local_routes(list("dimensions/counties/rows" = error_response(500, "INTERNAL_ERROR", "boom")))
  expect_snapshot(error = TRUE, resolve_places(county = "Nowhere"))
})

test_that("a code and a name for the same place is an error", {
  local_gcd_state()
  local_test_tables()
  expect_snapshot(error = TRUE, resolve_places(district = "Fulton", filters = list(district_code = "660")))
  expect_snapshot(error = TRUE, resolve_places(county = "Fulton", filters = list(county_fips = "13121")))
  expect_snapshot(error = TRUE, resolve_places(school = "Roswell High School", filters = list(school = "660-0191")))
})

test_that("a name argument needs its code column in the target", {
  local_gcd_state()
  expect_snapshot(error = TRUE, resolve_places(
    school = "Roswell High School", columns = c("year", "county_fips"),
    target = "the dataset \"employment\""
  ))
  expect_snapshot(error = TRUE, resolve_places(district = 1))
})

test_that("near_names() suggests close spellings only", {
  local_gcd_state()
  local_test_tables()
  expect_equal(near_names("Fultn County", "districts", "district_name"), "Fulton County")
  expect_equal(near_names("Zzzzzzzz", "districts", "district_name"), character())
  expect_equal(near_names("Rosewell High School", "schools", "school_name",
                          districts = "660"), "Roswell High School")
})

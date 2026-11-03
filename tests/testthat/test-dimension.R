test_that("gcd_dimension() returns a whole lookup table, cached", {
  skip_if_no_mocks()
  local_gcd_state()
  httptest2::with_mock_dir("m/dim", {
    counties <- gcd_dimension("counties")
    again <- gcd_dimension("counties")
    three <- gcd_dimension("counties", n_max = 3)
  })
  expect_equal(nrow(counties), 159)
  expect_named(counties, c("county_fips", "county_name"))
  expect_identical(counties, again)
  expect_equal(nrow(three), 3)
  expect_equal(counties$county_name[counties$county_fips == "13121"], "Fulton")
})

test_that("gcd_dimension() filters on the server and types from the schema", {
  skip_if_no_mocks()
  local_gcd_state()
  httptest2::with_mock_dir("m/dim2", {
    clay <- gcd_dimension("schools", district_code = "630", active = TRUE)
    found <- gcd_dimension("schools", q = "eastside",
                           columns = c("district_code", "school_code", "school_name"),
                           n_max = 2)
  })
  expect_true(all(clay$district_code == "630"))
  expect_true(all(clay$active))
  expect_type(clay$latitude, "double")
  expect_type(clay$directory_year, "integer")
  expect_type(clay$charter, "logical")
  expect_named(found, c("district_code", "school_code", "school_name"))
  expect_equal(nrow(found), 2)
  expect_true(all(grepl("eastside", found$school_name, ignore.case = TRUE)))
})

test_that("school names become code filters and exact pairs", {
  local_gcd_state()
  local_test_tables()
  seed_recorded("m/descl/g/m/schools.json", c("dimensions", "schools"))
  sent <- NULL
  local_routes(list("dimensions/schools/rows" = function(req) {
    sent <<- req$url
    json_response(list(
      data = list(
        list(district_code = "634", school_code = "0282", school_name = "Eastside Elementary School"),
        list(district_code = "634", school_code = "2052", school_name = "Other"),
        list(district_code = "638", school_code = "2052", school_name = "Eastside Elementary School")
      ),
      pagination = list(has_more = FALSE)
    ))
  }))
  out <- gcd_dimension("schools", school = "Eastside Elementary School",
                       district = c("Coffee County", "Coweta County"),
                       columns = "school_name")
  expect_match(sent, "district_code=634,638")
  expect_match(sent, "school_code=0282,2052")
  expect_match(sent, "columns=school_name,district_code,school_code")
  expect_equal(out$school_name, rep("Eastside Elementary School", 2))
  expect_named(out, "school_name")
})

test_that("gcd_dimension() pages past 10,000 rows", {
  local_gcd_state()
  seed_meta(c("dimensions", "block_groups"), list(
    name = "block_groups",
    columns = list(list(name = "block_group_geoid", type = "string"),
                   list(name = "population_2020", type = "integer"))
  ))
  urls <- character()
  local_routes(list("block_groups/rows" = function(req) {
    urls <<- c(urls, req$url)
    second <- grepl("offset", req$url)
    json_response(list(
      data = list(list(block_group_geoid = if (second) "2" else "1",
                       population_2020 = 5)),
      pagination = list(has_more = !second)
    ))
  }))
  out <- gcd_dimension("block_groups", county_fips = "13121")
  expect_equal(out$block_group_geoid, c("1", "2"))
  expect_identical(out$population_2020, c(5L, 5L))
  expect_match(urls[2], "offset=1")
})

test_that("gcd_dimension() checks names and arguments", {
  local_gcd_state()
  local_test_tables()
  seed_meta(c("dimensions", "counties"), list(
    name = "counties",
    columns = list(list(name = "county_fips", type = "string"),
                   list(name = "county_name", type = "string"))
  ))
  expect_snapshot(error = TRUE, gcd_dimension("counties", school = "Roswell High School"))
  expect_snapshot(error = TRUE, gcd_dimension("counties", q = c("a", "b")))
  expect_snapshot(error = TRUE, gcd_dimension("counties", n_max = -1))
  local_routes(list("dimensions/countys" = error_response(
    404, "DIM_NOT_FOUND", "No lookup table 'countys'",
    list(available = list("districts", "schools", "counties"),
         did_you_mean = list("counties"))
  )))
  expect_snapshot(error = TRUE, gcd_dimension("countys"))
})

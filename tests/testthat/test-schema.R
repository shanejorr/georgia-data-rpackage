test_that("apply_schema_types() types columns from the schema", {
  df <- data.frame(
    year = c("2024", "2025"),
    district_code = c("0103", NA),
    county_fips = c(13121, 13089),
    count = c("10", "3000000000"),
    rate = c("0.9375", ""),
    flag = c("true", "false"),
    day = c("2026-10-02", NA),
    at = c("2026-10-29T20:17:55+00:00", NA),
    joined_name = c(NA, NA),
    stringsAsFactors = FALSE
  )
  df$rate[2] <- NA
  types <- c(year = "integer", district_code = "string", county_fips = "string",
             count = "integer", rate = "number", flag = "boolean",
             day = "date", at = "timestamp")
  out <- apply_schema_types(df, types)
  expect_identical(out$year, c(2024L, 2025L))
  expect_identical(out$district_code, c("0103", NA))
  expect_identical(out$county_fips, c("13121", "13089"))
  expect_type(out$count, "double")
  expect_equal(out$count, c(10, 3e9))
  expect_equal(out$rate, c(0.9375, NA))
  expect_identical(out$flag, c(TRUE, FALSE))
  expect_s3_class(out$day, "Date")
  expect_s3_class(out$at, "POSIXct")
  expect_identical(out$joined_name, c(NA_character_, NA_character_))
})

test_that("integer columns stay integer when they fit", {
  expect_identical(as_integer_safe(c("1", "2", NA)), c(1L, 2L, NA))
  expect_identical(as_integer_safe(c(1, 2.5)), c(1, 2.5))
  expect_identical(as_integer_safe(character()), integer())
})

test_that("as_logical_value() reads JSON, CSV and numeric booleans", {
  expect_identical(as_logical_value(c("true", "FALSE", "x", NA)), c(TRUE, FALSE, NA, NA))
  expect_identical(as_logical_value(c(1, 0)), c(TRUE, FALSE))
  expect_identical(as_logical_value(NA), NA)
})

test_that("unknown columns and list-columns are left alone", {
  df <- tibble::tibble(a = 1:2, l = list(1, 2))
  expect_identical(apply_schema_types(df, c()), df)
})

schema <- list(
  name = "toy",
  columns = list(
    list(name = "year", type = "integer", role = "year"),
    list(name = "district_code", type = "string", role = "fk_district"),
    list(name = "school_code", type = "string", role = "fk_school"),
    list(name = "demographic", type = "string", role = "fk_demographic"),
    list(name = "n", type = "integer", role = "metric")
  ),
  foreign_keys = list(
    list(column = "district_code", attribute_columns_added = list("district_name", "district_type")),
    list(column = "school_code", attribute_columns_added = list("school_name")),
    list(column = "demographic", attribute_columns_added = list("demographic_label"))
  )
)

test_that("label columns come from foreign_keys", {
  expect_equal(label_columns(schema),
               c("district_name", "district_type", "school_name", "demographic_label"))
  types <- row_types(schema)
  expect_equal(types[["district_name"]], "string")
  expect_equal(types[["n"]], "integer")
  expect_equal(code_columns(schema), c("district_code", "school_code", "demographic"))
})

test_that("relocate_labels() puts each label after its code", {
  df <- tibble::tibble(
    year = 2024L, district_code = "660", school_code = "0191", demographic = "all",
    n = 1L, district_name = "Fulton County", district_type = "standard",
    school_name = "Roswell High School", demographic_label = "All"
  )
  out <- relocate_labels(df, schema$foreign_keys)
  expect_named(out, c("year", "district_code", "district_name", "district_type",
                      "school_code", "school_name", "demographic",
                      "demographic_label", "n"))
  no_school <- relocate_labels(df[c("year", "district_code", "n", "district_name")],
                               schema$foreign_keys)
  expect_named(no_school, c("year", "district_code", "district_name", "n"))
})

test_that("drop_empty_codes() drops all-NA code columns only", {
  df <- tibble::tibble(year = 2024L, district_code = c("660", NA),
                       school_code = c(NA_character_, NA), n = c(NA, 1L))
  out <- drop_empty_codes(df, code_columns(schema))
  expect_named(out, c("year", "district_code", "n"))
  expect_named(drop_empty_codes(df[0, ], code_columns(schema)), names(df))
})

test_that("drop_internal() removes sub_topic, topic and key", {
  x <- list(name = "a", sub_topic = "s", topic = "t", key = "k/s/t", title = "T")
  expect_equal(drop_internal(x), list(name = "a", title = "T"))
  expect_equal(drop_internal("x"), "x")
})

test_that("empty_typed() builds a typed zero-row tibble", {
  out <- empty_typed(c("year", "flag", "x"), c(year = "integer", flag = "boolean"))
  expect_equal(nrow(out), 0)
  expect_type(out$year, "integer")
  expect_type(out$flag, "logical")
  expect_type(out$x, "character")
})

test_that("schema_types() reads columns or geometry fields", {
  expect_equal(schema_types(list(fields = list(list(name = "a", type = "date"),
                                               list(name = "b")))),
               c(a = "date", b = "string"))
  expect_equal(schema_types(list()), stats::setNames(character(), character()))
})

test_that("table_schema() points lookup tables and geometry elsewhere", {
  local_gcd_state()
  seed_meta(c("datasets", "school_attendance_zones"), list(kind = "geometry"))
  seed_meta(c("datasets", "school_district_boundaries"), list(kind = "geometry"))
  expect_snapshot(error = TRUE, table_schema("counties", "gcd_rows"))
  expect_snapshot(error = TRUE, table_schema("school_attendance_zones", "gcd_rows"))
  expect_snapshot(error = TRUE, table_schema("school_district_boundaries", "gcd_values"))
  expect_equal(resource_kind("counties"), "lookup")
  expect_equal(resource_kind("school_attendance_zones"), "geometry")
})

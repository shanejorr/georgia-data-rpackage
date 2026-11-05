test_that("gcd_describe() summarizes a dataset", {
  skip_if_no_mocks()
  local_gcd_state()
  httptest2::with_mock_dir("m/desc", {
    d <- gcd_describe("graduation_rate_4_year_cohort")
    cols <- gcd_columns("graduation_rate_4_year_cohort")
    own <- gcd_columns("graduation_rate_4_year_cohort", labels = FALSE)
  })
  expect_s3_class(d, "gcd_description")
  expect_equal(d$kind, "table")
  expect_type(d$years, "integer")
  expect_equal(d$key_metric, "graduation_rate")
  expect_identical(d$columns, cols)
  expect_named(d$filters, c("param", "kind", "values", "multi_value", "has_total",
                            "total_value", "requires_single_value", "nullable"))
  expect_true("district_type" %in% d$filters$param)
  expect_s3_class(d$notes$series_breaks, "tbl_df")
  expect_false(any(c("sub_topic", "topic", "key") %in% names(d$raw)))
  expect_snapshot(print(d))

  expect_named(cols, c("column", "label", "type", "role", "label_of", "unit",
                       "is_key_metric", "metric_component", "nullable",
                       "valid_values", "description", "null_meaning"))
  expect_equal(cols$column[cols$is_key_metric], "graduation_rate")

  # The joined name columns sit right after their codes, as in gcd_rows()
  labels <- c("district_name", "district_census_id", "district_type",
              "school_name", "demographic_label", "demographic_category")
  expect_equal(cols$column[cols$role %in% "label"], labels)
  expect_equal(own$column, setdiff(cols$column, labels))
  expect_true(all(is.na(own$label_of)))
  at <- match(c("district_code", "school_code", "demographic"), cols$column)
  expect_equal(cols$column[at + 1], c("district_name", "school_name", "demographic_label"))
  expect_equal(cols$label_of[cols$column == "demographic_category"], "demographic")
  expect_equal(unique(cols$type[cols$role %in% "label"]), "string")
  expect_false(any(cols$is_key_metric[cols$role %in% "label"]))
  expect_match(cols$description[cols$column == "school_name"], ".")
  expect_true("race" %in% cols$valid_values[[which(cols$column == "demographic_category")]])
  expect_equal(cols$metric_component[cols$column == "num_cohort"], "denominator")
  expect_type(cols$valid_values, "list")
  expect_true("all" %in% cols$valid_values[[which(cols$column == "demographic")]])
})

test_that("label columns fall back to a plain description", {
  local_gcd_state()
  seed_meta(c("dimensions", "counties"), list(
    name = "counties",
    columns = list(list(name = "county_fips", type = "string", role = "key"))
  ))
  schema <- list(
    columns = list(
      list(name = "year", type = "integer", role = "year"),
      list(name = "county_fips", type = "string", role = "fk_county"),
      list(name = "rate", type = "number", role = "metric")
    ),
    foreign_keys = list(list(column = "county_fips", target_object = "counties",
                             attribute_columns_added = list("county_name")))
  )
  cols <- add_label_columns(columns_tibble(schema, "table"), schema)
  expect_equal(cols$column, c("year", "county_fips", "county_name", "rate"))
  expect_equal(cols$description[3], "Joined from the counties lookup table.")
  expect_true(is.na(cols$nullable[3]))
  expect_equal(cols$valid_values[[3]], character())
  expect_snapshot(error = TRUE, gcd_columns("infant_deaths", labels = NA))
})

test_that("gcd_describe() lists columns that need one value", {
  skip_if_no_mocks()
  local_gcd_state()
  httptest2::with_mock_dir("m/desc2", {
    d <- gcd_describe("ccrpi_content_mastery")
  })
  single <- d$filters$param[d$filters$requires_single_value %in% TRUE]
  expect_true("grade_cluster" %in% single)
  expect_snapshot(print(d))
})

test_that("gcd_describe() and gcd_columns() read lookup tables", {
  skip_if_no_mocks()
  local_gcd_state()
  httptest2::with_mock_dir("m/descl", {
    d <- gcd_describe("schools")
    cols <- gcd_columns("schools")
  })
  expect_equal(d$kind, "lookup")
  expect_equal(d$primary_key, c("district_code", "school_code"))
  expect_true(all(c("key", "enum", "boolean", "search") %in% d$filters$kind))
  expect_equal(cols$role[cols$column == "school_code"], "key")
  expect_true(all(is.na(cols$label)))
  expect_false(any(cols$is_key_metric))
  expect_equal(cols$valid_values[[which(cols$column == "locale")]],
               c("city", "suburb", "town", "rural"))
  expect_snapshot(print(d))
})

test_that("gcd_describe() reads geometry datasets", {
  skip_if_no_mocks()
  local_gcd_state()
  httptest2::with_mock_dir("m/descg", {
    d <- gcd_describe("school_attendance_zones")
  })
  expect_equal(d$kind, "geometry")
  expect_true("retrieved_on" %in% d$columns$column)
  expect_equal(d$columns$type[d$columns$column == "retrieved_on"], "date")
  expect_equal(d$filters$values[[which(d$filters$param == "zone_level")]],
               c("elementary", "middle", "high"))
  expect_true(d$filters$multi_value[d$filters$param == "district_code"])
  expect_true(is_string(d$notes$assignment_note))
  expect_snapshot(print(d))
})

test_that("every declared note is kept and printed", {
  schema <- list(
    name = "toy", title = "Toy Data", summary = "A toy.", source = "Somewhere",
    available_years = list(2022L, 2024L), year_gaps = list(2023L),
    detail_levels = list("counties", "states"), default_detail = "counties",
    grain = list("year", "county_fips"), key_metric = "rate",
    columns = list(list(name = "rate", type = "number", role = "metric")),
    filters = list(list(param = "payer", kind = "categorical",
                        values = list("a", "b"), requires_single_value = FALSE)),
    limitations = "Small samples.",
    year_meaning = "The year the survey ended.",
    null_semantics = list(suppressed_to_null = TRUE, zero_is_real = FALSE),
    series_breaks = list(list(year = 2024L, reason = "New method.", metrics = list("rate"))),
    non_additive = list(list(column = "race", reason = "Groups overlap.", values = list("a", "b"))),
    partitions = list(list(column = "payer", share = "share", reason = "Shares add to 1.")),
    pooled_rates = list(list(column = "rate", numerator = "events", denominator = "pop", scale = 1000)),
    year_window = list(years = 3L, overlapping = TRUE),
    value_implications = list(list(when = list(born = list("pr")),
                                   implies = list(citizen = "native"),
                                   reason = "Born in Puerto Rico implies native.")),
    pooled_min_count = list(count = 20L, reason = "Under 20 events is withheld.")
  )
  d <- structure(describe_table(schema), class = "gcd_description")
  expect_named(d$notes, c("limitations", "year_meaning", "null_semantics",
                          "series_breaks", "non_additive", "partitions",
                          "pooled_rates", "year_window", "value_implications",
                          "pooled_min_count"))
  expect_type(d$notes$non_additive$values, "list")
  expect_snapshot(print(d))
})

test_that("gcd_contract() returns the contract or writes its YAML", {
  skip_if_no_mocks()
  local_gcd_state()
  path <- withr::local_tempfile(fileext = ".yaml")
  httptest2::with_mock_dir("m/ctr", {
    contract <- gcd_contract("graduation_rate_4_year_cohort")
    expect_invisible(out <- gcd_contract("graduation_rate_4_year_cohort", file = path))
  })
  expect_equal(contract$kind, "DataContract")
  expect_equal(contract$name, "graduation_rate_4_year_cohort")
  expect_equal(out, path)
  expect_match(readLines(path, n = 1), "^apiVersion:")
})

test_that("gcd_contract() refuses lookup tables and geometry without a contract", {
  local_gcd_state()
  seed_meta(c("datasets", "school_district_boundaries"),
            list(name = "school_district_boundaries", kind = "geometry",
                 endpoints = list(rows = "/rows")))
  local_routes(list(
    "school_district_boundaries/contract" = error_response(
      404, "TOPIC_NOT_FOUND", "No dataset 'school_district_boundaries'"),
    "datasets/nope/contract" = error_response(
      404, "TOPIC_NOT_FOUND", "No dataset 'nope'",
      list(did_you_mean = list("employment"))),
    "datasets/nope" = error_response(
      404, "TOPIC_NOT_FOUND", "No dataset 'nope'",
      list(did_you_mean = list("employment")))
  ))
  expect_snapshot(error = TRUE, gcd_contract("nope", file = tempfile()))
  expect_snapshot(error = TRUE, gcd_contract("counties"))
  expect_snapshot(error = TRUE, gcd_contract("school_district_boundaries"))
  expect_snapshot(error = TRUE, gcd_contract("x", file = 1))
})

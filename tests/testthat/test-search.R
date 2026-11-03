test_that("gcd_search() ranks datasets", {
  skip_if_no_mocks()
  local_gcd_state()
  httptest2::with_mock_dir("m/srch", {
    out <- gcd_search("graduation rate", n = 3)
  })
  expect_named(out, c("rank", "name", "title", "summary", "main_topic",
                      "detail_levels", "year_min", "year_max", "score",
                      "matched_on", "matched_columns"))
  expect_equal(out$rank, 1:3)
  expect_type(out$score, "double")
  expect_type(out$matched_on, "list")
  expect_true("graduation_rate_4_year_cohort" %in% out$name)
  expect_true(attr(out, "confidence") %in% c("high", "medium", "low"))
  expect_named(attr(out, "retrieval"), c("mode", "reranked"))
  expect_false(any(c("sub_topic", "topic", "key") %in% names(out)))
})

test_that("gcd_search() reports low confidence, keyword fallback and lookup tables", {
  local_gcd_state()
  local_routes(list("search" = json_response(list(
    query = "school addresses", matches = list(), match_count = 0,
    total_matches = 0, truncated = FALSE, confidence = "low",
    retrieval = list(mode = "keyword", reranked = FALSE),
    dimension_matches = list(
      list(name = "schools", matched_on = list("aliases")),
      list(name = "counties", matched_on = list())
    )
  ))))
  expect_snapshot(out <- gcd_search("school addresses"))
  expect_equal(nrow(out), 0)
  expect_named(out, c("rank", "name", "title", "summary", "main_topic",
                      "detail_levels", "year_min", "year_max", "score",
                      "matched_on", "matched_columns"))
  withr::local_options(gcd.quiet = TRUE)
  expect_silent(gcd_search("school addresses"))
})

test_that("gcd_search() checks its arguments", {
  expect_snapshot(error = TRUE, gcd_search(""))
  expect_snapshot(error = TRUE, gcd_search(c("a", "b")))
  expect_snapshot(error = TRUE, gcd_search("jobs", n = 0))
  expect_snapshot(error = TRUE, gcd_search("jobs", n = 101))
  expect_snapshot(error = TRUE, gcd_search("jobs", year = "2024"))
})

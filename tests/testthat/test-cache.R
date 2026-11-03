test_that("cache_get_or_set() computes once", {
  local_gcd_state()
  calls <- 0
  f <- function() {
    calls <<- calls + 1
    "value"
  }
  expect_equal(cache_get_or_set("k", f()), "value")
  expect_equal(cache_get_or_set("k", f()), "value")
  expect_equal(calls, 1)
})

test_that("first_time() is TRUE once per key", {
  local_gcd_state()
  expect_true(first_time("note"))
  expect_false(first_time("note"))
})

test_that("gcd_cache_dir() defaults to the user cache folder", {
  skip_if_not_installed("withr")
  withr::local_options(gcd.cache_dir = NULL)
  expect_equal(gcd_cache_dir(), tools::R_user_dir("georgiacivicdata", "cache"))
})

test_that("gcd_cache_clear() empties the session and disk caches", {
  local_gcd_state()
  cache_get_or_set("k", 1)
  first_time("note")
  dir.create(gcd_cache_dir(), showWarnings = FALSE, recursive = TRUE)
  writeLines("x", file.path(gcd_cache_dir(), "file"))
  expect_invisible(gcd_cache_clear())
  expect_length(ls(the$meta), 0)
  expect_length(ls(the$shown), 0)
  expect_false(dir.exists(gcd_cache_dir()))
  expect_null(gcd_cache_clear())
})

test_that("compact() drops NULLs", {
  expect_equal(compact(list(a = 1, b = NULL, c = "x")), list(a = 1, c = "x"))
})

test_that("records_to_tibble() simplifies scalars and keeps arrays as lists", {
  records <- list(
    list(name = "a", n = 1L, levels = list("x", "y"), missing = NULL),
    list(name = "b", n = NULL, levels = list(), extra = TRUE)
  )
  out <- records_to_tibble(records, list_cols = "levels")
  expect_named(out, c("name", "n", "levels", "missing", "extra"))
  expect_equal(out$name, c("a", "b"))
  expect_equal(out$n, c(1L, NA))
  expect_equal(out$levels, list(c("x", "y"), character()))
  expect_equal(out$extra, c(NA, TRUE))
})

test_that("records_to_tibble() fixes fields and handles no records", {
  out <- records_to_tibble(list(list(a = 1)), fields = c("a", "b"))
  expect_named(out, c("a", "b"))
  expect_true(is.na(out$b))
  empty <- records_to_tibble(list(), fields = c("a", "l"), list_cols = "l")
  expect_equal(nrow(empty), 0)
  expect_type(empty$l, "list")
})

test_that("flatten_value() turns scalar arrays into vectors", {
  expect_equal(flatten_value(list(1L, 2L)), 1:2)
  expect_equal(flatten_value(NULL), character())
  expect_equal(flatten_value(list(list(a = 1))), list(list(a = 1)))
})

test_that("move_after() and order_columns() reorder columns", {
  df <- data.frame(a = 1, b = 2, c = 3, d = 4)
  expect_named(move_after(df, c("d"), "a"), c("a", "d", "b", "c"))
  expect_named(move_after(df, "z", "a"), names(df))
  expect_named(move_after(df, "b", "z"), names(df))
  expect_named(order_columns(df, c("c", "z", "a")), c("c", "a", "b", "d"))
})

test_that("parse_utc() reads ISO 8601 timestamps with offsets", {
  out <- parse_utc(c("2026-10-29T20:17:55+00:00", "2026-10-29T15:17:55-05:00",
                     "2026-10-29T20:17:55Z", "2026-10-29 20:17:55", NA))
  expect_s3_class(out, "POSIXct")
  expect_equal(attr(out, "tzone"), "UTC")
  expected <- as.POSIXct("2026-10-29 20:17:55", tz = "UTC")
  expect_equal(out[1:4], rep(expected, 4))
  expect_true(is.na(out[5]))
})

test_that("argument checks name the argument", {
  f <- function(x) check_flag(x)
  expect_snapshot(error = TRUE, f("yes"))
  g <- function(name) check_name_arg(name)
  expect_snapshot(error = TRUE, g(c("a", "b")))
  h <- function(x) check_chr(x)
  expect_null(h(NULL))
  expect_snapshot(error = TRUE, h(c("a", NA)))
  k <- function(n_max) check_n_max(n_max)
  expect_snapshot(error = TRUE, k(0))
  expect_invisible(k(Inf))
})

test_that("is_quiet() reads the argument and the option", {
  skip_if_not_installed("withr")
  withr::local_options(gcd.quiet = NULL)
  expect_false(is_quiet())
  expect_true(is_quiet(TRUE))
  withr::local_options(gcd.quiet = TRUE)
  expect_true(is_quiet())
})

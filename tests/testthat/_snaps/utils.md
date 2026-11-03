# argument checks name the argument

    Code
      f("yes")
    Condition
      Error in `f()`:
      ! `x` must be `TRUE` or `FALSE`.

---

    Code
      g(c("a", "b"))
    Condition
      Error in `g()`:
      ! `name` must be a single string, such as a dataset name.

---

    Code
      h(c("a", NA))
    Condition
      Error in `h()`:
      ! `x` must be a character vector of non-empty, non-missing values.

---

    Code
      k(0)
    Condition
      Error in `k()`:
      ! `n_max` must be a single number of at least 1, or `Inf`.


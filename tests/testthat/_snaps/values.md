# gcd_values() warns at the 500-combination cap and types values

    Code
      out <- gcd_values("graduation_rate_4_year_cohort", c("year", "demographic"))
    Condition
      Warning:
      Only the 2 most common combinations are shown (the API returns at most 500 of 900).
      i Add filters to narrow them.

# gcd_values() needs columns

    Code
      gcd_values("x")
    Condition
      Error in `gcd_values()`:
      ! argument "columns" is missing, with no default

---

    Code
      gcd_values("x", character())
    Condition
      Error in `gcd_values()`:
      ! `columns` must be a character vector of non-empty, non-missing values.


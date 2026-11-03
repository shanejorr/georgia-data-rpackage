# gcd_rows() returns typed rows with names beside codes

    Code
      out <- gcd_rows("graduation_rate_4_year_cohort", district = "Fulton County",
        school = "Roswell High School", year = 2024, demographic = c("all", "black"))
    Message
      i Demographic groups overlap across categories and may overlap within a category (active_duty can be a subset of military_connected). Read the dataset's definitions and non_additive declarations. Use the published `all` total when available, never add it to its subgroups. Counts reconcile only for complete, disjoint groups; subgroup rates generally do not add to the overall rate.

# results larger than one page download as CSV

    Code
      out <- gcd_rows("graduation_rate_4_year_cohort", district_code = "660")
    Message
      i Downloading 3 rows as CSV.
      i An advisory.

# gcd_rows() checks its arguments before any request

    Code
      gcd_rows("x", "all")
    Condition
      Error in `gcd_rows()`:
      ! Every filter in `...` must be named.
      i For example `subject = "mathematics"` or `district_code = "660"`.

---

    Code
      gcd_rows("x", limit = 10)
    Condition
      Error in `gcd_rows()`:
      ! `limit` can't be given as a filter.
      i The package chooses the page size and format; use `n_max` to cap rows.

---

    Code
      gcd_rows("x", detail = c("states", "districts"))
    Condition
      Error in `gcd_rows()`:
      ! `detail` must be one detail level, such as "districts".
      i To combine levels, call once per level and bind the rows.

---

    Code
      gcd_rows("x", n_max = 0)
    Condition
      Error in `gcd_rows()`:
      ! `n_max` must be a single number of at least 1, or `Inf`.

---

    Code
      gcd_rows("x", labels = "no")
    Condition
      Error in `gcd_rows()`:
      ! `labels` must be `TRUE` or `FALSE`.

---

    Code
      gcd_rows("counties")
    Condition
      Error in `gcd_rows()`:
      ! "counties" is a lookup table, not a dataset.
      i Use `gcd_dimension("counties")` to get its rows.


# gcd_dimension() checks names and arguments

    Code
      gcd_dimension("counties", school = "Roswell High School")
    Condition
      Error in `gcd_dimension()`:
      ! `school` doesn't apply: the lookup table "counties" has no district_code and school_code columns.
      i Check the columns with `gcd_columns()`.

---

    Code
      gcd_dimension("counties", q = c("a", "b"))
    Condition
      Error in `gcd_dimension()`:
      ! `q` must be a single string.

---

    Code
      gcd_dimension("counties", n_max = -1)
    Condition
      Error in `gcd_dimension()`:
      ! `n_max` must be a single number of at least 1, or `Inf`.

---

    Code
      gcd_dimension("countys")
    Condition
      Error in `gcd_dimension()`:
      ! No lookup table 'countys'
      i Did you mean: "counties"?
      i Available: "districts", "schools", and "counties".


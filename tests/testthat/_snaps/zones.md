# normalize_grade() accepts the usual spellings

    Code
      normalize_grade("13")
    Condition
      Error:
      ! `grade` must be one of "pk", "k", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", and "12".
      i "5" and "K" are accepted too.

---

    Code
      normalize_grade(c("1", "2"))
    Condition
      Error:
      ! `grade` must be one grade, such as "k", "05" or `9`.

---

    Code
      check_year1("2027")
    Condition
      Error:
      ! `year` must be a single year, such as `2027` (the 2026-27 school year).

# geometry = TRUE without sf points to geometry = FALSE

    Code
      gcd_school_zones(geometry = TRUE)
    Condition
      Error in `gcd_school_zones()`:
      ! The package sf is required to return geometry (or use `geometry = FALSE`).

---

    Code
      gcd_school_zones(geometry = "yes")
    Condition
      Error in `gcd_school_zones()`:
      ! `geometry` must be `TRUE` or `FALSE`.


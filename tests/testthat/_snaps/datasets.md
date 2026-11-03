# gcd_datasets() checks its arguments

    Code
      gcd_datasets(kind = "tables")
    Condition
      Error in `gcd_datasets()`:
      ! `kind` must be one of "table" or "geometry", not "tables".
      i Did you mean "table"?

---

    Code
      gcd_datasets(main_topic = c("census", "health"))
    Condition
      Error in `gcd_datasets()`:
      ! `main_topic` must be a single string, such as "education".

---

    Code
      gcd_datasets(level = 1)
    Condition
      Error in `gcd_datasets()`:
      ! `level` must be a single string, such as "schools".

---

    Code
      gcd_datasets(year = 2019:2020)
    Condition
      Error in `gcd_datasets()`:
      ! `year` must be a single year, such as `2024`.

---

    Code
      gcd_datasets(details = NA)
    Condition
      Error in `gcd_datasets()`:
      ! `details` must be `TRUE` or `FALSE`.


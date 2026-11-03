# encode_values() writes NA, logicals, numbers and dates as text

    Code
      encode_values(list(1), "subject")
    Condition
      Error:
      ! Filter `subject` must be a character, numeric, logical or Date vector, not a list.

# encode_years() sends runs as ranges and the rest as lists

    Code
      encode_years("2024")
    Condition
      Error:
      ! `year` must be a vector of whole years, such as `2024` or `2019:2024`.

---

    Code
      encode_years(2024.5)
    Condition
      Error:
      ! `year` must be a vector of whole years, such as `2024` or `2019:2024`.

# encode_filters() refuses unnamed, empty, reserved and list filters

    Code
      encode_filters(list("all"))
    Condition
      Error:
      ! Every filter in `...` must be named.
      i For example `subject = "mathematics"` or `district_code = "660"`.

---

    Code
      encode_filters(list(subject = character()))
    Condition
      Error:
      ! Filter `subject` is empty; give at least one value or leave it out.

---

    Code
      encode_filters(list(limit = 5))
    Condition
      Error:
      ! `limit` can't be given as a filter.
      i The package chooses the page size and format; use `n_max` to cap rows.

---

    Code
      encode_filters(list(school = "761-0199"))
    Condition
      Error:
      ! Use `school_id` for schools as "DISTRICT-SCHOOL" codes.
      i `school` takes school names.

---

    Code
      encode_filters(list(subject = list("a")))
    Condition
      Error:
      ! Filter `subject` must be a vector, not a list.

---

    Code
      encode_filters(stats::setNames(list(1, 2), c("a", "a")))
    Condition
      Error:
      ! Filter `a` is given more than once.

# check_query_args() wants one detail level

    Code
      check_query_args(c("states", "districts"), NULL, NULL)
    Condition
      Error:
      ! `detail` must be one detail level, such as "districts".
      i To combine levels, call once per level and bind the rows.

---

    Code
      check_query_args(NULL, c("year", NA), NULL)
    Condition
      Error:
      ! `columns` must be a character vector of non-empty, non-missing values.


# table_schema() points lookup tables and geometry elsewhere

    Code
      table_schema("counties", "gcd_rows")
    Condition
      Error:
      ! "counties" is a lookup table, not a dataset.
      i Use `gcd_dimension("counties")` to get its rows.

---

    Code
      table_schema("school_attendance_zones", "gcd_rows")
    Condition
      Error:
      ! "school_attendance_zones" is a geometry dataset, which `gcd_rows()` doesn't read.
      i Use `gcd_school_zones()` instead.

---

    Code
      table_schema("school_district_boundaries", "gcd_values")
    Condition
      Error:
      ! "school_district_boundaries" is a geometry dataset, which `gcd_values()` doesn't read.
      i Use `gcd_district_boundaries()` instead.


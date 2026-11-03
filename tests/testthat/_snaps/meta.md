# gcd_meta() needs a result from gcd_rows()

    Code
      gcd_meta(data.frame(a = 1))
    Condition
      Error in `gcd_meta()`:
      ! `x` carries no Georgia Civic Data metadata.
      i Metadata comes with results of `gcd_rows()`; many dplyr verbs drop it.
      i `gcd_citation()` also takes a dataset name.

# gcd_citation() uses the API's citation or builds one

    Code
      cat(gcd_citation(without))
    Output
      Unemployment (ACS). Georgia Civic Data (georgiacivicdata.org), CC BY 4.0. https://georgiacivicdata.org/api/v1/datasets/employment. Original source: U.S. Census Bureau, American Community Survey 5-Year Estimates.

---

    Code
      gcd_citation(list(1))
    Condition
      Error in `gcd_citation()`:
      ! `x` must be a result of `gcd_rows()` or a dataset name.

# gcd_citation() takes a dataset name

    Code
      cat(gcd_citation("graduation_rate_4_year_cohort"))
    Output
      Four-Year Cohort Graduation Rate. Georgia Civic Data (georgiacivicdata.org), CC BY 4.0. https://georgiacivicdata.org/api/v1/datasets/graduation_rate_4_year_cohort. Original source: Governor's Office of Education and Workforce Strategy (GOEWS, formerly GOSA).
    Code
      cat(gcd_citation("school_attendance_zones"))
    Output
      School Attendance Zones. Georgia Civic Data (georgiacivicdata.org), CC BY 4.0. https://georgiacivicdata.org/api/v1/datasets/school_attendance_zones. Original source: School district attendance-zone maps.

---

    Code
      gcd_citation("counties")
    Condition
      Error in `gcd_citation()`:
      ! "counties" is a lookup table; cite the dataset that uses it.


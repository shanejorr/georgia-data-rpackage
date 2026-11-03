# ambiguous names stop with the candidates

    Code
      resolve_places(school = "Eastside Elementary School")
    Condition
      Error:
      ! "Eastside Elementary School" names schools in 2 districts.
      i Add `district` (or `district_code`) to pick one.
      * 634-0282: Eastside Elementary School (Coffee County, active)
      * 638-2052: Eastside Elementary School (Coweta County, active)

---

    Code
      resolve_places(school = "Milton High School", district = "Fulton")
    Condition
      Error:
      ! "Milton High School" matches more than one school.
      i Use `school_id` with one "DISTRICT-SCHOOL" code.
      * 660-0106: Milton High School (Fulton County, active)
      * 660-2060: Milton High School (Fulton County, inactive)

---

    Code
      resolve_places(district = "Sample Academy")
    Condition
      Error:
      ! "Sample Academy" matches more than one district.
      i Use `district_code` with one of these codes.
      * 9901: Sample Academy
      * 9902: Other Academy

# unknown names stop with suggestions

    Code
      resolve_places(district = "Fultn County")
    Condition
      Error:
      ! No district named "Fultn County".
      i Did you mean: "Fulton County"?
      i Names match exactly (ignoring case and accents); browse with `gcd_dimension("districts", q = "fultn")`.

---

    Code
      resolve_places(school = "Roswell High", district = "Fulton County")
    Condition
      Error:
      ! No school named "Roswell High" in Fulton County (660).
      i Did you mean: "Roswell High School"?
      i Names match exactly (ignoring case and accents); browse with `gcd_dimension("schools", q = "roswell high")`.

---

    Code
      resolve_places(school = "Midtown High School", district = "Fulton County")
    Condition
      Error:
      ! No school named "Midtown High School" in Fulton County (660).
      i A school with that name is in district "761".
      i Did you mean: "Roswell High School"?
      i Names match exactly (ignoring case and accents); browse with `gcd_dimension("schools", q = "midtown high school")`.

# a failed suggestion search still gives the not-found error

    Code
      resolve_places(county = "Nowhere")
    Condition
      Error:
      ! No county named "Nowhere".
      i Names match exactly (ignoring case and accents); browse with `gcd_dimension("counties", q = "nowhere")`.

# a code and a name for the same place is an error

    Code
      resolve_places(district = "Fulton", filters = list(district_code = "660"))
    Condition
      Error:
      ! Give `district` or `district_code`, not both.

---

    Code
      resolve_places(county = "Fulton", filters = list(county_fips = "13121"))
    Condition
      Error:
      ! Give `county` or `county_fips`, not both.

---

    Code
      resolve_places(school = "Roswell High School", filters = list(school = "660-0191"))
    Condition
      Error:
      ! Give `school` or `school_id`, not both.

# a name argument needs its code column in the target

    Code
      resolve_places(school = "Roswell High School", columns = c("year",
        "county_fips"), target = "the dataset \"employment\"")
    Condition
      Error:
      ! `school` doesn't apply: the dataset "employment" has no district_code and school_code columns.
      i Check the columns with `gcd_columns()`.

---

    Code
      resolve_places(district = 1)
    Condition
      Error:
      ! `district` must be a character vector of non-empty, non-missing values.


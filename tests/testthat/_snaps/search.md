# gcd_search() reports low confidence, keyword fallback and lookup tables

    Code
      out <- gcd_search("school addresses")
    Message
      ! Nothing in the catalog may fit this query.
      i Search fell back to keywords only, so matches by meaning are missing.
      i Lookup tables that match: "schools". See `gcd_dimension()`.

# gcd_search() checks its arguments

    Code
      gcd_search("")
    Condition
      Error in `gcd_search()`:
      ! `query` must be a single, non-empty string.

---

    Code
      gcd_search(c("a", "b"))
    Condition
      Error in `gcd_search()`:
      ! `query` must be a single, non-empty string.

---

    Code
      gcd_search("jobs", n = 0)
    Condition
      Error in `gcd_search()`:
      ! `n` must be a whole number from 1 to 100.

---

    Code
      gcd_search("jobs", n = 101)
    Condition
      Error in `gcd_search()`:
      ! `n` must be a whole number from 1 to 100.

---

    Code
      gcd_search("jobs", year = "2024")
    Condition
      Error in `gcd_search()`:
      ! `year` must be a single year, such as `2024`.


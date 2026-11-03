# 429 and gateway errors are retried, honoring Retry-After

    Code
      wait <- gcd_retry_after(httr2::response(429, headers = list(`Retry-After` = "7")))
    Message
      i The API's rate limit was reached; retrying in 7 seconds.
    Code
      wait
    Output
      [1] 7
    Code
      wait <- gcd_retry_after(httr2::response(503))
    Message
      i The server is busy (HTTP 503); retrying shortly.
    Code
      wait
    Output
      [1] NA

# API error envelopes become classed conditions

    Code
      get(c("datasets", "graduation_rate", "rows"))
    Condition
      Error in `get()`:
      ! No dataset 'graduation_rate'
      i Did you mean: "ccrpi_graduation_rate" and "graduation_rate_4_year_cohort"?

---

    Code
      get(c("datasets", "counties", "contract"))
    Condition
      Error in `get()`:
      ! No dataset 'counties'
      i 'counties' is a lookup table: /api/v1/dimensions/counties

---

    Code
      get(c("dimensions", "countys"))
    Condition
      Error in `get()`:
      ! No lookup table 'countys'
      i Available: "counties" and "tracts".

---

    Code
      get(c("old", "path"))
    Condition
      Error in `get()`:
      ! Gone
      i Moved to </api/v1/datasets>.

---

    Code
      get("locate")
    Condition
      Error in `get()`:
      ! unknown grade; use pk, k or 01-12
      i Valid values: "pk", "k", and "01".

---

    Code
      get(c("datasets", "slow", "rows"))
    Condition
      Error in `get()`:
      ! The Georgia Civic Data API couldn't answer (HTTP 503).
      x The query took too long
      i Try again in a few minutes.

---

    Code
      get(c("datasets", "busy", "rows"))
    Condition
      Error in `get()`:
      ! The Georgia Civic Data API's rate limit was reached.
      i Try again in 30 seconds.

---

    Code
      get(c("datasets", "html", "rows"))
    Condition
      Error in `get()`:
      ! The Georgia Civic Data API couldn't answer (HTTP 502).
      x Bad Gateway
      i Try again in a few minutes.

# a transport failure is gcd_error_unavailable

    Code
      gcd_get_json("datasets")
    Condition
      Error:
      ! Couldn't reach the Georgia Civic Data API.
      i Check your internet connection, or try again later.
      Caused by error in `httr2::req_perform()`:
      ! Could not resolve host

# Census errors name the Census geocoder

    Code
      abort_service_error(resp, service = "census")
    Condition
      Error:
      ! The U.S. Census geocoder returned an error (HTTP 503).
      i Try again later.

---

    Code
      abort_unavailable(simpleError("x"), service = "census")
    Condition
      Error:
      ! Couldn't reach the U.S. Census geocoder.
      i Check your internet connection, or try again later.
      Caused by error:
      ! x


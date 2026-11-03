# levels without a zone get a row with a note

    Code
      cat(out$note[6:7], sep = "\n")
    Output
      No middle school zone has been collected for this district yet. Middle: No map is published.
      Clay County operates no high school.

---

    Code
      cat(out$note[6:7], sep = "\n")
    Output
      This point lies in no middle school zone.
      High students here are served by district 720.

# gcd_locate() locates points in one POST

    Code
      out <- gcd_locate(lat = c(33.749, 36.1627, 200), lon = c(-84.388, -86.7816, 0))
    Message
      i A zone is the default assignment, not the only option: a Georgia student may attend another public school by transfer, or a charter, magnet or other choice school. See attendance_rules for the main ways.

# gcd_locate() sends batches and checks the echoed ids

    Code
      res <- gcd_locate(lat = c(31, NA), lon = c(-83, -84))
    Message
      i A zone is the default assignment.

---

    Code
      gcd_locate(lat = 31, lon = -83)
    Condition
      Error in `gcd_locate()`:
      ! The API's location results didn't match the points sent.

# gcd_locate() checks its inputs

    Code
      gcd_locate()
    Condition
      Error in `gcd_locate()`:
      ! Give `lat` and `lon`, or `address`.

---

    Code
      gcd_locate(lat = 1, lon = 2, address = "x")
    Condition
      Error in `gcd_locate()`:
      ! Give `lat` and `lon`, or `address`, not both.

---

    Code
      gcd_locate(lat = 1:2, lon = 1)
    Condition
      Error in `gcd_locate()`:
      ! `lat` and `lon` must be numeric vectors of the same length.

---

    Code
      gcd_locate(lat = "33", lon = "-84")
    Condition
      Error in `gcd_locate()`:
      ! `lat` and `lon` must be numeric vectors of the same length.

---

    Code
      gcd_locate(lat = 1, lon = 2, id = 1:2)
    Condition
      Error in `gcd_locate()`:
      ! `id` must be a vector with one value per input (1).

---

    Code
      gcd_locate(lat = 1, lon = 2, grade = "13")
    Condition
      Error in `gcd_locate()`:
      ! `grade` must be one of "pk", "k", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", and "12".
      i "5" and "K" are accepted too.


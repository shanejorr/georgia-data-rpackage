# address_input() takes one-line addresses or a data frame

    Code
      address_input(data.frame(street = "x"))
    Condition
      Error:
      ! A data frame `address` needs columns street, city, state, and zip.
      x Missing: city, state, and zip.

---

    Code
      address_input(data.frame(street = character(), city = character(), state = character(),
      zip = character()))
    Condition
      Error:
      ! `address` has no rows.

---

    Code
      address_input(1)
    Condition
      Error:
      ! `address` must be a character vector of one-line addresses, or a data frame with street, city, state and zip.

# gcd_locate(address = ) geocodes locally, then sends points only

    Code
      out <- gcd_locate(address = c("206 Washington St SW, Atlanta, GA 30334",
        "55 Trinity Ave SW, Atlanta, GA 30303", "1 Nowhere Blvd, Nocity, GA",
        "10 Main St, Somewhere, GA", ""), id = c("capitol", "city_hall", "nowhere",
        "tie", "blank"))
    Message
      i A zone is the default assignment, not the only option: a Georgia student may attend another public school by transfer, or a charter, magnet or other choice school. See attendance_rules for the main ways.

# a Census failure is a classed error that never echoes the address

    Code
      gcd_locate(address = "206 Washington St SW, Atlanta, GA 30334")
    Condition
      Error in `gcd_locate()`:
      ! The U.S. Census geocoder returned an error (HTTP 500).
      i Try again later.


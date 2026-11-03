census_text <- paste(
  '"2","55 Trinity Ave SW, Atlanta, GA, 30303","Match","Exact","55 TRINITY AVE SW, ATLANTA, GA, 30303","-84.390279998653,33.747923442489","17344323","R"',
  '"1","206 Washington St SW, Atlanta, GA 30334, , , ","Match","Non_Exact","206 WASHINGTON ST SW, ATLANTA, GA, 30334","-84.388565089734,33.74979815619","17344749","L"',
  '"3","1 Nowhere Blvd, Nocity, GA, ","No_Match"',
  '"4","10 Main St, Somewhere, GA, ","Tie"',
  sep = "\n"
)

test_that("address_input() takes one-line addresses or a data frame", {
  one <- address_input(c("206 Washington St SW, Atlanta, GA 30334", " ", NA))
  expect_equal(one$street, c("206 Washington St SW, Atlanta, GA 30334", NA, NA))
  expect_true(all(is.na(one$city)))
  df <- data.frame(street = c("206 Washington St SW", NA), city = "Atlanta",
                   state = "GA", zip = c("30334", ""))
  two <- address_input(df)
  expect_equal(two$address, c("206 Washington St SW, Atlanta, GA 30334", NA))
  expect_equal(two$zip, c("30334", NA))
  expect_equal(paste_address("1 A St", NA, "GA", NA), "1 A St, GA")
  expect_snapshot(error = TRUE, address_input(data.frame(street = "x")))
  expect_snapshot(error = TRUE, address_input(data.frame(street = character(), city = character(),
                                                         state = character(), zip = character())))
  expect_snapshot(error = TRUE, address_input(1))
})

test_that("census_csv() quotes every field", {
  rows <- tibble::tibble(street = 'A "B" St, Suite 1', city = NA, state = "GA", zip = NA)
  expect_equal(census_csv(7, rows), '"7","A ""B"" St, Suite 1","","GA",""')
})

test_that("parse_census() reads matches, misses and ties", {
  out <- parse_census(census_text)
  expect_equal(out$id, c("2", "1", "3", "4"))
  expect_equal(out$match_status, c("match", "match", "no_match", "tie"))
  expect_equal(out$match_type, c("exact", "non_exact", NA, NA))
  expect_equal(out$lat[1:2], c(33.747923442489, 33.74979815619))
  expect_equal(out$lon[2], -84.388565089734)
  expect_true(all(is.na(out$lat[3:4])))
  expect_equal(nrow(parse_census("")), 0)
})

test_that("census_geocode() uploads a batch and joins results back by id", {
  uploads <- list()
  local_routes(list("geocoding.geo.census.gov" = function(req) {
    uploads[[length(uploads) + 1]] <<- req
    httr2::response(200, headers = list(`Content-Type` = "text/plain"),
                    body = charToRaw(census_text))
  }))
  input <- address_input(c("206 Washington St SW, Atlanta, GA 30334",
                           "55 Trinity Ave SW, Atlanta, GA 30303",
                           "1 Nowhere Blvd, Nocity, GA", "10 Main St, Somewhere, GA", NA))
  out <- census_geocode(input)
  expect_length(uploads, 1)
  expect_equal(uploads[[1]]$body$type, "multipart")
  expect_equal(uploads[[1]]$body$data$benchmark, "Public_AR_Current")
  expect_match(uploads[[1]]$url, "locations/addressbatch$")
  expect_equal(out$match_status, c("match", "match", "no_match", "tie", NA))
  expect_equal(out$lat[1], 33.74979815619)
  expect_equal(out$matched_address[2], "55 TRINITY AVE SW, ATLANTA, GA, 30303")
})

test_that("large address lists are split into Census-sized batches", {
  local_mocked_bindings(census_batch_max = 2)
  sizes <- integer()
  local_routes(list("geocoding.geo.census.gov" = function(req) {
    lines <- readLines(req$body$data$addressFile$path)
    sizes <<- c(sizes, length(lines))
    ids <- sub('^"([0-9]+)".*$', "\\1", lines)
    httr2::response(200, body = charToRaw(paste0('"', ids, '","x","No_Match"', collapse = "\n")))
  }))
  out <- census_geocode(address_input(paste("Address", 1:5)))
  expect_equal(sizes, c(2L, 2L, 1L))
  expect_equal(out$match_status, rep("no_match", 5))
})

test_that("gcd_locate(address = ) geocodes locally, then sends points only", {
  local_gcd_state()
  local_test_tables()
  sent <- NULL
  local_routes(list(
    "geocoding.geo.census.gov" = httr2::response(200, body = charToRaw(census_text)),
    "georgiacivicdata.org/api/v1/locate" = function(req) {
      sent <<- req$body$data
      res <- fixture_json("locate-capitol.json")
      json_response(list(results = lapply(sent$points, function(p) {
        res$id <- p$id
        res
      })))
    }
  ))
  expect_snapshot(out <- gcd_locate(
    address = c("206 Washington St SW, Atlanta, GA 30334",
                "55 Trinity Ave SW, Atlanta, GA 30303",
                "1 Nowhere Blvd, Nocity, GA", "10 Main St, Somewhere, GA", ""),
    id = c("capitol", "city_hall", "nowhere", "tie", "blank")
  ))
  expect_named(out, c("id", "address", "match_status", "match_type", "matched_address",
                      "lat", "lon", "geographic_type", "geographic_id",
                      "geographic_name", "grades", "note"))
  expect_equal(vapply(sent$points, function(p) p$id, ""), c("1", "2"))
  expect_false(any(grepl("Washington|Trinity", jsonlite::toJSON(sent))))
  expect_equal(unique(out$id), c("capitol", "city_hall", "nowhere", "tie", "blank"))
  expect_equal(out$note[out$id %in% c("nowhere", "tie", "blank")], c(
    "The U.S. Census geocoder found no match for this address.",
    "The U.S. Census geocoder found more than one possible match for this address.",
    "No address was given."
  ))
})

test_that("a Census failure is a classed error that never echoes the address", {
  local_routes(list("geocoding.geo.census.gov" = httr2::response(500)))
  expect_snapshot(error = TRUE, gcd_locate(address = "206 Washington St SW, Atlanta, GA 30334"))
  local_routes(list("geocoding.geo.census.gov" = function(req) {
    rlang::catch_cnd(rlang::abort("timeout", class = "httr2_failure"))
  }))
  err <- tryCatch(gcd_locate(address = "206 Washington St SW, Atlanta, GA 30334"),
                  error = identity)
  expect_s3_class(err, "gcd_error_unavailable")
  expect_false(grepl("Washington", conditionMessage(err)))
})

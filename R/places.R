# Places by name: one shared resolver turns district, school and county
# names into codes before any data request.

#' Letters folded to ASCII when comparing names (precomposed Latin letters,
#' curly quotes and dashes). Written as escapes so the source stays ASCII;
#' `chartr()` gives the same result on every platform, unlike `iconv()`
#' transliteration.
#' @noRd
fold_from <- paste0(
  "\u00c0\u00c1\u00c2\u00c3\u00c4\u00c5\u00c7\u00c8\u00c9\u00ca\u00cb\u00cc",
  "\u00cd\u00ce\u00cf\u00d1\u00d2\u00d3\u00d4\u00d5\u00d6\u00d9\u00da\u00db",
  "\u00dc\u00dd\u00e0\u00e1\u00e2\u00e3\u00e4\u00e5\u00e7\u00e8\u00e9\u00ea",
  "\u00eb\u00ec\u00ed\u00ee\u00ef\u00f1\u00f2\u00f3\u00f4\u00f5\u00f6\u00f9",
  "\u00fa\u00fb\u00fc\u00fd\u00ff\u0100\u0101\u0102\u0103\u0104\u0105\u0106",
  "\u0107\u0108\u0109\u010a\u010b\u010c\u010d\u010e\u010f\u0112\u0113\u0114",
  "\u0115\u0116\u0117\u0118\u0119\u011a\u011b\u011c\u011d\u011e\u011f\u0120",
  "\u0121\u0122\u0123\u0124\u0125\u0128\u0129\u012a\u012b\u012c\u012d\u012e",
  "\u012f\u0130\u0134\u0135\u0136\u0137\u0139\u013a\u013b\u013c\u013d\u013e",
  "\u0143\u0144\u0145\u0146\u0147\u0148\u014c\u014d\u014e\u014f\u0150\u0151",
  "\u0154\u0155\u0156\u0157\u0158\u0159\u015a\u015b\u015c\u015d\u015e\u015f",
  "\u0160\u0161\u0162\u0163\u0164\u0165\u0168\u0169\u016a\u016b\u016c\u016d",
  "\u016e\u016f\u0170\u0171\u0172\u0173\u0174\u0175\u0176\u0177\u0178\u0179",
  "\u017a\u017b\u017c\u017d\u017e\u01a0\u01a1\u01af\u01b0\u01cd\u01ce\u01cf",
  "\u01d0\u01d1\u01d2\u01d3\u01d4\u01d5\u01d6\u01d7\u01d8\u01d9\u01da\u01db",
  "\u01dc\u01de\u01df\u01e0\u01e1\u01e6\u01e7\u01e8\u01e9\u01ea\u01eb\u01ec",
  "\u01ed\u01f0\u01f4\u01f5\u01f8\u01f9\u01fa\u01fb\u0200\u0201\u0202\u0203",
  "\u0204\u0205\u0206\u0207\u0208\u0209\u020a\u020b\u020c\u020d\u020e\u020f",
  "\u0210\u0211\u0212\u0213\u0214\u0215\u0216\u0217\u0218\u0219\u021a\u021b",
  "\u021e\u021f\u0226\u0227\u0228\u0229\u022a\u022b\u022c\u022d\u022e\u022f",
  "\u0230\u0231\u0232\u0233\u00d8\u00f8\u0110\u0111\u0141\u0142\u0131\u0126",
  "\u0127\u2018\u2019\u02bc\u2013\u2014"
)
fold_to <- paste0(
  "AAAAAACEEEEI",
  "IIINOOOOOUUU",
  "UYaaaaaaceee",
  "eiiiinooooou",
  "uuuyyAaAaAaC",
  "cCcCcCcDdEeE",
  "eEeEeEeGgGgG",
  "gGgHhIiIiIiI",
  "iIJjKkLlLlLl",
  "NnNnNnOoOoOo",
  "RrRrRrSsSsSs",
  "SsTtTtUuUuUu",
  "UuUuUuWwYyYZ",
  "zZzZzOoUuAaI",
  "iOoUuUuUuUuU",
  "uAaAaGgKkOoO",
  "ojGgNnAaAaAa",
  "EeEeIiIiOoOo",
  "RrRrUuUuSsTt",
  "HhAaEeOoOoOo",
  "OoYyOoDdLliH",
  "h'''--"
)

#' Normalize a place name for exact matching
#'
#' Ignores case, accents, surrounding and repeated whitespace, and a
#' trailing " County" (so "Fulton County", "fulton" and " FULTON " match).
#' @noRd
normalize_place <- function(x) {
  x <- enc2utf8(as.character(x))
  x <- gsub("[̀-ͯ]", "", x, perl = TRUE)
  x <- chartr(fold_from, fold_to, x)
  x <- tolower(x)
  x <- gsub("[[:space:]]+", " ", trimws(x))
  sub(" county$", "", x)
}

#' Escape cli braces in text that goes into a bullet verbatim
#' @noRd
cli_escape <- function(x) {
  gsub("}", "}}", gsub("{", "{{", x, fixed = TRUE), fixed = TRUE)
}

#' The matching index of a lookup table: one row per (row, normalized name),
#' covering the current name and every former name
#' @noRd
name_index <- function(table, name_col) {
  cache_get_or_set(paste0("index:", name_col), {
    current <- table[[name_col]]
    former <- if ("former_names" %in% names(table)) {
      table$former_names
    } else {
      rep(NA_character_, nrow(table))
    }
    names <- lapply(seq_len(nrow(table)), function(i) {
      x <- current[[i]]
      if (!is.na(former[[i]]) && nzchar(former[[i]])) {
        x <- c(x, strsplit(former[[i]], "; ", fixed = TRUE)[[1]])
      }
      unique(normalize_place(x[!is.na(x)]))
    })
    data.frame(
      row = rep(seq_len(nrow(table)), lengths(names)),
      name = unlist(names),
      stringsAsFactors = FALSE
    )
  })
}

#' Rows of a lookup table whose current or former name matches exactly
#' @noRd
match_place_rows <- function(input, table, name_col) {
  index <- name_index(table, name_col)
  sort(unique(index$row[index$name == normalize_place(input)]))
}

#' Turn place names into codes
#'
#' @param district,school,county Name vectors (or `NULL`).
#' @param filters The encoded filters, to read codes given alongside.
#' @param columns The columns of the target dataset or table; a name
#'   argument whose code column is missing is an error before any request.
#' @param target How to name the target in errors ("dataset {.val x}").
#' @returns A list: `district_code`, `county_fips`, `school_pairs`
#'   ("DISTRICT-SCHOOL") and `schools` (a data frame of the pairs).
#' @noRd
resolve_places <- function(district = NULL, school = NULL, county = NULL,
                           filters = list(), columns = NULL, target = NULL,
                           call = rlang::caller_env()) {
  check_chr(district, arg = "district", call = call)
  check_chr(school, arg = "school", call = call)
  check_chr(county, arg = "county", call = call)
  out <- list(district_code = NULL, county_fips = NULL, school_pairs = NULL,
              schools = NULL)
  if (is.null(district) && is.null(school) && is.null(county)) {
    return(out)
  }
  check_code_or_name(district, filters$district_code, "district", "district_code", call)
  check_code_or_name(county, filters$county_fips, "county", "county_fips", call)
  check_code_or_name(school, filters$school_code, "school", "school_code", call)
  check_code_or_name(school, filters$school, "school", "school_id", call)
  if (!is.null(columns)) {
    check_place_columns(district, "district", "district_code", columns, target, call)
    check_place_columns(county, "county", "county_fips", columns, target, call)
    check_place_columns(school, "school", c("district_code", "school_code"),
                        columns, target, call)
  }

  district_codes <- NULL
  if (!is.null(district)) {
    district_codes <- resolve_simple(district, "districts", "district_name",
                                     "district_code", "district", call)
  }
  if (!is.null(county)) {
    out$county_fips <- resolve_simple(county, "counties", "county_name",
                                      "county_fips", "county", call)
  }
  if (!is.null(school)) {
    context <- unique(c(district_codes, filters$district_code))
    schools <- resolve_schools(school, context, call)
    out$schools <- schools
    out$school_pairs <- paste(schools$district_code, schools$school_code, sep = "-")
  } else {
    out$district_code <- district_codes
  }
  out
}

#' Code or name, not both, for one kind of place
#' @noRd
check_code_or_name <- function(name, code, name_arg, code_arg, call) {
  if (!is.null(name) && !is.null(code)) {
    cli::cli_abort(
      "Give {.arg {name_arg}} or {.arg {code_arg}}, not both.",
      call = call
    )
  }
}

#' A name argument needs its code column in the target
#' @noRd
check_place_columns <- function(name, arg, needs, columns, target, call) {
  if (is.null(name)) {
    return(invisible())
  }
  missing <- setdiff(needs, columns)
  if (length(missing)) {
    target <- target %||% "This dataset"
    abort_gcd(
      c("{.arg {arg}} doesn't apply: {target} has no {.field {missing}} column.",
        i = "Check the columns with {.fn gcd_columns}."),
      code = "place_not_applicable",
      call = call
    )
  }
}

#' Resolve district or county names to codes (one code per name)
#' @noRd
resolve_simple <- function(names, table_name, name_col, key, arg, call) {
  table <- lookup_table(table_name, call = call)
  codes <- character()
  for (input in unique(names)) {
    rows <- match_place_rows(input, table, name_col)
    if (!length(rows)) {
      abort_place_not_found(input, arg, table_name, name_col, call = call)
    }
    hits <- unique(table[[key]][rows])
    if (length(hits) > 1) {
      lines <- sprintf("%s: %s", table[[key]][rows], table[[name_col]][rows])
      abort_place_ambiguous(
        input, arg, lines,
        hint = "Use {.arg {key}} with one of these codes.",
        key = key, call = call
      )
    }
    codes <- c(codes, hits)
  }
  unique(codes)
}

#' Resolve school names to (district, school) pairs
#'
#' A name must identify one school per district: with no district given it
#' must exist in one district only, and within a district two schools with
#' one name (an old and a new one) are ambiguous.
#' @noRd
resolve_schools <- function(names, districts, call) {
  tbl <- lookup_table("schools", call = call)
  pairs <- tbl[0, c("district_code", "school_code")]
  for (input in unique(names)) {
    rows <- match_place_rows(input, tbl, "school_name")
    in_context <- if (length(districts)) {
      rows[tbl$district_code[rows] %in% districts]
    } else {
      rows
    }
    if (!length(in_context)) {
      abort_place_not_found(input, "school", "schools", "school_name",
                            districts = districts,
                            elsewhere = unique(tbl$district_code[rows]),
                            call = call)
    }
    hits <- tbl[in_context, , drop = FALSE]
    per_district <- table(hits$district_code)
    if (length(per_district) > 1 && !length(districts)) {
      abort_place_ambiguous(
        input, "school", school_lines(hits),
        hint = "Add {.arg district} (or {.arg district_code}) to pick one.",
        n_districts = length(per_district),
        call = call
      )
    }
    if (any(per_district > 1)) {
      abort_place_ambiguous(
        input, "school", school_lines(hits),
        hint = "Use {.arg school_id} with one {.str DISTRICT-SCHOOL} code.",
        call = call
      )
    }
    pairs <- rbind(pairs, hits[c("district_code", "school_code")])
  }
  unique(pairs)
}

#' Candidate lines for a school error
#' @noRd
school_lines <- function(hits) {
  districts <- lookup_table("districts")
  dname <- districts$district_name[match(hits$district_code, districts$district_code)]
  active <- if ("active" %in% names(hits)) {
    ifelse(is.na(hits$active), "", ifelse(hits$active, ", active", ", inactive"))
  } else {
    ""
  }
  sprintf("%s-%s: %s (%s%s)", hits$district_code, hits$school_code,
          hits$school_name, dname, active)
}

#' No exact match for a place name
#' @noRd
abort_place_not_found <- function(input, arg, table_name, name_col,
                                  districts = NULL, elsewhere = character(),
                                  call = rlang::caller_env()) {
  what <- switch(arg, district = "district", county = "county", "school")
  lead <- "No {what} named {.val {input}}."
  bullets <- character()
  if (length(districts)) {
    lead <- "No school named {.val {input}} in {cli::qty(districts)}district{?s} {.val {districts}}."
    if (length(elsewhere)) {
      bullets <- c(bullets, i = "A school with that name is in {cli::qty(elsewhere)}district{?s} {.val {elsewhere}}.")
    }
  }
  suggestions <- place_suggestions(input, table_name, name_col, districts)
  if (!length(suggestions)) {
    suggestions <- near_names(input, table_name, name_col, districts)
  }
  if (length(suggestions)) {
    bullets <- c(bullets, i = "Did you mean: {.val {suggestions}}?")
  }
  q <- sub(" county$", "", tolower(trimws(input)))
  bullets <- c(
    bullets,
    i = "Names match exactly (ignoring case and accents); browse with {.code gcd_dimension({.str {table_name}}, q = {.str {q}})}."
  )
  abort_gcd(c(lead, bullets), code = "place_not_found",
            details = list(input = input, suggestions = suggestions),
            call = call)
}

#' More than one match for a place name
#' @noRd
abort_place_ambiguous <- function(input, arg, lines, hint, n_districts = NULL,
                                  key = NULL, call = rlang::caller_env()) {
  lead <- if (is.null(n_districts)) {
    "{.val {input}} matches more than one {arg}."
  } else {
    "{.val {input}} names schools in {n_districts} districts."
  }
  shown <- utils::head(lines, 10)
  bullets <- stats::setNames(cli_escape(shown), rep("*", length(shown)))
  if (length(lines) > length(shown)) {
    more <- length(lines) - length(shown)
    bullets <- c(bullets, " " = "... and {more} more.")
  }
  abort_gcd(c(lead, i = hint, bullets), code = "place_ambiguous",
            details = list(input = input, candidates = lines),
            call = call)
}

#' Near names from the lookup table's text search (best effort)
#' @noRd
place_suggestions <- function(input, table_name, name_col, districts = NULL) {
  q <- sub(" county$", "", trimws(input), ignore.case = TRUE)
  words <- strsplit(q, "[[:space:]]+")[[1]]
  queries <- unique(c(q, words[order(-nchar(words))][1]))
  for (text in queries[nchar(queries) >= 3]) {
    query <- list(q = text, limit = "5", columns = name_col)
    if (length(districts) && table_name == "schools") {
      query$district_code <- districts
    }
    found <- tryCatch(
      gcd_get_json(c("dimensions", table_name, "rows"), query = query),
      error = function(e) NULL
    )
    names <- unique(unlist(lapply(found$data, function(r) r[[name_col]])))
    if (length(names)) {
      return(names)
    }
  }
  character()
}

#' Close spellings from the cached lookup table (suggestions only: a
#' place is never matched this way)
#' @noRd
near_names <- function(input, table_name, name_col, districts = NULL) {
  tbl <- tryCatch(lookup_table(table_name), error = function(e) NULL)
  if (is.null(tbl)) {
    return(character())
  }
  if (length(districts) && "district_code" %in% names(tbl)) {
    tbl <- tbl[tbl$district_code %in% districts, ]
  }
  names <- unique(tbl[[name_col]][!is.na(tbl[[name_col]])])
  if (!length(names)) {
    return(character())
  }
  target <- normalize_place(input)
  dist <- as.vector(utils::adist(target, normalize_place(names)))
  limit <- max(2, floor(nchar(target) * 0.25))
  keep <- which(dist <= limit)
  names[keep[order(dist[keep])]][seq_len(min(3, length(keep)))]
}

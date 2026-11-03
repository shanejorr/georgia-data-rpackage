---
title: "R package for the Georgia Civic Data API: user-facing functions"
date: 2026-11-02
---

# R package for the Georgia Civic Data API: user-facing functions

Recommendations for the exported functions of an R wrapper around the
Georgia Civic Data REST API (`https://georgiacivicdata.org/api/v1`). Scope is
the user-facing surface only: function names, parameters, outputs and
behavior. Internal helpers and the choice of imports are left for later,
except where an implementation choice changes what the user sees.

Everything below was checked against the live API on 2026-11-02
(name-keyed `v1` routes). This version folds in the follow-up decisions:
names by default, name arguments for places, no `recommended` argument,
fewer lookup-table functions, an opt-in disk cache, no base URL option,
and a new long shape for `gcd_locate()`.

## 1. Recommendation at a glance

Thirteen main exported functions in five groups, all prefixed `gcd_`.

**Find data**

- `gcd_datasets()`: the catalog, one row per dataset.
- `gcd_search()`: ranked dataset search from plain words.

**Understand a dataset**

- `gcd_describe()`: everything about one dataset or lookup table.
- `gcd_columns()`: the column dictionary as a tidy table.
- `gcd_contract()`: the raw ODCS data contract.

**Get data**

- `gcd_rows()`: the core function. Filtered rows as a tibble, with
  names beside codes.
- `gcd_values()`: which category combinations exist, with row counts.

**Lookup tables**

- `gcd_dimension()`: the rows of one lookup table (schools, districts,
  counties, tracts, block groups, demographic groups), with attributes
  such as addresses, coordinates and locale.

**Geography and school zones**

- `gcd_school_zones()`: attendance-zone polygons.
- `gcd_district_boundaries()`: school district outlines.
- `gcd_school_zone_status()`: per-school zone status.
- `gcd_school_zone_coverage()`: per-district collection coverage.
- `gcd_locate()`: points or addresses to the county, tract, block
  group, district and schools they fall in, one row per place.

Plus three small utilities: `gcd_meta()` and `gcd_citation()` (metadata
carried on results) and `gcd_cache_clear()`.

**Dropped since the first draft:** `gcd_dimensions()` (it only listed six
fixed tables) and `gcd_add_labels()` (names now come by default).

**Not wrapped** (reasons in section 9): `/resolve`, `POST /query`,
`/download`, `/aggregate`, `/openapi.json`, `/attendance_rules`, the
single-address and GET forms of `/locate`, `/` and `/healthz`. Two of
these (`/query`, `/download`) are still used inside the package, never
exported.

## 2. Package-wide conventions

### Naming

- **Package name:** `georgiacivicdata`. It matches the domain and public
  name, and it is free of the generic "georgia" names already on CRAN.
- **Prefix:** `gcd_` on every export. Typing `gcd_` lists the whole
  surface in RStudio's autocomplete, and it avoids clashes with dplyr
  and others (a bare `rows()` or `search()` would clash).
- **Code arguments match API parameter names** (`district_code`,
  `county_fips`, `detail`, `year`) so the API docs, the Data Explorer URLs
  and the R calls read the same. **Name arguments** (`district`,
  `school`, `county`) sit beside them (section 2, "Places by name").

### Return types

- **Tabular results are tibbles.** Never a raw parsed JSON list unless
  the content is inherently nested (a schema, a contract).
- **Geometry results are `sf` objects** (with an option to get the
  attributes alone as a tibble, which needs no `sf`).
- **One row per observation.** Where the API returns wide per-level
  columns (zone coverage), the package pivots them long.
- **Nested values become list-columns** only where flattening would lose
  meaning (`detail_levels`, `valid_values`, `matched_columns`).

### Names and codes together

Every result that identifies a place carries **both its code and its
name**: `district_code` with `district_name`, `school_code` with
`school_name`, `county_fips` with `county_name`, `tract_geoid` with
`tract_name`, `demographic` with `demographic_label`. Names are the
default because people read names. Codes stay because names alone are
not safe identifiers:

- **School names repeat.** 174 elementary and high school names belong
  to more than one school; "Eastside Elementary School" and "Northside
  Elementary School" are each in 6 districts. Without codes, those
  schools can't be told apart, and joining on the name merges them.
- **Names change.** The lookup tables keep `former_names`. A school
  renamed in 2019 has two names across a 2015-2024 series but one code.
- **Joins run on codes.** Linking two datasets, or linking to Census
  data through `district_census_id`, `county_fips` and `tract_geoid`,
  needs the codes. People bringing their own GaDOE or Census data hold
  codes too.

### Places by name

Every function that takes `district_code`, `school_code` or
`county_fips` also takes `district`, `school` and `county`: names, which
the package turns into codes before calling the API (the API's filters
take codes only). That covers `gcd_rows()`, `gcd_values()`,
`gcd_dimension()`, `gcd_school_zones()`, `gcd_district_boundaries()`,
`gcd_school_zone_status()` and `gcd_school_zone_coverage()`.

```r
gcd_rows("graduation_rate_4_year_cohort",
         district = "Fulton County",
         school = "Milton High School")
gcd_rows("employment", county = c("Fulton", "DeKalb"))
```

How matching works, the same in every function (one shared internal
resolver):

- **Exact match only**, ignoring case, accents and a trailing "County",
  against current and former names, using the lookup tables (cached for
  the session). No fuzzy matching: a fuzzy match that silently picks the
  wrong place is worse than an error.
- **No match:** an error suggesting near names (from the lookup table's
  text search).
- **More than one match:** an error listing the candidates with their
  codes. Nothing is guessed.
- **`school` needs a district** whenever the name exists in more than one
  district. "Eastside Elementary School" alone stops with a list of its 6
  districts. This mirrors the API's own rule that `school_code` needs one
  `district_code`.
- **Counties are easy:** 159 unique names.
- **Tracts and block groups stay code-only.** Their names ("Census Tract
  35") aren't useful identifiers.
- **Codes still work.** For any one place, give its code or its name,
  not both.

### Column types

The package reads each dataset's schema first and types columns from
it, never from guessing:

- Codes stay **character**: `district_code` "601", `school_code` "0103",
  `county_fips` "13121", tract and block group GEOIDs. Leading zeros
  must survive. (This is why CSV can't be read with default `readr`
  guessing.)
- `year` is **integer**.
- Counts are integer (double where they can exceed R's integer range).
- Proportions stay on the **0-1 scale** as published (0.9375, not 93.75).
- Date and boolean categoricals become `Date` and `logical`.

### Missing values

A NULL metric in the API is `NA` in R. For most datasets this means
**suppressed for privacy, not zero**. The schema's `null_semantics` says
which, and `gcd_rows()` surfaces the API's advisory about it (below).

### Metadata travels with the data

Every tibble from `gcd_rows()` carries an attribute with the response's
`meta` block: dataset name, title, detail level, key metric, units,
`null_semantics`, source, source URL, citation, license, advisories, data
version, `updated_at`, and the request URL. `gcd_meta(x)` reads it;
`gcd_citation(x)` formats the citation.

Attributes are dropped by many dplyr verbs. That is acceptable: the
metadata describes what came from the API, and `gcd_citation()` also
accepts a dataset name.

### Advisories

The API attaches advisories to results, for example
`suppressed_values_present` and `demographic_non_additive` ("never add
the `all` total to its subgroups"). These are some of the most useful
things the API says, so the package prints each one once as a `cli`
message. `quiet = TRUE` per call, or `options(gcd.quiet = TRUE)` for the
session, silences them; they stay in `gcd_meta(x)$advisories` either way.

They matter more now that `gcd_rows()` returns every group by default
(section 5): the `all` total rows arrive next to the subgroups.

### Errors

API errors become classed R conditions (`gcd_error`, plus a subclass per
API code such as `gcd_error_topic_not_found`). The message is the API's
own, with its suggestions:

```
Error in `gcd_rows()`:
! No dataset 'graduation_rate'.
i Did you mean: ccrpi_graduation_rate,
  graduation_rate_4_year_cohort?
```

Name-matching failures (section 2, "Places by name") use the same
classes (`gcd_error_place_not_found`, `gcd_error_place_ambiguous`).
Classed conditions let scripts `tryCatch()` a specific failure.

### Rate limits and retries

The API allows 600 data requests and 1,200 metadata requests per minute
per caller, 120 GET and 20 POST location lookups per minute. The package
reads `Retry-After` on a 429 and waits automatically, with a message. A
user should never have to think about this. Address lookups don't hit
the 20-per-minute limit either: the package geocodes addresses itself
and sends coordinates in batches of 1,000 (section 8).

### Caching

- **Metadata** (catalog, schemas, contracts, lookup tables) is cached
  in memory for the R session. The server only changes it on a
  redeploy.
- **Data rows: an opt-in disk cache that is never stale.** The API sends
  an `ETag` on row responses, including the bulk CSV path, and answers
  `304 Not Modified` when a request's `If-None-Match` still matches
  (tested against `georgiacivicdata.org` on 2026-11-02). With the cache
  on, each response is saved with its ETag in the standard user cache
  folder (`tools::R_user_dir("georgiacivicdata", "cache")`). The next
  identical request asks the server whether anything changed: a 304
  reuses the saved copy without downloading, and a new data release
  downloads afresh. Scripts that are re-run often stop downloading the
  same data again.
- **Off by default.** `cache = TRUE` on a call, or
  `options(gcd.cache = TRUE)` for the session, turns it on. CRAN expects
  packages not to write files unless asked.
- **Location lookups are never cached**, matching the API's privacy
  rule.
- `gcd_cache_clear()` empties both the session cache and the disk cache.

Why the first draft said no: the user already holds the result in a
variable, large pulls would use hidden memory, and a cache could serve
old data after a release. The ETag check removes the last reason, and a
disk cache (not memory) removes the second.

To confirm when building: the 304 was tested against the API directly;
retest it through the Vercel edge in front of the brand domain.

### No configuration needed

There is no API key, and the package always calls
`https://georgiacivicdata.org/api/v1`; there is no option to point it
elsewhere. The package sends a `User-Agent` naming itself and its
version.

### License

The data is CC BY 4.0. `gcd_citation()` and the README make the
attribution easy: "Georgia Civic Data (georgiacivicdata.org)" plus the
original source.

## 3. Find data

### `gcd_datasets()`

The catalog. Wraps `GET /api/v1/datasets`.

```r
gcd_datasets(
  main_topic = NULL,
  level = NULL,
  year = NULL,
  kind = NULL,
  details = FALSE
)
```

**With no arguments it returns every dataset**: all subject areas, all
detail levels, all years, tables and geometry alike. Each argument only
narrows the list.

**Parameters**

- `main_topic`: `"education"`, `"census"`, `"health"`,
  `"immigration"`. Default `NULL`: all.
- `level`: keep datasets that publish rows at this detail level
  (`"schools"`, `"districts"`, `"counties"`, `"tracts"`, ...). Default
  `NULL`: all.
- `year`: keep datasets that cover this year. Default `NULL`: all.
- `kind`: `"table"` or `"geometry"`. Default `NULL`: both.
- `details`: `FALSE` (default) gives the compact catalog. `TRUE`
  requests `fields=full` and adds the long columns.

**Output:** a tibble, one row per dataset.

- Compact: `name`, `title`, `summary`, `kind`, `main_topic`,
  `detail_levels` (list), `year_min`, `year_max`.
- With `details = TRUE`, also: `description`, `source`, `source_url`,
  `grain` (list), `default_detail`, `year_gaps` (list),
  `update_frequency`, `search_aliases_en` and `search_aliases_es` (lists),
  `updated_at` (POSIXct).

**Notes**

- 176 datasets today: small enough to `View()` and filter with `dplyr`.
- The catalog response also lists the six lookup tables. They are not
  datasets, so they don't appear as rows; `gcd_dimension()`'s help page
  names them.

### `gcd_search()`

Ranked search over the catalog. Wraps `GET /api/v1/search`.

```r
gcd_search(
  query,
  main_topic = NULL,
  level = NULL,
  year = NULL,
  n = 20
)
```

**Parameters**

- `query`: plain words, English or Spanish ("jobless rate", "kids
  missing school", "desempleo").
- `main_topic`, `level`, `year`: the same filters as `gcd_datasets()`,
  all defaulting to no filter.
- `n`: matches to return, 1 to 100 (the API's `limit`).

**Output:** a tibble, one row per match, best first: `rank`, `name`,
`title`, `summary`, `main_topic`, `detail_levels` (list), `year_min`,
`year_max`, `score`, `matched_on` (list: aliases, columns, summary, ...),
`matched_columns` (list).

**Notes**

- The overall `confidence` (`high` / `medium` / `low`) and the retrieval
  mode are attributes, not columns, because they describe the search,
  not a row. On `low` the function prints "Nothing in the catalog may fit
  this query." If the search fell back to keywords only, it says so.
- The API also returns `dimension_matches` (lookup tables that matched,
  such as `schools` for "school addresses"). Print them as a hint line;
  don't mix them into the dataset rows.
- Search is hybrid: keywords plus meaning. The meaning half runs on the
  server (query text goes to Voyage AI there; it is never logged). The R
  package needs nothing extra, but this is the one function whose results
  can't be reproduced by filtering `gcd_datasets()` locally, and its
  ranking can change between releases. The help page should say both.

## 4. Understand a dataset

Your sketch suggested folding the schema, contract and OpenAPI document
into one function. I recommend three narrower functions and dropping the
OpenAPI document instead, because the three give different shapes for
different users:

- The **schema** answers "how do I query this?" It is the everyday one.
- The **columns** are the part of the schema people look at most, and
  they are naturally a table.
- The **contract** is the formal, versioned artifact for people building
  pipelines or citing the schema.
- The per-dataset **OpenAPI** document exists so LLM function-calling
  clients can see every filter. It adds nothing for an R user that the
  schema doesn't already give.

### `gcd_describe()`

Everything about one dataset. Wraps `GET /api/v1/datasets/{name}`, or
`GET /api/v1/dimensions/{name}` for a lookup table.

```r
gcd_describe(name)
```

**Parameters**

- `name`: a dataset, lookup table or geometry dataset name. Names are
  unique across all three kinds (the API refuses to boot otherwise), so
  one function can route to the right endpoint.

**Output:** a `gcd_description` object, a named list with a print method.
The print shows a readable summary: title, source, years (with gaps),
detail levels, grain, key metric, and any notes the contract declares
(limitations, `year_meaning`, series breaks, overlapping groups,
partitions, pooled rates, pooled-year windows).

Components:

- `$columns`: the same tibble `gcd_columns()` returns.
- `$filters`: a tibble of every filter parameter: `param`, `kind`
  (categorical, foreign key, dimension attribute, metric bound, year,
  detail), `values` (list), `multi_value`, `has_total`, `total_value`,
  `requires_single_value`, `nullable`.
- `$notes`: the contract declarations (`non_additive`, `partitions`,
  `pooled_rates`, `series_breaks`, `year_window`, `year_meaning`,
  `value_implications`, `pooled_min_count`), each a tibble or string.
- `$raw`: the full parsed response, for anything not surfaced above.

**Notes**

- The `$filters` tibble is how a user discovers the dimension-attribute
  filters (`district_type`, `school_level`, `locale`,
  `demographic_category`), which are not columns of the dataset.
- The `requires_single_value` flag matters: a column like
  `grade_cluster` has no `all` total, so mixing its values in one
  summary is wrong. The print method lists these columns under a "Pick
  one value of" line. With no `recommended` argument on `gcd_rows()`,
  this line is where users learn it.

### `gcd_columns()`

The column dictionary as a tidy table.

```r
gcd_columns(name)
```

**Output:** a tibble, one row per column: `column`, `label`, `type`,
`role` (year, foreign key, categorical, metric), `unit` (count,
proportion, rate_per_population, ...), `is_key_metric`,
`metric_component` (numerator / denominator), `nullable`,
`valid_values` (list), `description`, `null_meaning`.

**Notes**

- Works for lookup tables too (same columns where they apply).
- This is the function people will reach for most after `gcd_rows()`:
  "what does `pct_proficient_learner_or_above` mean, and is it 0-1?"

### `gcd_contract()`

The dataset's ODCS v3.2 contract. Wraps
`GET /api/v1/datasets/{name}/contract`.

```r
gcd_contract(name, file = NULL)
```

**Parameters**

- `file`: if given, write the contract YAML verbatim to this path and
  return the path invisibly.

**Output:** the contract as a nested list (requested with
`format=json`, so no YAML parser is needed).

**Notes:** a niche function for data engineers and people who want the
formal, versioned schema (`version`, `schema_hash`). Keep it, but it
doesn't need prominence in the README.

## 5. Get data

### `gcd_rows()`

The core function. Wraps `GET /api/v1/datasets/{name}/rows`.

```r
gcd_rows(
  name,
  ...,
  year = NULL,
  detail = NULL,
  district = NULL,
  school = NULL,
  county = NULL,
  labels = TRUE,
  columns = NULL,
  sort = NULL,
  n_max = Inf,
  cache = getOption("gcd.cache", FALSE),
  quiet = FALSE
)
```

**It returns every category and group** that the filters don't
exclude. Nothing is pinned by default: no `demographic = "all"`, no
single subject. A call with only a dataset name returns the whole
dataset at its default detail level.

**Parameters**

- `name`: the dataset's bare name, such as
  `"graduation_rate_4_year_cohort"`.
- `...`: **filters, as named arguments.** Each name is an API filter
  parameter; each value a vector. Values within one filter are OR'd;
  different filters are AND'd. Accepted names:
    - any categorical column: `subject = "mathematics"`,
      `demographic = c("all", "black")`;
    - geography codes: `district_code`, `school_code`, `county_fips`,
      `tract_geoid`, `block_group_geoid`;
    - school ids: `school_id = c("761-0199", "660-0104")`, a school as
      "DISTRICT-SCHOOL" (the API's `school` pair filter, renamed in R
      because `school` is the name argument). It's also the form
      `gcd_locate()` returns, so a located school pastes straight in;
    - lookup-table attributes: `district_type = "state_charter"`,
      `school_level = "high"`, `locale = "rural"`,
      `demographic_category = "race"`;
    - metric bounds: `graduation_rate_min = 0.9`,
      `num_cohort_max = 50` (inclusive, in stored units).
- `year`: an integer vector. A run of consecutive years
  (`2019:2024`) becomes `year_min` / `year_max`; anything else
  (`c(2019, 2024)`) becomes an exact list. One argument, no need to know
  the API's two forms.
- `detail`: the level the rows describe (`"schools"`,
  `"districts"`, `"states"`, `"counties"`, `"tracts"`, ...). Default is
  the dataset's default: the finest level, except Census datasets, which
  default to counties. One level per call.
- `district`, `school`, `county`: places by name, matched to codes
  (section 2, "Places by name").
- `labels`: `TRUE` (default) adds names beside codes; `FALSE` returns
  codes only. See below.
- `columns`: a character vector to return only some columns.
- `sort`: a character vector; prefix `-` for descending
  (`"-graduation_rate"`). Mostly useful with `n_max` for a server-side
  top N.
- `n_max`: the most rows to return. Default all.
- `cache`: use the disk cache (section 2). Default off.
- `quiet`: silence the advisory messages.

**Output:** a tibble of rows at one detail level, typed from the schema
(section 2), with the metadata attribute. Columns in grain order: `year`,
geography codes each followed by its names, `demographic` and its label,
other categoricals, then metrics.

**Labels.** With `labels = TRUE`, the default, the output has the
API's own joined columns: `district_name`, `district_census_id` and
`district_type` after `district_code`; `school_name` after
`school_code`; `county_name`, `tract_name`, `block_group_name` after
their codes; `demographic_label` and `demographic_category` after
`demographic`. Codes are always kept (section 2, "Names and codes
together"). The schema's `foreign_keys[].attribute_columns_added` names
exactly which columns are joined, so the package needs no hardcoded
list.

`labels = FALSE` returns codes only, for large pulls and for users who
join names themselves. It costs almost nothing to keep.

Things worth stating in the help page:

1. Categorical values (`subject`, `grade_cluster`) are already readable
   snake_case codes; there are no separate labels for them. "Labels"
   means place names and demographic display names.
2. `demographic_category` (race, gender, economic_status, ...) is a
   grouping, not a name, but it arrives with the labels. Filtering by it
   works either way (`demographic_category = "race"`).
3. Other lookup-table attributes (school addresses, locale, grade span,
   coordinates) are not joined. Get them from `gcd_dimension()` and join
   (section 6).

**Columns that would be empty on every row are left out.** The API
already does this when it is not given a column list: district rows come
back without `school_code` and `school_name`, state rows without
geography codes, and `meta.omitted_columns` names them. With
`labels = FALSE` the package asks for specific columns, which turns the
API's omission off, so the package drops code columns that are entirely
`NA` itself. Both settings give the same shape. A column that is only
partly `NA` is kept: that happens only when a user binds rows from
several levels, and the `NA` there is true information (this row is a
district total).

**Notes**

- **Getting every row.** JSON pages hold at most 10,000 rows. For a full
  pull the package should not page through JSON; it should request
  `format=csv` without a `limit`, which streams every matching row in one
  response with its total in `X-Total-Count`. The function shows a
  progress bar for large pulls. Users never see this choice.
- **Missing values in filters.** For a nullable categorical, `NA` in a
  filter vector selects rows where the column is empty (the API's
  `__null__` token).
- **Validation happens on the server.** Apart from turning names into
  codes, the package does not re-implement filter checks. The API already
  rejects unknown filters, bad values, conflicting year forms, and a
  `school_code` without exactly one `district_code`, with specific
  messages, and those reach the user as `gcd_error` conditions.
  Reimplementing them would drift.
- **One detail level per call.** To get state, district and school rows,
  call three times and `bind_rows()`. I would not accept a vector here:
  rows at different levels have different empty columns and mixing them
  invites double counting.
- **Totals and subgroups arrive together.** Because nothing is pinned,
  results hold the `all` rows beside the subgroups, and every value of a
  column like `grade_cluster`, which has no total. The
  `demographic_non_additive` advisory and `gcd_describe()`'s "Pick one
  value of" line warn about adding them up.
- **Very long filter lists** (thousands of tract GEOIDs) can exceed URL
  limits. The package can switch to `POST /query` with the same filters.
  Invisible to the user.
- **Numeric filters.** The `{metric}_min` / `{metric}_max` names cover
  nearly every need. The API's JSON `numeric_filters` (`gt`, `between`,
  ...) add strict inequalities only; not worth a separate argument.

**Examples**

```r
# Names and codes (default), one district by name
grad <- gcd_rows(
  "graduation_rate_4_year_cohort",
  district = "Fulton County",
  demographic = c("all", "black", "hispanic"),
  year = 2020:2024
)

# Statewide schools, one subject, codes only
gcd_rows(
  "ccrpi_content_mastery",
  year = 2025,
  detail = "schools",
  grade_cluster = "high",
  subject = "mathematics",
  labels = FALSE
)

# Top 10 counties by unemployment
gcd_rows(
  "employment",
  year = 2024,
  sort = "-unemployment_rate",
  n_max = 10
)
```

### `gcd_values()`

Which category combinations exist, and how many rows each has, under
the same filters as `gcd_rows()`. Wraps
`GET /api/v1/datasets/{name}/values`.

```r
gcd_values(
  name,
  columns,
  ...,
  year = NULL,
  detail = NULL,
  district = NULL,
  school = NULL,
  county = NULL
)
```

**Parameters**

- `columns`: one or more categorical columns (`"subject"`,
  `c("subject", "grade_cluster")`).
- `...`, `year`, `detail`, `district`, `school`, `county`: exactly as in
  `gcd_rows()`.

**Output:** a tibble, one column per requested column plus `n_rows`,
most rows first. Capped at 500 combinations by the API; the function
warns when the cap is hit.

**Why keep it.** It answers questions that are otherwise expensive:
"which subjects exist in 2016 at district level?", "which demographic
groups does this county have rows for?". The alternative is downloading
a dataset with millions of rows to run `distinct()`. The contract's
`valid_values` lists every value ever used; `gcd_values()` lists what
exists **for this filter**, which is what people need when a filter
returns zero rows. Cheap to build: same parameters as `gcd_rows()`.

## 6. Lookup tables: `gcd_dimension()`

Six lookup tables: `districts`, `schools`, `counties`, `tracts`,
`block_groups`, `demographics`. With names now in `gcd_rows()` by
default, one function is enough. The package needs the tables either
way: name matching (section 2) runs against them.

Why `gcd_dimension()` stays: the tables hold much more than names, and
the API never adds it to dataset rows.

- **Schools:** address, coordinates, grade span, school level, locale
  (city, suburb, town, rural), charter status, active flag, NCES id,
  phone, website.
- **Districts:** district type, Census id, address, coordinates, active
  flag.
- **Tracts and block groups:** county, land area, 2020 population (and
  households and housing units for block groups).
- **Demographics:** each group's display label and category.

That is how a user analyzes results by locale or maps schools. It is
also how users browse what exists ("every school in Fulton County").

The table's schema goes through `gcd_describe()`. What was dropped:

- `gcd_dimensions()`, which only listed six fixed tables. The help page
  names them.
- `gcd_add_labels()`. Names come by default; adding other attributes is
  an ordinary `dplyr::left_join()` with `gcd_dimension()`.

Wraps `GET /api/v1/dimensions/{name}/rows`.

```r
gcd_dimension(
  name,
  ...,
  district = NULL,
  school = NULL,
  county = NULL,
  q = NULL,
  columns = NULL,
  n_max = Inf
)
```

**Parameters**

- `name`: one of the six tables.
- `...`: named filters on the key, any enum or boolean column, and
  `county_fips` / `district_code` / `tract_geoid`
  (`district_type = "state_charter"`, `active = TRUE`).
- `district`, `school`, `county`: places by name, as elsewhere
  (`gcd_dimension("schools", county = "Fulton")`).
- `q`: text search over name and label columns, ignoring case and
  accents (`q = "eastside"`). Unlike the name arguments, it matches
  partial text and returns every hit: the tool for browsing.
- `columns`, `n_max`: as in `gcd_rows()`.

**Output:** a tibble ordered by the primary key, typed from the
dimension schema.

**Notes**

- Cached for the session; the largest table (block groups) is about
  7,400 rows, schools about 4,400.
- The help page shows the one join pitfall: schools join on
  `district_code` **and** `school_code` together, because school codes
  repeat across districts.

```r
schools <- gcd_dimension(
  "schools",
  columns = c("district_code", "school_code", "locale")
)
grad |>
  dplyr::left_join(schools, by = c("district_code", "school_code"))
```

## 7. School zones and district boundaries

The two geometry datasets need `sf` to be useful as maps. I recommend
`sf` as a suggested package, not a required one: each geometry
function has a `geometry` argument, and `geometry = FALSE` returns the
attributes as a plain tibble with no `sf` needed. Calling with
`geometry = TRUE` without `sf` installed gives a clear install message.

The API offers GeoJSON, shapefile, GeoParquet and JSON. The package
reads GeoJSON (via `sf`) and JSON (attributes only). Users who want a
shapefile write one with `sf::write_sf()`.

Their schema documents go through `gcd_describe("school_attendance_zones")`
and `gcd_describe("school_district_boundaries")`. The attendance rules
endpoint is not wrapped, as you asked.

Every function here takes `district` and (where the API takes
`school_code`) `school` names beside the codes.

### `gcd_school_zones()`

Attendance-zone polygons: one per school, level and grade run. Wraps
`GET /api/v1/datasets/school_attendance_zones/rows`.

```r
gcd_school_zones(
  district_code = NULL,
  school_code = NULL,
  district = NULL,
  school = NULL,
  zone_level = NULL,
  grade = NULL,
  year = NULL,
  resolution = c("display", "full"),
  geometry = TRUE
)
```

**Parameters**

- `district_code`, `school_code`: vectors of codes.
- `district`, `school`: names, matched to codes.
- `zone_level`: `"elementary"`, `"middle"`, `"high"`.
- `grade`: keep zones serving this grade (`"k"`, `"05"`, `"09"`).
- `year`: the zones' school year (currently 2027, the 2026-27 zones).
- `resolution`: `"display"` (simplified, smaller, the default) or
  `"full"` (the source geometry).
- `geometry`: `TRUE` for `sf`, `FALSE` for a tibble.

**Output:** an `sf` object (or tibble), one row per zone: `year`,
`district_code`, `district_name`, `school_code`, `school_name`,
`zone_level`, `grade_low`, `grade_high`, `method`, `accuracy_class`,
`currency_status`, `boundary_vintage`, `source_url`, `retrieved_on`,
`area_sq_mi`, bounding box, geometry (WGS 84). The names come from the
lookup tables, as everywhere else; the API's `source_school_name` (the
name as the district's own map spells it) stays as an extra column.

**Notes**

- A statewide pull at full resolution is large. The help page should
  point people to a district filter and the `display` default.
- The `method` and `accuracy_class` columns matter: some zones are
  official GIS layers, some are digitized from maps, some are a whole
  district outline. The print or help should say not to treat them as
  equally precise.

### `gcd_district_boundaries()`

TIGER/Line school district outlines. Wraps
`GET /api/v1/datasets/school_district_boundaries/rows`.

```r
gcd_district_boundaries(
  district_code = NULL,
  district = NULL,
  geometry = TRUE
)
```

**Output:** an `sf` object (or tibble), one row per district piece,
with `district_code`, `district_name`, the boundary type (unified,
secondary) and NCES ids. Includes the Department of Defense districts.

### `gcd_school_zone_status()`

Whether each school of the 180 standard districts has a zone, and why
not when it doesn't. Wraps `.../school_attendance_zones/school_status`.
Tabular, so I recommend including it even though your list didn't name
it.

```r
gcd_school_zone_status(
  district_code = NULL,
  school_code = NULL,
  district = NULL,
  school = NULL,
  zone_status = NULL,
  no_zone_category = NULL
)
```

**Output:** a tibble, one row per school: `year`, `district_code`,
`district_name`, `school_code`, `school_name`, `zone_status` (`zoned`,
`no_zone`, `not_yet_collected`), `zone_levels`, `no_zone_category`,
`reason`.

Answers "why doesn't this magnet school have a zone?" without the user
inferring it from a missing polygon.

### `gcd_school_zone_coverage()`

How completely each district's zones were collected. Wraps
`.../school_attendance_zones/coverage`.

```r
gcd_school_zone_coverage(
  district_code = NULL,
  district = NULL,
  geometry = FALSE
)
```

**Output:** the API returns one row per district with per-level columns
(`level_status_elementary`, `pct_population_middle`, ...). The package
pivots them long for tidiness: one row per district and zone level, with
`year`, `district_code`, `district_name`, `tier`, `status`, `zone_level`,
`level_status`, `pct_land_area`, `pct_population`, `zone_count`,
`methods`, `accuracy_classes`, `reason`. With `geometry = TRUE` it
returns an `sf` object of district outlines carrying those fields
(GeoJSON format).

**Judgment call:** pivoting long is tidier but differs from the API's
shape. Keep a `wide = FALSE` argument if you want both.

The district filter is applied in R (the coverage endpoint takes no
filters; the table has only about 180 rows).

## 8. Locate places: `gcd_locate()`

Points or street addresses to the county, 2020 tract and block group,
school district and schools they fall in. Wraps the point-batch form of
`POST /api/v1/locate`. Addresses are first geocoded on the user's own
computer with the U.S. Census batch geocoder, so they never reach the
Georgia Civic Data server (see "How address lookups work" below).

```r
gcd_locate(
  lat = NULL,
  lon = NULL,
  address = NULL,
  id = NULL,
  grade = NULL,
  year = NULL
)
```

**Parameters**

- `lat`, `lon`: numeric vectors of equal length.
- `address`: street addresses, either a character vector of one-line
  addresses or a data frame with `street`, `city`, `state` and `zip`
  columns (the Census batch geocoder's own input fields). Give either
  `lat`/`lon` or `address`, not both.
- `id`: optional identifiers, same length as the input, carried into the
  output so results can be joined back. Default `1:n`.
- `grade`: keep only school zones serving this grade (`"k"`, `"05"`).
- `year`: the zones' year.

### Output: one row per place

A tibble in long form: **for each input, one row per geographic unit
it falls in.** A typical location gives seven rows: its county, tract,
block group and school district, then a row for each school it is zoned
for. A level can have more than one school row: some homes are zoned
to one elementary school for kindergarten to grade 3 and another for
grades 4-5.

Columns, in order:

1. `id`
2. **The input columns.** For points: `lat`, `lon`. For addresses:
   `address`, then the geocoder's `match_status`, `match_type` (exact or
   not), `matched_address`, and the geocoded `lat` and `lon`.
3. `geographic_type`: one of `county`, `tract`, `block_group`,
   `school_district`, `elementary_school`, `middle_school`,
   `high_school`.
4. `geographic_id`: the place's code. County FIPS ("13121"), tract
   GEOID ("13121003500"), block group GEOID ("131210035001"), district
   code ("761"). A school is "DISTRICT-SCHOOL" ("761-4560"): a school
   code alone is not unique across districts. That is the same form
   `gcd_rows()` takes as `school_id`.
5. `geographic_name`: the place's name. County, tract and block group
   names come from the lookup tables (looked up locally, so the
   coordinates never leave the API call); district and school names from
   the API response.

Rows for each input come in a fixed order: county, tract, block group,
district, then elementary, middle and high schools.

An illustrative result for one point in Atlanta:

| id | lat | lon | geographic_type | geographic_id | geographic_name | grades |
|---|---|---|---|---|---|---|
| 1 | 33.749 | -84.388 | county | 13121 | Fulton | NA |
| 1 | 33.749 | -84.388 | tract | 13121003500 | Census Tract 35 | NA |
| 1 | 33.749 | -84.388 | block_group | 131210035001 | Block Group 1, Census Tract 35, Fulton County | NA |
| 1 | 33.749 | -84.388 | school_district | 761 | Atlanta Public Schools | NA |
| 1 | 33.749 | -84.388 | elementary_school | 761-0199 | Centennial Academy (Charter) | K-5 |
| 1 | 33.749 | -84.388 | middle_school | 761-0199 | Centennial Academy (Charter) | 6-8 |
| 1 | 33.749 | -84.388 | high_school | 761-4560 | Midtown High School | 9-12 |

The `note` column, `NA` on every row here, is left out of the sample to
keep it narrow.

This shape filters and counts easily
(`filter(geographic_type == "high_school")`), and stacks any number of
schools without wide columns that collide.

**Two more columns after those three.** These go beyond the shape you
first specified:

- `grades`: the grades a school row serves, written as one short range
  ("K-2", "3-5", "6-8", "9-12"), built from the API's `grade_low` and
  `grade_high`. `NA` on the county, tract, block group and district rows,
  where it doesn't apply. Grades matter because split grade runs are
  common: 62 districts split at least one level (a K-2 school and a
  3-5 school, say), roughly a third of the districts with zones. A
  location there gets two `elementary_school` rows, which would look
  like a contradiction without grades. One column instead of two
  (`grade_low`, `grade_high`) halves the `NA` cells. Users who want
  exactly one school per level pass `grade` (`grade = "04"`), and the
  extra rows disappear.
- `note`: `NA` normally. Otherwise one plain sentence, so a missing row
  is never silent:
    - **No zone collected:** an input inside Georgia whose district has
      no zone for a level yet gets a row for that level with `NA` id and
      name, and a note saying the zone has not been collected (from the
      API's `coverage_status`).
    - **Lookup failed:** an input outside Georgia, or an address the
      geocoder could not match, gets a single row with `NA` geographic
      columns and the reason. The function never stops a batch over one
      bad input.

Zone-quality fields (`method`, `accuracy_class`, `currency_status`) are
left out of this table; `gcd_school_zones()` returns them for any school
`gcd_locate()` finds.

The draft's `shape = "wide"` option is gone. A user who wants one row
per input can pivot, keeping in mind that split grade runs give more
than one school for a level.

### Behavior

- **Always POST**, even for one point, so coordinates never appear in
  URLs (the API's privacy design). Nothing is cached.
- **Points** go in batches of up to 1,000 per request, each with its
  `id`; the API returns the `id` with each result, so results join back
  to the input. The API allows 20 POST requests a minute, which is
  20,000 points a minute: no pacing is needed in practice.
- **Addresses** are geocoded by the package, then sent as points (next
  section).
- The response's `assignment_note` (a zone is the default assignment,
  not the only option) prints once per session and is kept as an
  attribute.

### How address lookups work

The API does have an address form (`{"address": "..."}`), but it takes
one address per request, geocodes it on the server through the Census
single-address service, and is held to 20 POST requests a minute: about
5 minutes per 100 addresses. The package doesn't use it. Instead,
`gcd_locate(address = ...)` runs two steps:

1. **Geocode on the user's computer.** The package sends the addresses
   straight to the U.S. Census batch geocoder (its `addressbatch`
   service: a CSV upload of id, street, city, state and ZIP, answered
   with a CSV of matches and coordinates). It uses the same address data
   the API uses (`Public_AR_Current`), so a result matches what the
   website's address search gives for the same address. Large lists are
   split into the service's maximum upload size, with a progress bar.
2. **Send the coordinates to `/locate`** in batches of 1,000 with their
   ids, as for points. The geocoder's `match_status`, `match_type` and
   `matched_address` are joined back by id. An address the geocoder
   could not match gets one row with a `note` and is never sent to the
   API.

No extra package is needed: the HTTP client and `readr` the package
already uses can send the upload and read the result. `tidygeocoder` is
mentioned in the help page only as an alternative for users who
geocode their own data or want a different geocoding service.

**Why not a batch address endpoint on the API?**

- **Privacy:** an address list is often a list of students' or
  patients' homes. With this design the addresses go only to the Census
  Bureau, never to our server.
- **No stored state:** a large Census batch can take minutes, longer
  than a web request should run. Serving it from the API would need a
  submit-then-check-back job, so the server would hold addresses or
  their results between requests, breaking its "never stored" rule.
- **One shared quota:** the API's geocoding runs through one limiter,
  about 5 addresses a second for every user combined. One large batch
  would block the website's address search and the AI tools for
  everyone.
- **No free geocoding proxy:** a bulk address endpoint invites use
  unrelated to Georgia schools.

**No API change is needed** for any of this: the point-batch form of
`POST /locate` already exists. One optional documentation change: a
sentence on the `/locate` page pointing bulk-address users to this
two-step path, which helps Python and other API users too.

**To confirm before building** (not checked when this was written):

- the Census batch service's current upload format and maximum size
  (10,000 addresses per upload, as last documented), and how well it
  matches a one-line address placed in the street field alone. If it
  matches poorly, the package splits one-line addresses into their
  fields first, or asks for the data-frame form;
- the response time of a full 1,000-point `/locate` batch against
  production. The API accepts that size today, but no one has timed
  routine use of it.

**Not included: tract mode.** `GET /locate?tract_geoid=` returns the
zones covering a tract. The same rows, with population and area shares,
are in the `school_attendance_zone_tracts` dataset:
`gcd_rows("school_attendance_zone_tracts", tract_geoid = ...)`. One way
to get it is enough, and it keeps `gcd_locate()`'s output shape single.

## 9. Endpoints not wrapped, and why

**`/resolve`** (name to code). The name arguments (`district`, `school`,
`county`) cover the need, matching exactly against the lookup tables,
and `gcd_dimension(q = ...)` covers browsing by partial name. `/resolve`
matches fuzzily, which helps with typos but can pick the wrong place
silently; exact matching that fails loudly with suggestions is the safer
default for scripts.

**`POST /datasets/{name}/query`.** Used inside `gcd_rows()` for very
long filter lists. Not exported: same parameters as `/rows`, and GET is
edge-cached, so GET stays the default.

**`/datasets/{name}/download`.** Not needed as a function.
`gcd_rows()` already pulls every row through the bulk CSV path, and
users export with `readr::write_csv()` or `arrow`.

**`/datasets/{name}/aggregate`.** Skip for version 1. One caution for
the README or a vignette: rates must be pooled from their counts, never
averaged (`sum(num_graduates) / sum(num_cohort)`, not
`mean(graduation_rate)`). The API's aggregate does this and also refuses
to rebuild rates the publisher withheld (`pooled_min_count`). Users
aggregating locally need the rule. `gcd_describe()` shows each dataset's
numerator and denominator (`metric_component`) and `pooled_rates`, so
the information is in reach. If misuse shows up, a later
`gcd_aggregate()` could wrap the endpoint with `group_by` and
`agg = "weighted_rate"`.

**`/datasets/{name}/openapi.json`.** For LLM function-calling clients.
No R use.

**`/school_attendance_zones/attendance_rules`.** Excluded, as you
asked.

**`POST /locate` with `{"address"}` and `GET /locate`.** The package
uses only the point-batch form of `POST /locate`. Addresses are geocoded
on the user's computer (section 8), and GET would put coordinates in
URLs.

**`/` and `/healthz`.** Service info and liveness. No user value.

**Data Talk and MCP.** Separate products on the same server; out of
scope.

## 10. A typical session

```r
library(georgiacivicdata)

gcd_search("high school graduation")
gcd_columns("graduation_rate_4_year_cohort")

grad <- gcd_rows(
  "graduation_rate_4_year_cohort",
  district = "Fulton County",
  demographic = c("all", "black", "white"),
  year = 2018:2024
)

gcd_citation(grad)

zones <- gcd_school_zones(district = "Fulton County")
home <- gcd_locate(lat = 34.04, lon = -84.34)
```

## 11. Decisions

Settled by Shane: the package name `georgiacivicdata` with the `gcd_`
prefix; names by default with codes kept; name arguments for places; no
`recommended` argument; `gcd_dimensions()` and `gcd_add_labels()`
dropped; an opt-in disk cache; no base URL option; addresses geocoded by
the package; and the long `gcd_locate()` shape with one `grades` column
and a `note` column.

Adopted as recommended for the first build (change them here, and in
`notes/build-package-prompt.md`, if Shane decides otherwise):

1. **`sf` is a suggested package**, not an import, with
   `geometry = FALSE` fallbacks. It keeps installs light for the large
   majority who only want tables.
2. **`gcd_school_zone_coverage()` returns long data**, one row per
   district and zone level.
3. **`school_id` is the R name** for the API's "DISTRICT-SCHOOL" filter,
   since `school` is the name argument.
4. **No `gcd_resolve()` or `gcd_aggregate()`** in version 1; add them on
   demand.

# Prompt: build the `georgiacivicdata` R package

You are building, from an empty repository, a complete, CRAN-ready R
package that wraps the Georgia Civic Data REST API. Work autonomously
until every item in "Definition of done" (section 1) is true. This is a
long task (several hours, most of it waiting on installs and checks);
that is expected.

- **Package name:** `georgiacivicdata`. **Function prefix:** `gcd_`.
- **Local repo:** `~/projects/georgia-data-rpackage` (exists; holds only
  `notes/`).
- **GitHub repo:** `shanejorr/georgia-data-rpackage`, public (section 3).
- **API:** `https://georgiacivicdata.org/api/v1` (production, read-only,
  no key).

## 0. How to work

**Read first, in this order:**

1. This prompt. It is authoritative.
2. `notes/function-design.md`: the user-facing design, with the
   reasoning behind each choice. This prompt restates every
   recommendation in it and adds implementation decisions. If the two
   ever disagree, this prompt wins; say so in your final report.
3. *R Packages*, second edition, by Hadley Wickham and Jennifer Bryan,
   <https://r-pkgs.org/>. Follow its practices throughout: package
   structure, `usethis` setup, DESCRIPTION and dependencies, roxygen2
   documentation, testthat 3e, vignettes, pkgdown, GitHub Actions,
   licensing, and the release chapter's CRAN checklist. Read the chapters
   relevant to each step before doing it.
4. The API's own guide, **read-only**:
   `~/projects/georgia-data/src/api/CLAUDE.md` (routes, parameters,
   errors, rate limits, privacy rules). Code under
   `~/projects/georgia-data/src/api/` may also be read for exact response
   shapes. Never edit anything in `~/projects/georgia-data`.

**Verify against the live API before coding each function.** Section 4
lists what was verified on 2026-11-02, but response shapes are the
contract you code to: `curl` the endpoint, look at the real response,
then write the function and record its test fixture.

**Shane monitors asynchronously** (often from a phone). Post a short,
self-contained progress update at the end of each milestone (section 15).
If blocked on a decision only Shane can make, state it crisply, up front,
with your recommendation, then continue with any work that doesn't
depend on it.

**Ground rules.**

- Never edit `~/projects/georgia-data` or any service it runs.
- Never submit to CRAN (`devtools::release()`, `devtools::submit_cran()`).
  Shane decides when to submit.
- The pkgdown site is served at `https://georgiacivicdata.org/r/`
  through a rewrite in the main site (section 11). Set no custom domain
  on GitHub Pages and change no DNS.
- `sudo` is interactive on this machine and will fail. When something
  needs root, stop and give Shane the exact command (he runs it with the
  `!` prefix).
- Never print, commit or write tokens or credentials anywhere. Read the
  GitHub token at run time (`gh auth token`).
- Never put a real home address in code, tests, fixtures, examples or
  vignettes. Use public buildings only (section 9).
- The API is production, and every request it serves is counted in the
  project's usage metric. Keep live requests to what development
  genuinely needs: record fixtures once, replay them in tests.
- `/tmp` on this machine is a small shared tmpfs (7.5 GB). If an install
  or check fails with "Disk quota exceeded", set
  `TMPDIR=$HOME/tmp-rbuild` (create it first) and retry.

## 1. Definition of done

The work is done when all of these are true, and your final report shows
the evidence for each:

1. **Every exported function in section 6 exists**, with the signature,
   behavior and output specified there, plus the three utilities.
2. **Internal helper functions** keep the exported functions short and
   free of duplication (section 7).
3. **Every export is documented** with roxygen2: title, description,
   every parameter, `@returns` describing the columns, examples,
   `@family`, `@seealso` where useful (section 8).
4. **`README.Rmd` and `README.md`** exist (section 10).
5. **Three vignettes** exist and build, including one with real
   analysis (section 10).
6. **Unit tests** with testthat 3e cover every export and the important
   helpers, run offline from recorded fixtures, and pass; coverage is at
   least 90% by `covr::package_coverage()` (section 9).
7. **The pkgdown framework** exists: `_pkgdown.yml` with every export in
   the reference index, the articles, the brand theme, the site URL
   `https://georgiacivicdata.org/r/`, and a GitHub Actions workflow that
   deploys it to GitHub Pages (section 11).
   `pkgdown::check_pkgdown()` passes and `pkgdown::build_site()` builds
   locally.
8. **GitHub Actions** run R CMD check on macOS, Windows and Ubuntu
   (devel, release, oldrel-1), deploy pkgdown, run r-hub on demand, and
   run the live-API tests weekly; the check workflow is green on the
   latest commit (section 12).
9. **All CRAN checks pass** (section 13): `devtools::check(remote = TRUE,
   manual = TRUE)` gives 0 errors, 0 warnings and 0 notes (the
   "New submission" note is the one acceptable note), the GitHub Actions
   matrix is green, and `rhub::rhub_check()` is green on every platform
   listed in section 13.
10. **`CLAUDE.md` and an `AGENTS.md` symlink to it** exist at the repo
    root (section 14).
11. **`notes/` is in `.Rbuildignore`**, and everything is committed and
    pushed to GitHub.

## 2. Environment setup

The toolchain was installed on 2026-11-02, before this prompt ran:

- **R 4.5.2** with the system libraries devtools, pkgdown and sf need
  (from Ubuntu 26.04's `r-base`).
- **R packages** in the user library
  (`~/R/x86_64-pc-linux-gnu-library/4.5`): `cli`, `curl`, `httr2`,
  `jsonlite`, `readr`, `rlang`, `tibble`, `tidyr`, `dplyr`, `ggplot2`,
  `sf`, `httptest2`, `testthat`, `withr`, `knitr`, `rmarkdown`,
  `spelling`, `devtools`, `usethis`, `roxygen2`, `pkgdown`, `rhub`,
  `urlchecker`, `covr`, `rcmdcheck`, `lintr`, `styler`, `tinytex`, `pak`,
  and their dependencies.
- **`~/.Rprofile`** points R at Posit Package Manager's prebuilt Linux
  binaries for this release
  (`https://packagemanager.posit.co/cran/__linux__/resolute/latest`), so
  any package you add installs in seconds with `install.packages()`.
- **TinyTeX** in `~/.TinyTeX`, with `makeindex` added: a test
  `R CMD Rd2pdf` built a manual. If a LaTeX package turns out to be
  missing during `check(manual = TRUE)`, add it with
  `tinytex::tlmgr_install("<name>")`; no sudo needed.
- Also present: `pandoc` (`/usr/bin/pandoc`), `quarto`, `git`, and `gh`
  (logged in as `shanejorr` with `repo` scope).

Confirm it first: `R --version`, and
`Rscript -e 'library(devtools); library(sf)'`. If anything is missing,
install R packages yourself; if a system library or R itself is
missing, stop and ask Shane to run (sudo needed):

```bash
sudo apt-get install -y r-base r-base-dev libcurl4-openssl-dev \
  libssl-dev libxml2-dev libfontconfig1-dev libharfbuzz-dev \
  libfribidi-dev libfreetype-dev libpng-dev libtiff-dev libjpeg-dev \
  libwebp-dev libgdal-dev libgeos-dev libproj-dev libudunits2-dev \
  libsqlite3-dev libgit2-dev qpdf cmake
```

Then:

- **Make the GitHub token visible to R** for usethis and rhub, per
  session only: `Sys.setenv(GITHUB_PAT = system("gh auth token",
  intern = TRUE))`. Never write it to `.Renviron` or any file.

## 3. Repository and GitHub setup

1. **Create the package** in the existing directory:
   `usethis::create_package("~/projects/georgia-data-rpackage",
   open = FALSE)`. Keep `notes/` untouched.
2. **Git:** `usethis::use_git()`, or `git init -b main`. Commit the
   skeleton and `notes/`.
3. **Ignore files:** add to `.Rbuildignore` (via
   `usethis::use_build_ignore()`): `notes`, `CLAUDE.md`, `AGENTS.md`,
   and anything else that isn't part of the built package (usethis adds
   most automatically). `.gitignore` excludes the pkgdown output `docs/`,
   `.Rproj.user`, `.Rhistory`, `.RData` and built tarballs.
4. **Create the GitHub repo and push:**

   ```bash
   gh repo create shanejorr/georgia-data-rpackage --public \
     --source=. --remote=origin \
     --description "R client for the Georgia Civic Data API"
   git push -u origin main
   ```

   Public, for three reasons: GitHub Pages for the pkgdown site needs it
   on the current free plan; GitHub Actions minutes are unlimited for
   public repos (the macOS and Windows check matrix is expensive on
   private ones); and CRAN packages are normally public.
5. **Link GitHub in DESCRIPTION:** `usethis::use_github_links()` (sets
   `URL` and `BugReports`), then make the pkgdown site,
   `https://georgiacivicdata.org/r/`, the first `URL` entry (section 11).
6. **Push often.** Shane works on two machines: commit after each
   logical step and push at the end of every milestone.

## 4. The API: verified facts (2026-11-02)

Base URL `https://georgiacivicdata.org/api/v1`. Every dataset, lookup
table and geometry dataset is addressed by its **bare name**; names are
unique across all three kinds.

### Endpoints the package uses

| Route | Used by | Notes |
|---|---|---|
| `GET /datasets` | `gcd_datasets()` | Filters `main_topic`, `level`, `year`, `kind` (`table` / `geometry`); `fields=full` for the long form. Response `{data, count, fields, links, dimensions, license}`; `dimensions` lists the six lookup tables. 176 datasets today. |
| `GET /search` | `gcd_search()` | `q` (required), `limit` 1-100 (default 20), `main_topic`, `level`, `year`. Response `{query, matches, match_count, total_matches, truncated, confidence, retrieval: {mode, reranked}, dimension_matches}`. |
| `GET /datasets/{name}` | `gcd_describe()`, `gcd_columns()`, every data function | The schema: `columns` (each with `name`, `type`, `role`, `nullable`, `label`, `description`, `valid_values`, `unit`, `null_meaning`, `key_metric_grain_contributor`, `metric_component`, ...), `key_metric`, `grain`, `detail_levels`, `default_detail`, `available_years`, `year_gaps`, `foreign_keys` (each with `column` and `attribute_columns_added`), `filters`, `null_semantics`, `limitations`, `non_additive`, `partitions`, `value_implications`, `year_meaning`, `pooled_rates`, `series_breaks`, `year_window`, `pooled_min_count`, `source`, `source_url`, `updated_at`, `schema_hash`, `version`. Column `type` values seen: `integer`, `number`, `string`, `boolean`. |
| `GET /datasets/{name}/contract?format=json` | `gcd_contract()` | ODCS v3.2 contract; `format=yaml` gives the YAML. Lookup tables have **no** contract route (404). |
| `GET /datasets/{name}/rows` | `gcd_rows()` | See "Rows" below. |
| `POST /datasets/{name}/query` | `gcd_rows()` internally | The rows route with a JSON body, for filter lists too long for a URL. |
| `GET /datasets/{name}/values?columns=a,b` | `gcd_values()` | Same filters as rows. Response `{dataset, detail, columns, null_filter_token, total_combinations, truncated, data: [{..., count}]}`; at most 500 combinations. |
| `GET /dimensions/{name}` | `gcd_describe()`, `gcd_columns()` | Lookup table schema. |
| `GET /dimensions/{name}/rows` | `gcd_dimension()`, the name resolver, label joins | Filters on the key, enum and boolean columns, and `county_fips` / `district_code` / `tract_geoid`; `q` text search; `columns`, `sort`, `limit` (max 10,000), `offset`, `format`. |
| `GET /datasets/school_attendance_zones` | `gcd_describe()` | Geometry schema (fields, enums, CRS, `assignment_note`). |
| `GET .../school_attendance_zones/rows` | `gcd_school_zones()` | `district_code`, `school_code`, `zone_level` (lists), `grade`, `year`, `format` `geojson` or `json` (shapefile and geoparquet exist; not used), `resolution` `display` or `full`. |
| `GET .../school_attendance_zones/contract` | `gcd_contract()` | |
| `GET .../school_attendance_zones/coverage` | `gcd_school_zone_coverage()` | No filters; `format` `json` or `geojson`; one row per district with per-level columns (`level_status_elementary`, `pct_land_area_middle`, `pct_population_high`, ...). |
| `GET .../school_attendance_zones/school_status` | `gcd_school_zone_status()` | Filters `district_code`, `school_code`, `zone_status`, `no_zone_category`; `format=json` gives `{data, count, note}`. |
| `GET /datasets/school_district_boundaries` and `/rows` | `gcd_describe()`, `gcd_district_boundaries()` | `district_code`, `format`. |
| `POST /locate` | `gcd_locate()` | Body `{"points": [{"id", "lat", "lon"}, ...], "grade", "year"}`, at most 1,000 points. See "Locate" below. |

**Not used** (decided in the design doc, section 9): `/resolve`,
`/aggregate`, `/download` (the rows CSV path does the same),
`/openapi.json`, `.../attendance_rules`, `POST /locate` with an
`address`, `GET /locate`, `/`, `/healthz`, and the Data Talk and MCP
routes.

### Rows

- **JSON** (default): `{data, pagination: {limit, offset, total,
  returned, has_more}, links: {self, next}, meta}`. `meta` holds
  `dataset`, `key`, `title`, `detail`, `key_metric`, `units`,
  `null_semantics`, `source`, `source_url`, `citation`, `license`,
  `schema`, `advisories` (`[{code, message}]`), `year_meaning`,
  `omitted_columns`, `data_version`, `updated_at`. Default page 1,000
  rows, at most 10,000 (`limit` above that is `400 LIMIT_TOO_LARGE`).
- **CSV** (`format=csv`) **without `limit` streams every matching row**
  in one response, with `X-Total-Count`. CSV carries **no `meta`**: no
  advisories, no citation.
- **Parameters:** `year` (list) xor `year_min` / `year_max`; `detail`;
  every categorical column as a list filter; `district_code`,
  `school_code`, `county_fips`, `tract_geoid`, `block_group_geoid`,
  `demographic`; `school=DISTRICT-SCHOOL,...` pairs; the dimension
  attributes `district_type`, `school_level`, `locale`,
  `demographic_category`; `{metric}_min` / `{metric}_max`; `columns`;
  `sort=-col,col2`; `limit`; `offset`; `format`. Lists are comma-joined
  or repeated. An empty value is `400 EMPTY_FILTER`. `__null__` selects
  NULLs in a nullable enum. `school_code` needs exactly one
  `district_code`. Unknown parameters are `400 UNSUPPORTED_FILTER`.
- **Joined columns:** by default every row carries the lookup-table
  columns named in the schema's `foreign_keys[].attribute_columns_added`:
  `district_name`, `district_census_id`, `district_type`, `school_name`,
  `county_name`, `tract_name`, `block_group_name`, `demographic_label`,
  `demographic_category`. All are character. The API appends them after
  the metrics.
- **Empty columns:** without `columns`, code and name columns that are
  NULL on every row of the requested detail are left out
  (`meta.omitted_columns`). Passing `columns` turns that off.
- **Caching headers:** row responses (JSON and CSV) carry an `ETag`;
  `If-None-Match` with an unchanged ETag returns `304 Not Modified`
  (tested against `georgiacivicdata.org` directly). They also carry
  `Cache-Control: public, max-age=300`.

### Errors, limits, headers

- **Errors:** every error body is `{"error": {"code", "message",
  "details"}}`. Codes include `TOPIC_NOT_FOUND` / `DIM_NOT_FOUND` (404,
  `details.did_you_mean`), `UNSUPPORTED_FILTER`, `INVALID_FILTER_VALUE`,
  `EMPTY_FILTER`, `REPEATED_PARAMETER`, `CONFLICTING_YEAR_FILTER`,
  `INVALID_YEAR_RANGE`, `SCHOOL_NEEDS_DISTRICT`, `INVALID_COLUMNS`,
  `INVALID_SORT`, `INVALID_DETAIL`, `LIMIT_TOO_LARGE` (400),
  `QUERY_TIMEOUT` (503), `RATE_LIMITED` (429, `Retry-After`),
  `INTERNAL_ERROR` (500), `INVALID_GRADE`, `BATCH_TOO_LARGE`,
  `INVALID_LOOKUP`.
- **Rate limits per caller:** 600 data and 1,200 metadata requests a
  minute; 20 `POST /locate` a minute. Responses carry
  `X-RateLimit-Limit` / `-Remaining` / `-Reset`.
- **License header:** `Link: <https://creativecommons.org/licenses/by/4.0/>;
  rel="license"` on every response.

### Lookup tables

| Table | Key | Columns |
|---|---|---|
| `districts` | `district_code` | `district_name`, `former_names`, `district_census_id`, `district_type`, `county_fips`, `street_address`, `city`, `zip`, `latitude`, `longitude`, `active`, `directory_year` |
| `schools` | `district_code` + `school_code` | `school_name`, `former_names`, `school_level`, `grade_low`, `grade_high`, `county_fips`, `nces_school_id`, `street_address`, `city`, `zip`, `phone`, `website`, `latitude`, `longitude`, `locale`, `charter`, `active`, `directory_year` (4,372 rows) |
| `counties` | `county_fips` | `county_name` (159 rows; "Fulton", without "County") |
| `tracts` | `tract_geoid` | `tract_name` ("Census Tract 35"), `county_fips`, `county_name`, `land_area_sq_mi`, `population_2020` (2,796 rows) |
| `block_groups` | `block_group_geoid` | `block_group_name` ("Block Group 1, Census Tract 35, Fulton County"), `tract_geoid`, `county_fips`, `land_area_sq_mi`, `population_2020`, `housing_units_2020`, `households_2020` (7,446 rows) |
| `demographics` | `demographic` | `demographic_label`, `demographic_category` |

`former_names` is one string, earlier names joined with `"; "`, most
recent first. 174 elementary and high school names belong to more than
one school ("Eastside Elementary School" is in 6 districts), and
non-school facilities ("Central Office") repeat in nearly every district.

### Locate

`POST /locate` with `{"points": [...]}` returns `{"results": [...],
"count"}`, one result per point in input order, each echoing its `id`.
A result holds `year`, `grade`, `county_fips`, `tract_geoid`,
`block_group_geoid`, `district` (`district_code`, `district_name`,
`district_census_id`, `nces_lea_id`, `boundary_type`), `coverage_status`
(`zoned`, `one_school_per_grade`, `gap`, `not_available`, `not_zoned`,
`outside_georgia`), `coverage_reason`, `level_status` (per level:
`zoned`, `one_school_per_grade`, `gap`, `not_available`,
`served_by_other_district`), `zones` (each with `district_code`,
`school_code`, `school_name`, `zone_level`, `grade_low`, `grade_high`,
`method`, `accuracy_class`, ...; sorted by level, then grade),
`served_elsewhere`, `currency_warning`, `overlap_warning`, `note` and
`assignment_note`. A point that fails validation returns `{"id",
"error": {"code", "message"}}` in its slot. A Department of Defense
district has `district_code` NULL and `boundary_type` `"dodea"`. Grades
are `pk`, `k`, `01` ... `12`.

## 5. Package-wide design

### DESCRIPTION

- `Title`: title case, under 65 characters, with the service name in
  single quotes, for example "Access Public Data from 'Georgia Civic
  Data'".
- `Description`: one paragraph that does not start with the package
  name; names the API with its URL in angle brackets
  (`<https://georgiacivicdata.org/api/v1>`); says what data it covers
  (Georgia education, Census context, immigration and health, at state,
  county, district, school and tract level) and that results are tidy
  data frames; mentions school attendance zones as 'sf' objects and
  point and address lookups. Quote 'sf' and other software names.
- `Authors@R`: `person("Shane", "Orr", email = "shane.j.orr@gmail.com",
  role = c("aut", "cre", "cph"))`.
- `License`: `MIT + file LICENSE`, via `usethis::use_mit_license("Shane
  Orr")` (matches the platform's code license). The data the package
  returns is CC BY 4.0; say so in the README and in `gcd_citation()`'s
  docs, not in `License`.
- `Depends: R (>= 4.1.0)`. `Language: en-US`. `Encoding: UTF-8`.
  `Config/testthat/edition: 3`. `Roxygen: list(markdown = TRUE)`.
  `VignetteBuilder: knitr`.

### Dependencies

Minimize imports. Use **httr2** for every HTTP call: it gives retries
that honor `Retry-After` (`req_retry()`), ETag-aware disk caching
(`req_cache()`), streaming to a file (`req_perform(path = )`), multipart
uploads, user agents and error hooks, so the package needs no hand-rolled
HTTP layer. httr2 already depends on `cli`, `curl`, `rlang` and
`jsonlite`, so importing those adds nothing to install.

Expected `Imports`: `cli`, `curl` (only for `curl::form_file()` in the
geocoder upload), `httr2`, `jsonlite`, `readr`, `rlang`, `tibble`, and
`tidyr` (coverage pivot). Add `dplyr` only if it clearly simplifies code
you can't write cleanly in base R; justify it in `CLAUDE.md` if you do.
`Suggests`: `sf`, `ggplot2`, `dplyr` (vignettes), `httptest2`,
`testthat (>= 3.0.0)`, `withr`, `knitr`, `rmarkdown`, `spelling`.

Every use of a Suggests package is guarded (`rlang::check_installed()`
in functions, `skip_if_not_installed()` in tests).

### Conventions (from the design doc, section 2)

- **Prefix** `gcd_` on every export. Code arguments use the API's
  parameter names (`district_code`, `county_fips`, `detail`, `year`).
- **Tibbles** for tabular results; **`sf`** for geometry (with
  `geometry = FALSE` for a plain tibble); one row per observation;
  list-columns only where flattening would lose meaning (`detail_levels`,
  `valid_values`, `matched_columns`, `grain`).
- **Names beside codes.** Every result that identifies a place carries
  its code and its name (`district_code` and `district_name`, ...). Codes
  are always kept: school names repeat across districts, names change
  over time (`former_names`), and joins run on codes.
- **Types from the schema, never guessed.** Codes are character (leading
  zeros survive: "0103", "13121"); `year` is integer; `integer` columns
  are integer (double if a value exceeds `.Machine$integer.max`);
  `number` columns double; `boolean` logical; proportions stay on the
  0-1 scale. Joined name columns are character. One internal typing
  function applies the schema to any data frame, whether it came from
  JSON or CSV.
- **`NA` means suppressed, not zero**, for most datasets. Surface the
  API's advisory saying so.
- **`sub_topic` is internal to the platform.** Never expose it as a
  parameter, a column, a printed field or a documented concept. Drop
  `sub_topic`, `topic` and `key` (which embeds it) from every result,
  print method, `gcd_meta()` and `gcd_describe()$raw`. The single
  exception is `gcd_contract()`, which returns the formal contract
  verbatim.
- **No base URL option.** The API base URL is one internal constant.
- **User agent:** `georgiacivicdata/<version> (+<GitHub URL>)`.

### Metadata, advisories and citation

- Every tibble from `gcd_rows()` carries a `gcd_meta` attribute: the
  response `meta` minus `key`, plus the request URL. `gcd_meta(x)` reads
  it; `gcd_citation(x)` formats the citation.
- Advisories print once per call as `cli` messages (one line each, the
  API's own message). `quiet = TRUE` per call or
  `options(gcd.quiet = TRUE)` silences them; they stay in
  `gcd_meta(x)$advisories`.

### Errors

- API errors become classed conditions via `rlang::abort()`: class
  `gcd_error` plus `gcd_error_<lowercase API code>`
  (`gcd_error_topic_not_found`). The message is the API's, formatted with
  `cli` and its `did_you_mean` suggestions; the condition carries
  `code`, `status` and `details` fields.
- The name resolver raises `gcd_error_place_not_found` and
  `gcd_error_place_ambiguous`.
- **Fail gracefully** (CRAN policy for internet resources): a transport
  failure or 5xx after retries raises `gcd_error_unavailable` with an
  informative message ("Couldn't reach the Georgia Civic Data API ...").
- Snapshot-test the messages (`expect_snapshot(error = TRUE)`).

### HTTP behavior

- Retry 429 and 503 automatically, honoring `Retry-After`, with a
  `cli` message while waiting (`req_retry()`; cap tries and total time).
- Timeouts: 60 s for metadata and JSON pages; generous for bulk CSV and
  geocoder uploads.
- Long filter lists: switch to `POST /datasets/{name}/query` when the
  URL would exceed about 6,000 characters. Invisible to the user.

### Caching

- **Metadata** (catalog, schemas, lookup tables) is cached in memory for
  the session, in a package-level environment
  (`the <- new.env(parent = emptyenv())`, per *R Packages*).
- **Rows: opt-in disk cache.** `cache = TRUE` on `gcd_rows()` (default
  `getOption("gcd.cache", FALSE)`) stores responses under
  `tools::R_user_dir("georgiacivicdata", "cache")` and revalidates with
  the ETag, so a cached copy is never served after the data changes.
  Prefer `httr2::req_cache()`; first confirm it sends `If-None-Match`,
  reuses on 304, and works with responses streamed to a file. If it
  doesn't fit the bulk CSV path, write a small ETag cache instead. Off by
  default: CRAN expects packages not to write files unless asked.
- **Location lookups are never cached**, in memory or on disk.
- Tests point the cache at `withr::local_tempdir()`; nothing in checks
  writes outside `tempdir()`.

### Places by name

Every function that takes `district_code`, `school_code` or
`county_fips` also takes `district`, `school` and `county` names. One
shared internal resolver turns them into codes before the API call:

- **Exact match only**, ignoring case, accents, surrounding whitespace
  and a trailing " County" on both sides, against the current name and
  every `"; "`-separated former name, using the cached lookup tables. No
  fuzzy matching.
- **No match:** `gcd_error_place_not_found`, suggesting near names from
  the lookup table's `q` text search.
- **More than one match:** `gcd_error_place_ambiguous`, listing the
  candidates with codes (and `active` for schools).
- **`school` needs a district** whenever the name exists in more than
  one district; within one district, two schools with one name (an old
  and a new one) are also ambiguous.
- **Tracts and block groups are code-only.**
- **Code or name, not both,** for the same kind of place
  (`district_code` and `district` together is an error).
- **Check the dataset first:** a name argument on a dataset without that
  column (`county` on a schools-only dataset) is a clear package error,
  before any data request.
- Resolved schools are sent as `school=DISTRICT-SCHOOL` pairs (or as
  `district_code` + `school_code` on routes without the pair filter).
- Accent folding must give the same result on Linux, macOS and Windows;
  test it on all three in CI.

## 6. Exported functions

Thirteen functions plus three utilities. Full rationale and examples are
in `notes/function-design.md`; this is the build spec.

### Find data

**`gcd_datasets(main_topic = NULL, level = NULL, year = NULL, kind = NULL,
details = FALSE)`**

- With no arguments returns **every dataset**: all subject areas,
  levels, years, tables and geometry. Each argument only narrows the
  list (server-side filters). `kind` is `"table"` or `"geometry"`.
- Output: tibble, one row per dataset. Compact: `name`, `title`,
  `summary`, `kind`, `main_topic`, `detail_levels` (list), `year_min`,
  `year_max`. With `details = TRUE` (`fields=full`), also `description`,
  `source`, `source_url`, `grain` (list), `default_detail`, `year_gaps`
  (list), `update_frequency`, `search_aliases_en`, `search_aliases_es`
  (lists), `updated_at` (POSIXct, UTC).
- Lookup tables are not rows; `gcd_dimension()`'s help names them.

**`gcd_search(query, main_topic = NULL, level = NULL, year = NULL,
n = 20)`**

- Output: tibble, best first: `rank`, `name`, `title`, `summary`,
  `main_topic`, `detail_levels` (list), `year_min`, `year_max`, `score`,
  `matched_on` (list), `matched_columns` (list).
- Attributes `confidence` and `retrieval`. On `low` confidence, message
  "Nothing in the catalog may fit this query." If retrieval fell back to
  keywords, say so. Print any `dimension_matches` as a hint line.
- `n` is 1 to 100. English or Spanish queries. The help page says the
  query is sent to the API (which embeds it with Voyage AI and never logs
  it) and that rankings can change between releases.

### Understand a dataset

**`gcd_describe(name)`**

- Routes by name to the dataset, lookup table or geometry dataset
  endpoint.
- Returns a `gcd_description` object (named list) with a `cli` print
  method: title, source, years with gaps, detail levels, grain, key
  metric, a **"Pick one value of"** line for columns whose filter has
  `requires_single_value`, and every declared note (limitations,
  `year_meaning`, series breaks, non-additive groups, partitions, pooled
  rates, year windows).
- Components: `$columns` (as `gcd_columns()`), `$filters` (tibble:
  `param`, `kind`, `values` (list), `multi_value`, `has_total`,
  `total_value`, `requires_single_value`, `nullable`), `$notes` (the
  contract declarations, each a tibble or string), `$raw` (the parsed
  response without `sub_topic`, `topic`, `key`).
- No `$recommended_query` (dropped with the `recommended` argument).

**`gcd_columns(name)`**

- Tibble, one row per column: `column`, `label`, `type`, `role`, `unit`,
  `is_key_metric`, `metric_component`, `nullable`, `valid_values` (list),
  `description`, `null_meaning`. Works for lookup tables and geometry
  datasets (`NA` where a field doesn't apply).

**`gcd_contract(name, file = NULL)`**

- The ODCS contract as a nested list (`format=json`). With `file`, write
  the YAML verbatim (`format=yaml`) and return the path invisibly.
- Datasets and `school_attendance_zones`. A lookup table, or a geometry
  dataset without a contract route, gives a clear error.

### Get data

**`gcd_rows(name, ..., year = NULL, detail = NULL, district = NULL,
school = NULL, county = NULL, labels = TRUE, columns = NULL,
sort = NULL, n_max = Inf, cache = getOption("gcd.cache", FALSE),
quiet = FALSE)`**

- **Returns every category and group** the filters don't exclude.
  Nothing is pinned by default.
- `...`: named filters. Categorical columns (`subject = "mathematics"`),
  geography codes (`district_code`, `school_code`, `county_fips`,
  `tract_geoid`, `block_group_geoid`), **`school_id`** (the API's
  `school` pair filter, `"761-0199"`), dimension attributes
  (`district_type`, `school_level`, `locale`, `demographic_category`),
  metric bounds (`graduation_rate_min = 0.9`). Vectors are OR within a
  filter, AND across filters. `NA` in a vector becomes `__null__`.
  Logicals become `true` / `false`. Unnamed arguments are an error.
- `year`: integer vector; a consecutive run (`2019:2024`) becomes
  `year_min` / `year_max`, anything else an exact list.
- `detail`: one level; default the schema's `default_detail`.
- `district`, `school`, `county`: names (section 5).
- `labels = TRUE`: the API's joined name columns, each relocated right
  after its code (`district_code`, `district_name`, `district_census_id`,
  `district_type`, ...; `demographic`, `demographic_label`,
  `demographic_category`), using `foreign_keys[].attribute_columns_added`
  (no hardcoded list). `labels = FALSE`: request only the dataset's own
  columns, then drop code columns that are `NA` on every row, so both
  settings give the same shape. Keep a column that is only partly `NA`.
- `columns`: explicit projection, passed through.
- `sort`, `n_max`: server-side order and row cap (`sort =
  "-unemployment_rate", n_max = 10`).
- Fetch strategy: first request JSON with `limit = min(n_max, 10000)`.
  If `has_more` is false, that is the result. Otherwise stream every row
  as CSV (no `limit`) to a temp file, read it with readr (all columns as
  character, then the typing function), truncate to `n_max`, and take
  `meta` and advisories from the first JSON page (document that the
  advisories then describe the first 10,000 rows). Show a `cli` progress
  indicator for large downloads.
- Output: typed tibble at one detail level, grain order (`year`,
  geography codes each followed by its names, `demographic` and its
  labels, other categoricals, metrics), `gcd_meta` attribute.
- Errors: a geometry dataset name points to `gcd_school_zones()` /
  `gcd_district_boundaries()`; a lookup table name points to
  `gcd_dimension()`. The API validates filters; the package only checks
  what it must (name arguments, argument types).

**`gcd_values(name, columns, ..., year = NULL, detail = NULL,
district = NULL, school = NULL, county = NULL)`**

- Tibble: one column per requested column (typed from the schema) plus
  `n_rows` (the API's `count`), most rows first. Warn when `truncated`
  (500-combination cap).

### Lookup tables

**`gcd_dimension(name, ..., district = NULL, school = NULL,
county = NULL, q = NULL, columns = NULL, n_max = Inf)`**

- `name`: `districts`, `schools`, `counties`, `tracts`, `block_groups`,
  `demographics` (named in the help page; an unknown name lists them).
- `...`: filters on the key, enum and boolean columns, and
  `county_fips` / `district_code` / `tract_geoid` (`active = TRUE`,
  `district_type = "state_charter"`). Name arguments as elsewhere
  (`gcd_dimension("schools", county = "Fulton")`).
- `q`: partial text search over names (the API's `q`): the browsing
  tool, unlike the exact name arguments.
- Output: tibble ordered by the primary key, typed from the lookup
  table's schema. Unfiltered tables are cached for the session (the
  resolver uses the same cache).
- The help page shows the school join pitfall:
  `left_join(by = c("district_code", "school_code"))`.

### Geography and school zones

`sf` is in Suggests. Each function takes `geometry = TRUE`; without `sf`
installed that gives an install hint, and `geometry = FALSE` returns a
plain tibble without `sf`. Read GeoJSON with `sf::read_sf()` (WGS 84).
Each takes `district` (and `school` where the route takes
`school_code`) beside the codes.

**`gcd_school_zones(district_code = NULL, school_code = NULL,
district = NULL, school = NULL, zone_level = NULL, grade = NULL,
year = NULL, resolution = c("display", "full"), geometry = TRUE)`**

- One row per zone: `year`, `district_code`, `district_name`,
  `school_code`, `school_name`, `zone_level`, `grade_low`, `grade_high`,
  `method`, `accuracy_class`, `currency_status`, `boundary_vintage`,
  `source_url`, `retrieved_on`, `area_sq_mi`, bounding box,
  `source_school_name` (the district map's spelling), geometry. Names
  come from the cached lookup tables. Keep the `sf` class through any
  join.
- The help page warns that a statewide `full` pull is large and that
  zones differ in precision (`method`, `accuracy_class`).

**`gcd_district_boundaries(district_code = NULL, district = NULL,
geometry = TRUE)`**

- One row per district piece: `district_code`, `district_name`, boundary
  type, NCES ids, geometry. Includes the Department of Defense districts.

**`gcd_school_zone_status(district_code = NULL, school_code = NULL,
district = NULL, school = NULL, zone_status = NULL,
no_zone_category = NULL)`**

- One row per school: `year`, `district_code`, `district_name`,
  `school_code`, `school_name`, `zone_status`, `zone_levels`,
  `no_zone_category`, `reason`. The API's `note` as an attribute.

**`gcd_school_zone_coverage(district_code = NULL, district = NULL,
geometry = FALSE)`**

- Pivoted long: one row per district and zone level: `year`,
  `district_code`, `district_name`, `tier`, `status`, `zone_level`,
  `level_status`, `pct_land_area`, `pct_population`, `zone_count`,
  `methods`, `accuracy_classes`, `reason` (pivot every per-level column
  the API returns). The district filter runs in R (the route takes none).
  `geometry = TRUE` uses `format=geojson`.

**`gcd_locate(lat = NULL, lon = NULL, address = NULL, id = NULL,
grade = NULL, year = NULL)`**

- Input: `lat` and `lon` (equal-length numeric vectors), or `address`
  (a character vector of one-line addresses, or a data frame with
  `street`, `city`, `state`, `zip`), not both. `id` defaults to
  `seq_along()` of the input. `grade` takes `"pk"`, `"k"`, `"01"` ...
  `"12"` (accept `"5"` and `"K"` too, normalized).
- **Output: long, one row per geographic unit per input.** Columns in
  order:
  1. `id`
  2. Input columns. Points: `lat`, `lon`. Addresses: `address` (the
     one-line address; built from the fields for a data frame),
     `match_status` (`match`, `no_match`, `tie`), `match_type` (`exact`,
     `non_exact`), `matched_address`, `lat`, `lon`.
  3. `geographic_type`: `county`, `tract`, `block_group`,
     `school_district`, `elementary_school`, `middle_school`,
     `high_school`.
  4. `geographic_id`: county FIPS, tract GEOID, block group GEOID,
     district code, or for a school `"DISTRICT-SCHOOL"` (`"761-4560"`,
     the form `gcd_rows()` takes as `school_id`).
  5. `geographic_name`: county, tract and block group names from the
     cached lookup tables; district and school names from the response.
  6. `grades`: the school row's grade range ("K-5", "3-5", "6-8",
     "9-12", "PK-5"), built from `grade_low` / `grade_high`; `NA` on
     other rows.
  7. `note`: `NA` normally; otherwise one plain sentence built from the
     API's own text.
- Row order per input: county, tract, block group, district, then the
  zones in the API's order (elementary, middle, high, by grade). A level
  can have more than one school row (split grade runs, K-2 and 3-5).
- `note` cases:
  - a level whose `level_status` is not `zoned` or
    `one_school_per_grade` gets one row for that level with `NA` id,
    name and grades, and a note from the status and `coverage_reason`
    (`not_available`: no zone collected yet; `gap`;
    `served_by_other_district`, naming the district from
    `served_elsewhere`);
  - `outside_georgia`, a per-point API error, or an address the
    geocoder couldn't match: one row for the input with `NA` geographic
    columns and the reason; never stop the batch;
  - a Department of Defense district: the district row has `NA` id, the
    response's name, and a note;
  - `currency_warning` / `overlap_warning`: the note on the school rows
    they concern.
- **Always POST**, in batches of up to 1,000 points with their ids. Join
  results back by position and check the echoed `id`.
- **Addresses never reach the Georgia Civic Data API.** Geocode them on
  the user's computer with the U.S. Census batch geocoder
  (`https://geocoding.geo.census.gov/geocoder/locations/addressbatch`,
  benchmark `Public_AR_Current`, a multipart CSV upload of id, street,
  city, state, ZIP; the response is a CSV of matches with coordinates).
  Then send the coordinates as points. Before writing this, read the
  Census documentation
  (<https://geocoding.geo.census.gov/geocoder/Geocoding_Services_API.html>)
  and confirm the current upload format, the maximum batch size (10,000
  as last documented), and how well a one-line address in the street
  field alone matches. If it matches poorly, split one-line addresses
  into fields first (or require the data-frame form). Split large lists
  into the maximum batch size, with a progress bar and generous
  timeouts.
- `assignment_note` (a zone is the default assignment, not the only
  option): an attribute, and a message once per session.
- Never cache, log or echo coordinates or addresses in messages or
  errors.
- Time one 1,000-point batch against production once and report it.

### Utilities

- **`gcd_meta(x)`**: the `gcd_meta` attribute as a list; an informative
  error if `x` has none.
- **`gcd_citation(x)`**: `x` is a tibble from `gcd_rows()` or a dataset
  name; returns the citation string ("{title}. Georgia Civic Data
  (georgiacivicdata.org), CC BY 4.0. {dataset URL}. Original source:
  {source}."), from `meta$citation` when present, else built from the
  schema in the same format. The docs explain the CC BY 4.0 attribution.
- **`gcd_cache_clear()`**: empties the session cache and the disk cache;
  returns invisibly.

## 7. Internal structure

Organize `R/` by topic, one file per exported function or family, with
helpers beside their callers or in shared files. A starting layout:

| File | Contents |
|---|---|
| `georgiacivicdata-package.R` | `"_PACKAGE"` doc, package-wide `@importFrom` / `@import` decisions |
| `api.R` | base URL constant, request builder (user agent, retries, timeouts, error hook), performing JSON and file requests, the error-envelope parser, classed conditions |
| `cache.R` | the session environment `the`, metadata getters with caching, disk-cache setup, `gcd_cache_clear()` |
| `schema.R` | fetching schemas, the typing function, label-column mapping and relocation, dropping internal fields (`sub_topic`, `topic`, `key`) |
| `params.R` | building query parameters: years, list filters, `NA` and logical encoding, `school_id`, URL-length check |
| `places.R` | the name resolver and name normalization |
| `datasets.R`, `search.R`, `describe.R`, `rows.R`, `values.R`, `dimension.R`, `zones.R`, `locate.R`, `geocode.R`, `meta.R` | the exports |
| `utils.R` | small shared helpers (a null-default operator if needed, tibble conversion) |

Keep each exported function short: argument checks, a call to shared
helpers, output shaping. Validate arguments with `rlang::arg_match()`
and simple checks with `cli::cli_abort()` messages naming the argument.
Internal helpers get roxygen comments with `@noRd`.

## 8. Documentation

- roxygen2 with markdown. Run `devtools::document()`; never edit `man/`
  or `NAMESPACE` by hand.
- Every export: a title, a description paragraph saying when to use it,
  every `@param` (type, default, accepted values), **`@returns`
  describing the object and each column** (CRAN requires `\value`),
  `@family` (find, describe, data, lookup, geography, utilities),
  `@seealso` linking related functions, and examples.
- **Examples hit the network, so wrap them in `@examplesIf
  interactive()`.** CRAN must never run them. Keep them short and
  realistic; tests carry the coverage.
- Document the data license (CC BY 4.0) and the "`NA` means suppressed"
  rule where users meet them (`gcd_rows()`, `gcd_citation()`, the
  package doc).
- Package-level doc (`?georgiacivicdata`) with an overview of the
  function families.
- `NEWS.md` (`usethis::use_news_md()`) with the initial version
  (`0.1.0`).
- `inst/WORDLIST` for `spelling` (place names, column names).

## 9. Tests

testthat 3e (`usethis::use_testthat(3)`). Tests must pass **offline**:
CRAN and the regular CI run them without network.

- **Recorded fixtures with httptest2.** `httptest2::with_mock_dir()`
  records a real response on the first run and replays it afterwards.
  Record each fixture once against production with small requests (a few
  rows: one district, one year), and commit them. Keep the recorded
  files small (the built tarball must stay well under 5 MB) and every
  path under 100 characters (R CMD check flags longer paths): use short
  mock directory names and httptest2's redactors to shorten file names.
- **Synthetic responses with httr2's own mocking**
  (`httr2::local_mocked_responses()`) for error envelopes, 429 retries,
  503 fallbacks, partial geocoder matches, and the Census upload
  (multipart boundaries are random, so recorded multipart requests don't
  replay reliably).
- **Pure helper tests without mocks:** year encoding, filter encoding
  (`NA`, logicals, vectors), name normalization (case, accents,
  " County", former names), ambiguity rules, the typing function (codes
  keep leading zeros), label relocation, all-`NA` column dropping, the
  coverage pivot, grade formatting, locate row assembly, citation
  formatting.
- **Snapshot tests** for print methods and every user-facing error and
  message (`expect_snapshot()`, `expect_snapshot(error = TRUE)`).
- **Live tests** (`tests/testthat/test-live.R`): a handful of end-to-end
  calls, skipped unless `Sys.getenv("GCD_LIVE_TESTS") == "true"`, plus
  `skip_on_cran()` and `skip_if_offline("georgiacivicdata.org")`. They
  run weekly in CI (section 12), not on every push, to keep traffic off
  the production usage metric.
- **Addresses:** only public buildings, for example the Georgia State
  Capitol (206 Washington St SW, Atlanta, GA 30334). Points: public
  landmarks.
- Guard Suggests (`skip_if_not_installed("sf")`); the r-hub
  `nosuggests` check must pass.
- Isolate state: `withr::local_options()`, `withr::local_tempdir()` for
  the disk cache, and reset the session cache between tests.
- Coverage: at least 90% (`covr::package_coverage()`); report the
  figure.

## 10. README, vignettes

### README

`usethis::use_readme_rmd()`; knit `README.Rmd` to `README.md` with
`devtools::build_readme()` (network is fine here: it runs locally, and
`README.Rmd` is build-ignored). Contents: what the package is and what
data it reaches; installation (`pak::pak("shanejorr/georgia-data-rpackage")`
until it is on CRAN); a short example per function family (find,
describe, rows with names, a zone map or a locate call); the data
license and how to cite; links to the website
(<https://georgiacivicdata.org>), the API docs and the pkgdown site
(<https://georgiacivicdata.org/r/>).
Badges: R-CMD-check, lifecycle "experimental".

### Vignettes

Three vignettes. Their code needs the network, which CRAN builds don't
have, so **precompute them**: write each as `vignettes/<name>.Rmd.orig`,
knit it locally to `vignettes/<name>.Rmd` with `knitr::knit()` (output
and figures baked in as static Markdown), and commit both. Add
`vignettes/precompile.R` (it knits every `.Rmd.orig` and moves figures
into `vignettes/`), and build-ignore the `.Rmd.orig` files and the
script. Follow rOpenSci's guide:
<https://ropensci.org/blog/2019/12/08/precompute-vignettes/>. Keep
figures compact (moderate `dpi`, PNG), since they ship in the tarball.

1. **`georgiacivicdata.Rmd`, "Get started"** (pkgdown's "Get started"
   page): finding data (`gcd_search()`, `gcd_datasets()`), understanding
   a dataset (`gcd_describe()`, `gcd_columns()`), getting rows with names
   and filters by name and code, years, detail levels, what `NA` means,
   totals beside subgroups (and why not to add them), `gcd_values()`,
   lookup tables and the school join, citing data, and the disk cache.
2. **`analysis.Rmd`, "Analyzing Georgia data"**: a real analysis
   joining datasets on codes. For example, district graduation rates
   alongside a Census measure of the same districts (child poverty or
   median household income), with rates pooled from their counts
   (`sum(numerator) / sum(denominator)`, never `mean()` of rates), a
   trend over years that respects any `series_breaks`, and `ggplot2`
   charts. Pick the datasets with `gcd_search()` and confirm the join
   keys and years exist before writing. Describe only what the data
   shows: association, not causation, and say what the figures can't
   tell.
3. **`school-zones.Rmd`, "School zones and places"**: a zone map for one
   district (`gcd_school_zones()` + `ggplot2::geom_sf()`), zone status
   (`gcd_school_zone_status()`), precision caveats (`method`,
   `accuracy_class`), `gcd_locate()` on public landmarks and the State
   Capitol's address, reading the long output, split grade runs, and the
   assignment note.

## 11. pkgdown site

- `usethis::use_pkgdown_github_pages()` (creates `gh-pages`, the deploy
  workflow, and enables Pages through the API).
- **Hosting: GitHub Pages, served through the main site.** CI deploys
  the built site to GitHub Pages at its default address,
  `https://shanejorr.github.io/georgia-data-rpackage/`. The main site's
  Vercel project forwards `https://georgiacivicdata.org/r/` to it with a
  Next.js rewrite, so visitors see the site under `georgiacivicdata.org`.
- **Site URL:** set `url: https://georgiacivicdata.org/r/` in
  `_pkgdown.yml`, replacing the `github.io` address that
  `use_pkgdown_github_pages()` writes, and make it the first `URL` entry
  in DESCRIPTION. pkgdown then writes canonical links and the sitemap
  for `georgiacivicdata.org/r/`, so search engines prefer it over the
  `github.io` copy.
- **No custom domain on GitHub Pages.** The site must stay at its
  `github.io` address, because that is what the rewrite forwards to. If
  GitHub Pages had a custom domain, it would redirect `github.io`
  requests to that domain and break the rewrite. Check that the
  deployed `gh-pages` branch has **no `CNAME` file** (pkgdown writes one
  only for a `url` without a path, so `/r/` should not produce one;
  verify after the first deploy, and delete it if it appears) and that
  the repo's Pages settings show no custom domain
  (`gh api repos/shanejorr/georgia-data-rpackage/pages`).
- **Relative links only.** The site works under `/r/` only if its
  internal links are relative, which pkgdown's are. After the first
  deploy, check the built HTML for absolute links to the `github.io`
  address (`grep -r "shanejorr.github.io" docs/` should find none), and
  that the navbar links to explicit `.html` files (folder URLs such as
  `reference/` make GitHub Pages redirect to its own address).
- **The main-site rewrite is Shane's change, not yours** (it lives in
  `~/projects/georgia-data`, which you never edit). For your final
  report, this is what it needs, in the array returned by `rewrites()`
  in `~/projects/georgia-data/web/next.config.ts`, the specific entries
  before the catch-all:

  ```ts
  // R package docs: pkgdown on GitHub Pages, served at /r/.
  { source: "/r", destination: "https://shanejorr.github.io/georgia-data-rpackage/index.html" },
  { source: "/r/:dir(reference|articles|news)", destination: "https://shanejorr.github.io/georgia-data-rpackage/:dir/index.html" },
  { source: "/r/:path*", destination: "https://shanejorr.github.io/georgia-data-rpackage/:path*" },
  ```

  The middle line exists because the site strips trailing slashes, so
  `/r/reference/` arrives as `/r/reference`; without it GitHub Pages
  would answer with a redirect to its own `github.io` address and
  visitors would leave `georgiacivicdata.org`.
- **Before the rewrite is live**, `https://georgiacivicdata.org/r/`
  returns 404, and `urlchecker::url_check()` and the remote CRAN check
  will flag the DESCRIPTION and README links to it. At the start of
  milestone 6, ask Shane to deploy the rewrite. Never remove or change
  the URL to make a check pass. Once it is live, confirm with `curl -sI`
  that `/r/`, `/r/reference/`, `/r/articles/` and one reference page
  return 200 from `georgiacivicdata.org` without redirecting to
  `github.io`.
- **Theme:** Bootstrap 5 with the platform's brand. Read the tokens in
  `~/projects/georgia-data/web/src/app/globals.css` (read-only): the
  primary color is `--color-brand-deep` (Tailwind red-700), the accent
  `--color-brand-accent` (red-600); fonts Inter (body), Figtree
  (headings), JetBrains Mono (code). Set them through `template: bslib:`
  and Google Fonts.
- **Reference index** grouped like section 6: Find data; Understand a
  dataset; Get data; Lookup tables; Geography and school zones;
  Utilities. Every export listed (`pkgdown::check_pkgdown()` enforces it).
- **Articles:** the three vignettes.
- **Navbar:** links to the Georgia Civic Data website and the API
  documentation. **Footer:** the data credit, "Data: Georgia Civic Data
  (georgiacivicdata.org), CC BY 4.0."
- Build locally (`pkgdown::build_site()`) to confirm, but never commit
  `docs/`; CI deploys.

## 12. GitHub Actions

Use the r-lib/actions templates through usethis:

1. **`R-CMD-check.yaml`**: `usethis::use_github_action("check-standard")`
   (macOS release, Windows release, Ubuntu devel, release and oldrel-1).
   Tests run on fixtures; no live calls.
2. **`pkgdown.yaml`**: from `use_pkgdown_github_pages()`; builds on
   pushes to `main` and deploys to `gh-pages`.
3. **`rhub.yaml`**: `rhub::rhub_setup()`; runs on demand through
   `rhub::rhub_check()`.
4. **`live-api.yaml`**: your own, scheduled weekly plus
   `workflow_dispatch`, Ubuntu release only, sets `GCD_LIVE_TESTS=true`,
   runs the live tests. It catches API changes without hitting the
   production API on every push.
5. **Optional `test-coverage.yaml`** (`use_github_action("test-coverage")`).
   Codecov uploads may need a token; if so, leave the step non-fatal
   (`fail_ci_if_error: false`) and tell Shane how to add `CODECOV_TOKEN`.

Add the R-CMD-check badge to the README. Watch runs with
`gh run list` / `gh run watch` and fix every failure.

## 13. CRAN checks

Run these, fix everything they report, and repeat until clean:

1. `devtools::document()`, then `devtools::test()`.
2. `spelling::spell_check_package()` (update `inst/WORDLIST` for real
   words only) and `urlchecker::url_check()`.
3. `devtools::check(remote = TRUE, manual = TRUE)`: **0 errors,
   0 warnings, 0 notes**, except "New submission". Fix every note, don't
   explain it away.
4. The GitHub Actions check matrix: green on every platform.
5. `rhub::rhub_check(platforms = c("linux", "macos-arm64", "windows",
   "ubuntu-next", "ubuntu-release", "nosuggests"))` (confirm current
   names with `rhub::rhub_platforms()`), and wait for green with
   `gh run watch`.
6. Last, `devtools::check_win_devel()`. Its results go by email to the
   maintainer (Shane), so report that it was submitted; Shane confirms
   the email.
7. `usethis::use_cran_comments()`: record the environments tested and
   their results in `cran-comments.md`.

CRAN rules to respect throughout (from *R Packages*' release chapter and
the CRAN policy):

- No network in examples, tests or vignette builds on CRAN (examples are
  `@examplesIf interactive()`, tests replay fixtures, vignettes are
  precomputed).
- Fail gracefully when the API is unreachable (`gcd_error_unavailable`).
- Never write outside `tempdir()` unless the user opts in (the disk
  cache); never change the user's options, working directory or
  graphics state without restoring them.
- Messages through `cli` / `message()`, never `print()` or `cat()`
  outside print methods.
- At most two cores in examples, tests and vignettes.
- ASCII-only R code (escape any non-ASCII with `\u`); file paths under
  100 characters; tarball under 5 MB.
- Every exported function has `\value`; titles are title case; software
  and service names are single-quoted in `Title` and `Description`.

## 14. `CLAUDE.md` and `AGENTS.md`

Write `CLAUDE.md` at the repo root for future agents working on this
package, then `ln -s CLAUDE.md AGENTS.md` (commit the symlink).
Build-ignore both. Start it with the line "`AGENTS.md` is a symlink to
this file; edit `CLAUDE.md` only." Cover:

- What the package is: an R client for
  `https://georgiacivicdata.org/api/v1`, the API's guide (read-only)
  at `~/projects/georgia-data/src/api/CLAUDE.md`, and that the API
  repo is a separate project agents here must not edit.
- Commands: `devtools::load_all()`, `document()`, `test()`,
  `check(remote = TRUE, manual = TRUE)`, `build_readme()`,
  `pkgdown::build_site()`, `Rscript vignettes/precompile.R`, the r-hub
  and coverage commands.
- Layout: the `R/` files and what lives where; `notes/` (planning
  documents and prompts, build-ignored, not part of the package).
- Conventions: the `gcd_` prefix, tibbles and `sf`, names beside codes,
  types from the schema, classed errors, `cli` messages, `sub_topic`
  never exposed, no base URL option.
- API usage rules: production only; every request counts in the
  platform's usage metric, so record fixtures once and keep live tests
  weekly; how to re-record a fixture; never commit a real home address;
  location lookups are never cached or logged.
- CRAN rules (section 13) and the release checklist.
- Testing rules (section 9).
- When to flag Shane: anything that changes what the package or the
  platform claims publicly, so the organization wiki's positioning note
  gets updated.
- The machine's constraints: no passwordless sudo, small `/tmp`, Shane
  monitors asynchronously; commit and push often.

## 15. Milestones

Commit (and push) at the end of each. Post a short progress update after
each.

1. **Setup:** R toolchain confirmed (section 2), package skeleton, git,
   GitHub repo, `.Rbuildignore`, DESCRIPTION, license, `CLAUDE.md` and
   `AGENTS.md`.
2. **Core layer:** `api.R`, `cache.R`, `schema.R`, `params.R`,
   `places.R`, with tests.
3. **Find and describe:** `gcd_datasets()`, `gcd_search()`,
   `gcd_describe()`, `gcd_columns()`, `gcd_contract()`, with fixtures,
   tests and docs.
4. **Data:** `gcd_rows()`, `gcd_values()`, `gcd_dimension()`,
   `gcd_meta()`, `gcd_citation()`, `gcd_cache_clear()`.
5. **Geography:** the four zone and boundary functions, then
   `gcd_locate()` with the Census geocoder.
6. **Docs:** README, the three vignettes (precomputed), pkgdown site.
   Ask Shane to deploy the main-site rewrite at the start (section 11).
7. **CI and CRAN:** the workflows, then every check in section 13 until
   clean.

## 16. Final report

End with a mobile-readable summary:

- each "Definition of done" item with its evidence (check output
  counts, the green GitHub Actions and r-hub run links, the coverage
  figure, the pkgdown build);
- the 1,000-point locate batch timing;
- anything you could not finish or verify, plainly;
- Shane's next steps: deploy the main-site rewrite (section 11) if it
  isn't live yet, confirm the win-builder email, and decide when to
  submit to CRAN;
- any place you departed from this prompt or the design doc, and why.

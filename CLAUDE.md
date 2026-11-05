`AGENTS.md` is a symlink to this file; edit `CLAUDE.md` only.

# georgiacivicdata: agent instructions

## What this is

`georgiacivicdata` is an R client for the Georgia Civic Data REST API,
`https://georgiacivicdata.org/api/v1` (production, read-only, no key). It
returns tidy tibbles typed from each dataset's schema, `sf` objects for
school attendance zones and district boundaries, and point and address
lookups.

- The API's own guide is `~/projects/georgia-data/src/api/CLAUDE.md`
  (routes, parameters, errors, rate limits, privacy rules). Read it, and
  the code under `~/projects/georgia-data/src/api/`, for exact response
  shapes. **That repo is a separate project: never edit anything in
  `~/projects/georgia-data` or any service it runs.**
- The Python package in `~/projects/georgia-data-pypackage` (also
  `georgiacivicdata`, pandas or Polars data frames) mirrors this one: the
  same exported functions without the `gcd_` prefix (`gcd.rows()` for
  `gcd_rows()`), the same arguments and the same output columns.
  `notes/function-design.md` here is the design for both.
- **Keep the two packages in parity, in both directions.** When this
  package changes or adds functionality (a new function, argument, column
  or behavior), the Python package must get the same change, and when the
  Python package changes or adds functionality, this package must follow.
  The only exceptions are the deliberate ones recorded in the Python
  package's `CLAUDE.md` ("Python and R differ"). The Python package is
  never edited from here: end any change here that it lacks by telling
  Shane exactly what the Python package needs, and before working on a
  feature, check the Python package for changes this package has not
  caught up with yet.
- The user-facing design, with its reasoning, is
  `notes/function-design.md`; the original build spec is
  `notes/build-package-prompt.md`. `notes/` holds planning documents and
  prompts only; it is build-ignored and not part of the package.

## Commands

Run from the repo root.

```r
devtools::load_all()
devtools::document()        # never edit man/ or NAMESPACE by hand
devtools::test()
devtools::check(remote = TRUE, manual = TRUE)
devtools::build_readme()    # knits README.Rmd (uses the network)
pkgdown::build_site()       # local preview only; never commit docs/
covr::package_coverage()    # keep >= 90%
spelling::spell_check_package()
urlchecker::url_check()
rhub::rhub_check(platforms = c("linux", "macos-arm64", "windows",
                               "ubuntu-next", "ubuntu-release", "nosuggests"))
```

```bash
Rscript vignettes/precompile.R            # re-knit the precomputed vignettes
GCD_LIVE_TESTS=true Rscript -e 'devtools::test(filter = "live")'
```

The GitHub token is read per session:
`Sys.setenv(GITHUB_PAT = system("gh auth token", intern = TRUE))`. Never
write it to `.Renviron` or any file.

## Layout

| File | Contents |
|---|---|
| `R/georgiacivicdata-package.R` | package doc, `@importFrom` declarations |
| `R/api.R` | base URL constant, request builder (user agent, retries, timeouts, error hook), JSON and file performers, the error-envelope parser, classed conditions |
| `R/cache.R` | the session environment `the`, cached metadata getters, the disk cache directory, `gcd_cache_clear()` |
| `R/schema.R` | schema fetching, the typing function `apply_schema_types()`, label-column relocation, dropping internal fields (`sub_topic`, `topic`, `key`) |
| `R/params.R` | query parameters: years, list filters, `NA` and logical encoding, `school_id`, the URL-length switch to `POST /query` |
| `R/places.R` | the place-name resolver (`district`, `school`, `county` to codes) and name normalization |
| `R/datasets.R`, `R/search.R` | find data |
| `R/describe.R` | `gcd_describe()`, `gcd_columns()`, `gcd_contract()`, the print method |
| `R/rows.R`, `R/values.R` | get data |
| `R/zones.R` | zones, boundaries, zone status, zone coverage |
| `R/locate.R`, `R/geocode.R` | `gcd_locate()` and the Census batch geocoder |
| `R/dimension.R` | `gcd_dimension()` and `lookup_table()`, the cached full tables the resolver and `gcd_locate()` read |
| `R/meta.R` | `gcd_meta()`, `gcd_citation()` |
| `R/utils.R` | small shared helpers |
| `tests/testthat/` | tests; recorded fixtures in short directories under `tests/testthat/` (httptest2) |
| `vignettes/*.Rmd.orig` | vignette sources; `*.Rmd` are knitted from them by `vignettes/precompile.R` (precomputed; figures land in `vignettes/`) |
| `vignettes/articles/agents.Rmd` | the "For LLM agents" page: a pkgdown-only article (build-ignored, not a vignette), listed in the Articles menu |
| `pkgdown/canonical.R` | adds `<link rel="canonical">` (to `georgiacivicdata.org/r/`) and `<link rel="alternate" type="text/markdown">` (to the page's `.md` copy) to every built page; run by the pkgdown workflow |
| `.github/workflows/` | `R-CMD-check.yaml` (5-platform matrix), `pkgdown.yaml` (deploys to `gh-pages`), `rhub.yaml` (on demand), `test-coverage.yaml`, `live-api.yaml` (weekly live tests) |

## Conventions

- `gcd_` prefix on every export. Code arguments use the API's parameter
  names (`district_code`, `county_fips`, `detail`, `year`); name
  arguments (`district`, `school`, `county`) sit beside them.
- Tibbles for tables, `sf` for geometry (`geometry = FALSE` gives a plain
  tibble and needs no `sf`). List-columns only where flattening would
  lose meaning.
- Names beside codes: every result that identifies a place carries its
  code and its name. Codes are always kept.
- Types come from the schema, never guessed: codes are character
  (leading zeros survive), `year` integer, `integer` integer (double past
  `.Machine$integer.max`), `number` double, `boolean` logical,
  proportions on the 0-1 scale. One function, `apply_schema_types()`,
  types any data frame from JSON or CSV.
- API errors are classed conditions: `gcd_error` plus
  `gcd_error_<lowercase code>`, with `code`, `status`, `details` fields.
  Transport failures and 5xx after retries are `gcd_error_unavailable`.
  The resolver raises `gcd_error_place_not_found` /
  `gcd_error_place_ambiguous`.
- Messages go through `cli`; never `print()` or `cat()` outside print
  methods. Advisories print once per call; `quiet = TRUE` or
  `options(gcd.quiet = TRUE)` silences them.
- **`sub_topic` is internal to the platform.** Never expose it as a
  parameter, column, printed field or documented concept. Drop
  `sub_topic`, `topic` and `key` from every result, print method,
  `gcd_meta()` and `gcd_describe()$raw`. Only `gcd_contract()` returns
  the contract verbatim.
- No base URL option: the URL is the internal constant `gcd_base_url`.
- Dependencies: Imports are `cli`, `curl`, `httr2`, `jsonlite`, `readr`,
  `rlang`, `tibble`, `tidyr`. No `dplyr` in Imports. Every Suggests use
  is guarded (`rlang::check_installed()`, `skip_if_not_installed()`).
- ASCII-only R code: escape non-ASCII as `\u` sequences.

## API usage rules

- The API is production. **Every request counts in the platform's usage
  metric.** Record fixtures once and replay them; live tests run weekly
  in CI only.
- To re-record a fixture: delete its directory under `tests/testthat/`
  (the `with_mock_dir()` name in the test), run that test file once with
  the network, check the recorded files are small and contain nothing
  personal, then commit. Keep requests small (one district, one year,
  a few rows).
- **Never commit a real home address** in code, tests, fixtures,
  examples or vignettes. Use public buildings (the Georgia State
  Capitol, 206 Washington St SW, Atlanta, GA 30334) and public landmarks.
- Location lookups (`POST /locate`, the Census geocoder) are never
  cached, in memory or on disk, and coordinates and addresses are never
  echoed in messages or errors. Addresses never reach the Georgia Civic
  Data API: they are geocoded with the Census batch geocoder and sent as
  points.

## Testing rules

- testthat 3e. Tests pass **offline**: CRAN and the regular CI have no
  network.
- Recorded fixtures with `httptest2::with_mock_dir()`; keep files small
  and every path under 100 characters.
- Synthetic responses with `httr2::local_mocked_responses()` for error
  envelopes, retries, 503s and the Census upload (multipart boundaries
  are random, so recorded uploads don't replay).
- Pure helper tests without mocks; snapshot tests for print methods and
  every user-facing error and message.
- Live tests in `tests/testthat/test-live.R` run only with
  `GCD_LIVE_TESTS=true`, and skip on CRAN and offline.
- Isolate state: `withr::local_options()`, `withr::local_tempdir()` for
  the disk cache, `local_gcd_state()` (helper) to reset the session
  cache. Nothing writes outside `tempdir()`.
- Guard Suggests with `skip_if_not_installed()`; the r-hub `nosuggests`
  check must pass.

## CRAN rules and release checklist

- No network in examples (`@examplesIf interactive()`), tests (fixtures)
  or vignette builds (precomputed `.Rmd.orig` -> `.Rmd`).
- Fail gracefully when the API is unreachable (`gcd_error_unavailable`).
- Never write outside `tempdir()` unless the user opts in (the disk
  cache); restore any options, working directory or graphics state.
- At most two cores; file paths under 100 characters; tarball under 5 MB.
- Every export has `\value`; titles in title case; software and service
  names single-quoted in `Title` and `Description`.
- Release checklist: `document()`, `test()`, `spell_check_package()`,
  `url_check()`, `check(remote = TRUE, manual = TRUE)` with 0/0/0 (only
  "New submission" allowed), the GitHub Actions matrix green,
  `rhub::rhub_check()` green, `devtools::check_win_devel()` (results go
  by email to Shane), update `cran-comments.md` and `NEWS.md`.
- **Never submit to CRAN** (`devtools::release()`, `submit_cran()`).
  Shane decides when.

## pkgdown site

- Deployed by `.github/workflows/pkgdown.yaml` to GitHub Pages at
  `https://shanejorr.github.io/georgia-data-rpackage/` and served at
  `https://georgiacivicdata.org/r/` through a rewrite in the main site
  (Shane's repo). `_pkgdown.yml` sets `url: https://georgiacivicdata.org/r/`.
- No custom domain on GitHub Pages and no `CNAME` on `gh-pages`: a
  custom domain would redirect `github.io` and break the rewrite.
- For LLM agents, pkgdown 2.2 writes `llms.txt` and a Markdown copy of
  every page (`page.md` beside `page.html`); `pkgdown/canonical.R` links
  each copy from its page's `<head>`. `vignettes/articles/agents.Rmd`
  documents both: keep it true when either changes.

## Gotchas learned while building

- In httr2 1.3, mocked responses (`local_mocked_responses()`, httptest2)
  bypass `req_retry()` and `req_cache()`. Offline tests check the retry and
  cache *settings* and the callbacks; the weekly live tests exercise real
  ETag revalidation.
- `.Rbuildignore` lines are Perl regular expressions, not globs.
- R code must stay ASCII: write non-ASCII as `\uXXXX` escapes, and never
  let a tool (a Python edit, for example) expand them into raw characters.
  `tools::showNonASCIIfile()` finds them.
- pkgdown renders every top-level `.md` file, so the pkgdown workflow
  deletes `CLAUDE.md` and `AGENTS.md` from its checkout before building.
- pkgdown's Pandoc reads a wrapped line that starts with one letter and a
  period ("R.") as a lettered list item, so the site showed "all from R."
  as a list starting at 18. Knitted Markdown wraps at 72 columns: reword a
  sentence rather than let "R." start a line.
- The httptest2 redactor (`tests/testthat/helper-gcd.R`) shortens URL
  prefixes so fixture paths stay under 100 bytes, keeps only the headers
  the package reads, and stores YAML and GeoJSON as plain text files.
- HTML Tidy (for the manual's HTML check) is unpacked without root into
  `~/.local/tidy` with a wrapper at `~/.local/bin/tidy`.
- School names repeat, and some schools have an old and a new record with
  one name (Fulton County's "Milton High School"): use unique names such as
  "Roswell High School" in examples.

## When to flag Shane

Anything that changes what the package or the platform claims publicly
(new data coverage, privacy behavior, license wording, the site URL), so
the organization wiki's positioning note gets updated.

## Machine constraints

- `sudo` is interactive: never run it; give Shane the exact command.
- `/tmp` is a small shared tmpfs. If a build fails with "Disk quota
  exceeded", `mkdir -p ~/tmp-rbuild` and set `TMPDIR=$HOME/tmp-rbuild`.
- Shane monitors asynchronously (often from a phone): post short,
  self-contained progress updates; state blocking decisions up front.
- Shane works on two machines: commit and push often.

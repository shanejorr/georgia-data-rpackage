## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

Every environment below gave 0 errors, 0 warnings and 0 notes apart from
the "New submission" note.

## Test environments

* Local: macOS 26.6.2 (aarch64), R 4.6.2,
  `devtools::check(remote = TRUE, manual = TRUE)`.
* GitHub Actions: macOS (release), Windows (release), Ubuntu (devel,
  release, oldrel-1).
* R-hub: linux (R-devel), macos-arm64 (R-devel), windows (R-devel),
  ubuntu-next, ubuntu-release, nosuggests.
* win-builder: R-devel (`devtools::check_win_devel()`; results by email to
  the maintainer).

## Notes for CRAN

* The package wraps a web API. Examples are wrapped in
  `@examplesIf interactive()`, tests replay recorded responses (they make no
  network calls), and the vignettes are precomputed, so no check step needs
  the network. Functions fail with an informative, classed error when the
  API is unreachable.
* The package writes no files unless the user turns on its disk cache
  (`cache = TRUE` or `options(gcd.cache = TRUE)`), which lives in
  `tools::R_user_dir("georgiacivicdata", "cache")`.

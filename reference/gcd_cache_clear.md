# Clear the session cache and the disk cache

Empties the in-memory cache of metadata (the catalog, dataset schemas
and lookup tables) kept for the R session, and deletes the opt-in disk
cache of row downloads (see the `cache` argument of
[`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md)).
Location lookups are never cached, so there is nothing to clear for
them.

## Usage

``` r
gcd_cache_clear()
```

## Value

`NULL`, invisibly.

## Details

The disk cache lives in
`tools::R_user_dir("georgiacivicdata", "cache")`. It is only ever
written when you ask for it, with `cache = TRUE` or
`options(gcd.cache = TRUE)`.

## See also

[`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md) for
the disk cache.

Other utilities:
[`gcd_citation()`](https://georgiacivicdata.org/r/reference/gcd_citation.md),
[`gcd_meta()`](https://georgiacivicdata.org/r/reference/gcd_meta.md)

## Examples

``` r
gcd_cache_clear()
```

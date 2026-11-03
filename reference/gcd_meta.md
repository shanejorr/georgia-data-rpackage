# Get the metadata carried by a result

Every tibble from
[`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md)
carries the response's metadata as an attribute: what the rows are,
where they come from and how to cite them. `gcd_meta()` returns it.

Many dplyr verbs drop attributes, so read the metadata from the result
as it came back.
[`gcd_citation()`](https://georgiacivicdata.org/r/reference/gcd_citation.md)
also accepts a dataset name.

## Usage

``` r
gcd_meta(x)
```

## Arguments

- x:

  A tibble returned by
  [`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md).

## Value

A named list: `dataset` (the name), `title`, `detail`, `key_metric`,
`units` (a named list of each metric's unit), `null_semantics` (what a
missing value means), `source`, `source_url`, `citation`, `license`,
`schema` (the schema's path), `advisories` (a tibble of `code` and
`message`), `year_meaning`, `omitted_columns` (columns left out because
they were empty), `data_version`, `updated_at` and `request_url`. Fields
the API didn't send are absent.

## See also

[`gcd_citation()`](https://georgiacivicdata.org/r/reference/gcd_citation.md)
to cite the data.

Other utilities:
[`gcd_cache_clear()`](https://georgiacivicdata.org/r/reference/gcd_cache_clear.md),
[`gcd_citation()`](https://georgiacivicdata.org/r/reference/gcd_citation.md)

## Examples

``` r
if (FALSE) { # interactive()
grad <- gcd_rows("graduation_rate_4_year_cohort", district = "Fulton County",
                 year = 2024, demographic = "all")
gcd_meta(grad)$advisories
}
```

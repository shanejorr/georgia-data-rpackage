# Cite a dataset

The citation for data from Georgia Civic Data, ready to paste:

"{title}. Georgia Civic Data (georgiacivicdata.org), CC BY 4.0. {dataset
URL}. Original source: {source}."

## Usage

``` r
gcd_citation(x)
```

## Arguments

- x:

  A tibble returned by
  [`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md),
  or a dataset name.

## Value

A single string: the citation. For a result of
[`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md) it
is the API's own citation; for a name it is built from the dataset's
schema in the same format.

## License and attribution

The data is published under the Creative Commons Attribution 4.0
International license (CC BY 4.0,
<https://creativecommons.org/licenses/by/4.0/>). You may share and adapt
it for any purpose, including commercially, as long as you give credit:
name Georgia Civic Data (georgiacivicdata.org) and the original source,
link the license, and say if you changed the data. The citation covers
all three. The license covers Georgia Civic Data's cleaning,
standardization, compilation and documentation; the source data stays
under its original publisher's terms.

## See also

[`gcd_meta()`](https://georgiacivicdata.org/r/reference/gcd_meta.md) for
all the metadata.

Other utilities:
[`gcd_cache_clear()`](https://georgiacivicdata.org/r/reference/gcd_cache_clear.md),
[`gcd_meta()`](https://georgiacivicdata.org/r/reference/gcd_meta.md)

## Examples

``` r
if (FALSE) { # interactive()
gcd_citation("graduation_rate_4_year_cohort")

grad <- gcd_rows("graduation_rate_4_year_cohort", district = "Fulton County",
                 year = 2024, demographic = "all")
gcd_citation(grad)
}
```

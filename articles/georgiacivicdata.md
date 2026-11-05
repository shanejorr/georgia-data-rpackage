# Get started with georgiacivicdata

georgiacivicdata reads the [Georgia Civic
Data](https://georgiacivicdata.org) API: cleaned public data about
Georgia’s schools and communities. The [home
page](https://georgiacivicdata.org/r/) walks through the basic workflow
(search for a dataset, read its columns, get its rows, plot them and
cite them) with Fulton County’s graduation rate. This article covers
what that example leaves out: how to narrow the catalog, how names and
filters work, and the rules of the data that are easy to get wrong.

``` r

library(georgiacivicdata)
library(dplyr)
```

## Browse the catalog

[`gcd_datasets()`](https://georgiacivicdata.org/r/reference/gcd_datasets.md)
is the whole catalog, one row per dataset. Every argument narrows it on
the server:

``` r

catalog <- gcd_datasets()
count(catalog, main_topic, kind)
#> # A tibble: 5 x 3
#>   main_topic  kind         n
#>   <chr>       <chr>    <int>
#> 1 census      table       28
#> 2 education   geometry     2
#> 3 education   table       61
#> 4 health      table       62
#> 5 immigration table       23

gcd_datasets(main_topic = "education", level = "districts", year = 2025) |>
  select(name, title)
#> # A tibble: 51 x 2
#>    name                                     title                               
#>    <chr>                                    <chr>                               
#>  1 ccrpi_content_mastery                    CCRPI Content Mastery               
#>  2 ccrpi_graduation_rate                    High School Graduation Rates        
#>  3 ccrpi_progress                           CCRPI Progress                      
#>  4 ccrpi_readiness                          CCRPI Readiness                     
#>  5 ccrpi_scoring_by_component               CCRPI Scores and Components         
#>  6 enrollment_by_grade                      Enrollment by Grade Level (Fall and~
#>  7 enrollment_march_gender_race_ethnicity   March Enrollment by Race and Gender 
#>  8 enrollment_october_disability            Special Education Enrollment by Dis~
#>  9 enrollment_october_gender_race_ethnicity October Enrollment by Race and Gend~
#> 10 free_reduced_lunch                       Free and Reduced-Price Lunch Eligib~
#> # i 41 more rows
```

## Read a dataset’s notes

[`gcd_describe()`](https://georgiacivicdata.org/r/reference/gcd_describe.md)
prints what a dataset holds, where it comes from, its years and detail
levels, the columns that identify a row (its *grain*) and the notes its
data contract declares:

``` r

gcd_describe("graduation_rate_4_year_cohort")
#> -- Four-Year Cohort Graduation Rate (graduation_rate_4_year_cohort) ------------
#> Share of the four-year high school cohort that graduated, by school, district,
#> and state and demographic subgroup, 2004-2025.
#> 
#> Source: Governor's Office of Education and Workforce Strategy (GOEWS, formerly
#> GOSA)
#> Years: 2004-2025
#> Detail levels: districts, schools (default), states
#> Grain: year, district_code, school_code, demographic
#> Key metric: graduation_rate
#> Columns: 7, plus 6 joined name columns (see `$columns`); filters: 18 (see
#> `$filters`)
#> 
#> -- Notes -----------------------------------------------------------------------
#> * Missing values: NA means suppressed (small counts), not zero; zeros are real
#>   from 2010 on.
#> * Limitations: 2004-2010 figures predate Georgia's adoption of the federal
#>   four-year adjusted-cohort methodology (ACGR, first reported 2011) and use the
#>   state's earlier leaver-based rate; the 2010->2011 state rate drop (~81% to
#>   ~67%) is a methodology break, not a real decline <U+2014> do not trend across it.
#>   Suppressed cells are NULL (not zero) from 2010 onward, but 2004-2009 sources
#>   use literal ZEROS for suppressed cells <U+2014> a zero rate/count in those years may
#>   be real or suppressed and cannot be distinguished; treat very small cohorts
#>   in 2004-2009 with caution. num_cohort is NULL for every row in 2012-2016 (the
#>   source publishes no denominator in those years). The 2004 file lists every
#>   public school, including elementary and middle schools with no graduating
#>   cohort, so 1,703 of its 2,037 all-students school rows have no graduate count
#>   or rate; from 2005 only schools with a graduating cohort are listed (344 in
#>   2005). School rows do not always sum to the published district row: of the
#>   42,815 district rows (all subgroups) with a published num_graduates and at
#>   least one published school value, 468 publish a district num_graduates below
#>   the sum of its school rows, 49 of them among the 4,039 all-students rows
#>   (source-published, 2005-2025; e.g. 2016 Whitfield 709 vs 810, 2014 Richmond
#>   economically_disadvantaged 582 vs 1,286) <U+2014> use the official district/state
#>   rows for rollups rather than summing school rows. economically_disadvantaged
#>   is not a like-for-like group across years. Statewide it is 55-56% of the
#>   cohort in 2017-2021, then 47% (2022), 53% (2023), 61% (2024) and 66% (2025),
#>   and district coding shifts: Cobb County puts 98% of its 2021 cohort in the
#>   group (36-38% in 2017-2020 and 2023, 20% in 2022) and under 2% of its
#>   graduates in 2011, 2012 and 2014, and districts with 100+ graduates that
#>   report 10% or less of them in the group or suppress it number 6-11 a year in
#>   2021-2023 (0-2 a year in 2016-2020). GOEWS does not document these shifts.
#>   The group's graduation rate moves when its membership does, so check its
#>   share of the cohort before comparing it across years or districts. The race
#>   axis uses the combined asian_pacific_islander bucket <U+2014> not comparable
#>   row-for-row with split-convention topics without aggregating those topics'
#>   asian + pacific_islander rows at query time. State rows have NULL
#>   district_code and school_code; district rows have NULL school_code.
#> * Series break in 2011: From 2011 Georgia reports the federal four-year
#>   adjusted-cohort graduation rate, while 2004-2010 use the state's earlier
#>   leaver-based count, so the state rate falls from 0.808 (2010) to 0.675 (2011)
#>   and the cohort rises from 113,364 to 131,012 because the method changed, not
#>   because fewer students graduated.
```

Some categorical columns have no total.
[`gcd_describe()`](https://georgiacivicdata.org/r/reference/gcd_describe.md)
lists them under **“Pick one value of”**: for example, `grade_cluster`
and `subject` in `ccrpi_content_mastery`, whose values must not be mixed
in one summary.

``` r

d <- gcd_describe("ccrpi_content_mastery")
d$filters |>
  filter(kind == "categorical") |>
  select(param, has_total, requires_single_value)
#> # A tibble: 4 x 3
#>   param           has_total requires_single_value
#>   <chr>           <lgl>     <lgl>                
#> 1 grade_cluster   FALSE     TRUE                 
#> 2 assessment_type FALSE     FALSE                
#> 3 subject         FALSE     TRUE                 
#> 4 ccrpi_flag      FALSE     FALSE
```

## Filter by name or by code

Name a district, school or county and the package turns it into a code.
Names match exactly, ignoring case, accents and a trailing “County”, and
former names work too:

``` r

gcd_rows(
  "graduation_rate_4_year_cohort",
  district = "Fulton County",
  school = "Riverwood High School",   # a former name
  demographic = "all",
  year = 2021:2025
) |>
  select(year, district_code, school_code, school_name, graduation_rate)
#> i Demographic groups overlap across categories and may overlap within a
#>   category (active_duty can be a subset of military_connected). Read the
#>   dataset's definitions and non_additive declarations. Use the published `all`
#>   total when available, never add it to its subgroups. Counts reconcile only
#>   for complete, disjoint groups; subgroup rates generally do not add to the
#>   overall rate.
#> # A tibble: 5 x 5
#>    year district_code school_code school_name                    graduation_rate
#>   <int> <chr>         <chr>       <chr>                                    <dbl>
#> 1  2021 660           3066        Riverwood International Chart~           0.934
#> 2  2022 660           3066        Riverwood International Chart~           0.975
#> 3  2023 660           3066        Riverwood International Chart~           0.969
#> 4  2024 660           3066        Riverwood International Chart~           0.988
#> 5  2025 660           3066        Riverwood International Chart~           0.971
```

A name that matches more than one place stops with the candidates
instead of guessing. “Eastside Elementary School” is in several
districts, and Fulton County has an old and a new “Milton High School”:

``` r

gcd_rows("graduation_rate_4_year_cohort", school = "Milton High School",
         district = "Fulton County")
#> Error in `gcd_rows()`:
#> ! "Milton High School" matches more than one school.
#> i Use `school_id` with one "DISTRICT-SCHOOL" code.
#> * 660-0106: Milton High School (Fulton County, active)
#> * 660-2060: Milton High School (Fulton County, inactive)
```

Codes work everywhere names do. A school is identified by its district
and school codes together, written `"DISTRICT-SCHOOL"` in `school_id`:

``` r

gcd_rows("graduation_rate_4_year_cohort", school_id = "660-0106",
         demographic = "all", year = 2025, quiet = TRUE) |>
  select(year, school_code, school_name, num_graduates, num_cohort, graduation_rate)
#> # A tibble: 1 x 6
#>    year school_code school_name        num_graduates num_cohort graduation_rate
#>   <int> <chr>       <chr>                      <int>      <int>           <dbl>
#> 1  2025 0106        Milton High School           502        522           0.962
```

## Years and detail levels

`year = 2021:2025` asks for a range; `year = c(2015, 2025)` asks for
those two years only. Each call returns one **detail level**: schools,
districts, states, counties or tracts, whatever the dataset publishes.
The default is the finest level (counties for Census datasets). Columns
that would be empty at a level are left out:

``` r

state <- gcd_rows("graduation_rate_4_year_cohort", detail = "states",
                  demographic = "all", year = c(2015, 2025), quiet = TRUE)
state
#> # A tibble: 2 x 7
#>    year demographic demographic_label demographic_category num_graduates
#>   <int> <chr>       <chr>             <chr>                        <int>
#> 1  2015 all         All               aggregate                    98465
#> 2  2025 all         All               aggregate                   123911
#> # i 2 more variables: num_cohort <int>, graduation_rate <dbl>
```

To combine levels, call once per level and bind the rows.

## What `NA` means

A missing metric usually means the value was **suppressed** to protect
privacy (small counts), **not zero**. The schema’s `null_semantics` says
which, and
[`gcd_rows()`](https://georgiacivicdata.org/r/reference/gcd_rows.md)
prints the API’s advisory when a result holds suppressed values:

``` r

small <- gcd_rows("graduation_rate_4_year_cohort", district = "Appling County",
                  year = 2024, detail = "districts")
#> i This result contains NULL metric cells, which mean the value was SUPPRESSED
#>   (small counts), not zero — do not report or chart a NULL as 0 (see
#>   null_semantics and each column's null_meaning).
#> i Demographic groups overlap across categories and may overlap within a
#>   category (active_duty can be a subset of military_connected). Read the
#>   dataset's definitions and non_additive declarations. Use the published `all`
#>   total when available, never add it to its subgroups. Counts reconcile only
#>   for complete, disjoint groups; subgroup rates generally do not add to the
#>   overall rate.
#> i `district_census_id` is a 5-digit Census school-district code, NOT a county
#>   FIPS, and a district is not 1:1 with a county — do not map these district
#>   rows as counties.
small |>
  select(demographic, num_graduates, num_cohort, graduation_rate)
#> # A tibble: 18 x 4
#>    demographic                    num_graduates num_cohort graduation_rate
#>    <chr>                                  <int>      <int>           <dbl>
#>  1 active_duty                               NA         NA          NA    
#>  2 all                                      225        240           0.938
#>  3 asian_pacific_islander                    NA         NA          NA    
#>  4 black                                     57         62           0.919
#>  5 economically_disadvantaged               225        240           0.938
#>  6 english_learners                          13         14           0.929
#>  7 female                                   111        114           0.974
#>  8 foster_care                               NA         NA          NA    
#>  9 hispanic                                  42         44           0.954
#> 10 homeless                                  NA         NA          NA    
#> 11 male                                     114        126           0.905
#> 12 migrant                                   18         20           0.9  
#> 13 multiracial                               NA         NA          NA    
#> 14 native_american                           NA         NA          NA    
#> 15 not_economically_disadvantaged            NA         NA          NA    
#> 16 students_with_disabilities                25         31           0.807
#> 17 students_without_disabilities            200        209           0.957
#> 18 white                                    119        127           0.937
```

The advisories stay with the result in `gcd_meta(small)$advisories`;
`quiet = TRUE` (or `options(gcd.quiet = TRUE)`) silences the messages.

## Totals beside subgroups

Nothing is pinned by default, so a result holds the `all` total beside
every subgroup, and subgroups from different categories overlap (a
student is in a race group, a gender group and an economic group at
once). Never add them up:

``` r

fulton <- gcd_rows("graduation_rate_4_year_cohort", district = "Fulton County",
                   detail = "districts", year = 2025, quiet = TRUE)

fulton |>
  summarise(
    published_total = num_cohort[demographic == "all"],
    sum_of_every_row = sum(num_cohort, na.rm = TRUE)
  )
#> # A tibble: 1 x 2
#>   published_total sum_of_every_row
#>             <int>            <int>
#> 1            7934            39902
```

Use the published `all` row for totals, and filter one category
(`demographic_category = "race"`) to compare groups.

## Which values exist: `gcd_values()`

When a filter returns nothing,
[`gcd_values()`](https://georgiacivicdata.org/r/reference/gcd_values.md)
shows which combinations exist under the other filters, with row counts,
without downloading rows:

``` r

gcd_values("ccrpi_content_mastery", c("grade_cluster", "subject"),
           year = 2025, detail = "districts")
#> # A tibble: 11 x 3
#>    grade_cluster subject               n_rows
#>    <chr>         <chr>                  <int>
#>  1 elementary    english_language_arts   2340
#>  2 elementary    mathematics             2340
#>  3 elementary    science                 2340
#>  4 high          english_language_arts   2340
#>  5 high          mathematics             2340
#>  6 high          science                 2340
#>  7 high          social_studies          2340
#>  8 middle        english_language_arts   2340
#>  9 middle        mathematics             2340
#> 10 middle        science                 2340
#> 11 middle        social_studies          2340
```

## Lookup tables

There are six lookup tables: `districts`, `schools`, `counties`,
`tracts`, `block_groups` and `demographics`.
[`gcd_dimension()`](https://georgiacivicdata.org/r/reference/gcd_dimension.md)
returns any of them. **School codes repeat across districts**, so join
schools on `district_code` and `school_code` together, never
`school_code` alone:

``` r

gcd_dimension("schools", columns = c("district_code", "school_code")) |>
  count(school_code, sort = TRUE) |>
  head(3)
#> # A tibble: 3 x 2
#>   school_code     n
#>   <chr>       <int>
#> 1 8010          198
#> 2 8012          175
#> 3 8013          166
```

## Caching

Metadata (the catalog, schemas and lookup tables) is cached for the R
session. Rows can also be cached on disk, if you ask:

``` r

options(gcd.cache = TRUE)   # or cache = TRUE in gcd_rows()
```

Cached responses are kept with their `ETag` in
`tools::R_user_dir("georgiacivicdata", "cache")`, and each repeat asks
the server whether the data changed: an unchanged answer reuses the
saved copy without downloading, and a new data release downloads afresh
(a response the server marks fresh, for five minutes, is reused without
asking).
[`gcd_cache_clear()`](https://georgiacivicdata.org/r/reference/gcd_cache_clear.md)
empties both caches.

# Dallas Fed Trimmed-Mean PCE component dictionary

A tibble mapping each of the 177 components used in the Federal Reserve
Bank of Dallas's trimmed-mean PCE inflation rate to its corresponding
series in BEA NIPA Table 2.4.4U (Fisher price index for personal
consumption expenditures by type of product, monthly).

## Usage

``` r
dallasTrimPCEcomponents
```

## Format

A tibble with 177 rows and 5 variables:

- dallas_idx:

  Integer. Ordinal position in the Dallas Fed tech-notes list.

- name:

  Character. Component name as published by the Dallas Fed.

- series_code:

  Character. BEA NIPA series code in Table 2.4.4U.

- line_no:

  Integer. Line number in BEA Table 2.4.4U.

- bea_label:

  Character. Label BEA publishes alongside `series_code`.

## Source

Dolmas, J. (2009, updated 2022-12-23). "PCE Inflation: Technical Note."
Federal Reserve Bank of Dallas. BEA NIPA Table 2.4.4U.

## Details

Components are organized as durables (1-41), nondurables (42-91),
services (92-177), and one NPISH aggregate (178). The 2009 tech notes
(Dolmas, "Trimmed Mean PCE Inflation," updated 2022-12-23) list 178
components; BEA combined two of them - Tenant-Occupied Stationary Homes
and Tenant Landlord Durables - into a single line of Table 2.4.4U
(`IA000629`) when the disaggregated series stopped in December 2001. The
mapping reflects that combination, yielding 177 rows; `dallas_idx` runs
1..178 with 94 omitted (93 holds the merged item).

## References

Atkinson, T., Dolmas, J., & Zarutskie, R. (2026). "Skewness warrants
caution as Trimmed Mean PCE inflation eases." Federal Reserve Bank of
Dallas, April 16, 2026.

## Examples

``` r
data(dallasTrimPCEcomponents)
head(dallasTrimPCEcomponents)
#> # A tibble: 6 × 5
#>   dallas_idx name               series_code line_no bea_label         
#>        <int> <chr>              <chr>         <int> <chr>             
#> 1          1 New Domestic Autos DNDCRG            7 New domestic autos
#> 2          2 New Foreign Autos  DNFCRG            8 New foreign autos 
#> 3          3 New Light Trucks   DNWTRG            9 New light trucks  
#> 4          4 Used Autos         DNPURG           13 Used autos        
#> 5          5 Used Light Trucks  DUTRRG           17 Used light trucks 
#> 6          6 Tires              DTATRG           21 Tires             
```

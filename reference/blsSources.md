# List available BLS sources

List available BLS sources

## Usage

``` r
blsSources(tier = NULL, status = "current", pattern = NULL)
```

## Arguments

- tier:

  Optional integer vector; 1 = release-calendar workhorses, 2 =
  annual/structural, 3 = specialist, 4 = discontinued.

- status:

  `"current"`, `"discontinued"`, or `NULL` for both. Default
  `"current"`.

- pattern:

  Optional regex matched against `name` and `title`.

## Value

A tibble: one row per source, with `name`, `prefix`, `file` (default
data file), `title`, `frequency`, `tier`, `approx_mb`, `status`,
`notes`, `url`.

## Examples

``` r
if (FALSE) { # \dontrun{
  blsSources()
  blsSources(tier = 1)
  blsSources(pattern = "price")
} # }
```

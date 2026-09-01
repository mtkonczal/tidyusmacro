# List every file BLS publishes for a source

List every file BLS publishes for a source

## Usage

``` r
blsFiles(source, email, data_only = TRUE)
```

## Arguments

- source:

  A registry name (see
  [`blsSources`](https://www.mikekonczal.com/tidyusmacro/reference/blsSources.md))
  or a bare two-letter BLS prefix (e.g. `"wp"`).

- email:

  Contact email, required by BLS in the user agent.

- data_only:

  Logical, default `TRUE`: return only `.data.*` files, not lookup
  tables.

## Value

A tibble: `stem` (pass to `getBLSFiles(..., file = )`), `mb`, `modified`
(remote mtime), `file` (full BLS name).

## Examples

``` r
if (FALSE) { # \dontrun{
  blsFiles("ppi", "your.email@example.com")
} # }
```

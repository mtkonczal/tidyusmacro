# ESP Color Palette

Named character vector of ESP-branded colors, used by
[`scale_color_esp`](https://www.mikekonczal.com/tidyusmacro/reference/esp_theme.md)
and
[`scale_fill_esp`](https://www.mikekonczal.com/tidyusmacro/reference/esp_theme.md).

## Usage

``` r
esp_pal
```

## Format

A named character vector of three hex colors:

- "Warm Navy":

  `"#2c3254"`

- "Warm Red":

  `"#ff8361"`

- "Soft Green":

  `"#70ad8f"`

## See also

[`esp_navy`](https://www.mikekonczal.com/tidyusmacro/reference/esp_navy.md),
[`theme_esp`](https://www.mikekonczal.com/tidyusmacro/reference/esp_theme.md)

## Examples

``` r
esp_pal
#>  Warm Navy   Warm Red Soft Green 
#>  "#2c3254"  "#ff8361"  "#70ad8f" 
esp_pal[["Warm Red"]]
#> [1] "#ff8361"
```

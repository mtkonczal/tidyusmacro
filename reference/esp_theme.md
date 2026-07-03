# ESP Theme and Color Scales

Custom ggplot2 theme and discrete color/fill scales for Economic
Security Project graphics.

## Usage

``` r
theme_esp(base_family = "Public Sans")

scale_color_esp(...)

scale_fill_esp(...)

scale_colour_esp(...)
```

## Arguments

- base_family:

  Base font family for the theme. Defaults to "Public Sans"; if the font
  is not installed, ggplot2 falls back to the default sans font.

- ...:

  Passed to the underlying ggplot2 scale functions
  ([`scale_color_manual`](https://ggplot2.tidyverse.org/reference/scale_manual.html)
  /
  [`scale_fill_manual`](https://ggplot2.tidyverse.org/reference/scale_manual.html)).

## Value

`theme_esp()` returns a
[`theme`](https://ggplot2.tidyverse.org/reference/theme.html) object;
the scale functions return ggplot2 scale objects. All are added to a
plot with `+`.

## Details

`theme_esp()` builds on
[`theme_minimal`](https://ggplot2.tidyverse.org/reference/ggtheme.html)
with an ESP house style. Note several opinionated defaults: a cream plot
background (`"#f4f2e4"`), no minor gridlines, and **axis titles and the
legend removed entirely**. Label lines directly (e.g., with
[`annotate()`](https://ggplot2.tidyverse.org/reference/annotate.html) or
[`geom_text()`](https://ggplot2.tidyverse.org/reference/geom_text.html))
or re-enable the legend with `theme(legend.position = ...)` after
`theme_esp()`.

`scale_color_esp()` and `scale_fill_esp()` apply the
[`esp_pal`](https://www.mikekonczal.com/tidyusmacro/reference/esp_pal.md)
palette (three colors, so at most three discrete levels).
`scale_colour_esp()` is an alias.

## See also

[`esp_pal`](https://www.mikekonczal.com/tidyusmacro/reference/esp_pal.md),
[`esp_navy`](https://www.mikekonczal.com/tidyusmacro/reference/esp_navy.md)

## Examples

``` r
# Plots are assigned rather than printed: rendering requires the
# "Public Sans" font, which check machines may not have registered.
library(ggplot2)

p1 <- ggplot(economics, aes(date, unemploy / pop)) +
  geom_line(color = esp_navy) +
  labs(
    title = "Unemployment share of population",
    caption = "Source: FRED via ggplot2::economics."
  ) +
  theme_esp()

# Multiple series (palette has 3 colors, so at most 3 levels);
# theme_esp() removes the legend, so label lines directly
dat <- subset(economics_long, variable %in% c("psavert", "uempmed", "unemploy"))
p2 <- ggplot(dat, aes(date, value01, color = variable)) +
  geom_line() +
  scale_color_esp() +
  theme_esp()

# print(p1) or print(p2) to render (needs the font installed)
```

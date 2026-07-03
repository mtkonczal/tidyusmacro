#' ESP Theme and Color Scales
#'
#' Custom ggplot2 theme and discrete color/fill scales for Economic Security
#' Project graphics.
#'
#' \code{theme_esp()} builds on \code{\link[ggplot2]{theme_minimal}} with an
#' ESP house style. Note several opinionated defaults: a cream plot background
#' (\code{"#f4f2e4"}), no minor gridlines, and \strong{axis titles and the
#' legend removed entirely}. Label lines directly (e.g., with
#' \code{annotate()} or \code{geom_text()}) or re-enable the legend with
#' \code{theme(legend.position = ...)} after \code{theme_esp()}.
#'
#' \code{scale_color_esp()} and \code{scale_fill_esp()} apply the
#' \code{\link{esp_pal}} palette (three colors, so at most three discrete
#' levels). \code{scale_colour_esp()} is an alias.
#'
#' @param base_family Base font family for the theme. Defaults to
#'   "Public Sans"; if the font is not installed, ggplot2 falls back to the
#'   default sans font.
#' @param ... Passed to the underlying ggplot2 scale functions
#'   (\code{\link[ggplot2]{scale_color_manual}} /
#'   \code{\link[ggplot2]{scale_fill_manual}}).
#'
#' @return \code{theme_esp()} returns a \code{\link[ggplot2]{theme}} object;
#'   the scale functions return ggplot2 scale objects. All are added to a
#'   plot with \code{+}.
#'
#' @seealso \code{\link{esp_pal}}, \code{\link{esp_navy}}
#'
#' @examples
#' # Plots are assigned rather than printed: rendering requires the
#' # "Public Sans" font, which check machines may not have registered.
#' library(ggplot2)
#'
#' p1 <- ggplot(economics, aes(date, unemploy / pop)) +
#'   geom_line(color = esp_navy) +
#'   labs(
#'     title = "Unemployment share of population",
#'     caption = "Source: FRED via ggplot2::economics."
#'   ) +
#'   theme_esp()
#'
#' # Multiple series (palette has 3 colors, so at most 3 levels);
#' # theme_esp() removes the legend, so label lines directly
#' dat <- subset(economics_long, variable %in% c("psavert", "uempmed", "unemploy"))
#' p2 <- ggplot(dat, aes(date, value01, color = variable)) +
#'   geom_line() +
#'   scale_color_esp() +
#'   theme_esp()
#'
#' # print(p1) or print(p2) to render (needs the font installed)
#'
#' @name esp_theme
#' @importFrom ggplot2 theme_minimal theme element_rect element_blank element_line element_text scale_color_manual scale_fill_manual
#' @importFrom grid unit
#' @export
theme_esp <- function(base_family = "Public Sans") {
  ggplot2::theme_minimal(base_family = base_family) +
    ggplot2::theme(
      # Background
      plot.background = ggplot2::element_rect(fill = "#f4f2e4", color = NA),
      panel.background = ggplot2::element_rect(fill = "#f4f2e4", color = NA),

      # Remove gridlines
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_line(color = "grey80"),
      panel.grid.major.x = ggplot2::element_line(color = "grey80"),

      # Axis lines and ticks
      axis.line = ggplot2::element_line(color = "black", linewidth = 0.5),
      axis.ticks = ggplot2::element_line(color = "black", linewidth = 0.5),
      axis.ticks.length = grid::unit(5, "pt"),

      # Titles and text
      plot.title = ggplot2::element_text(
        size = 25,
        face = "bold",
        family = base_family,
        color = "black",
        margin = ggplot2::margin(b = 10, t = 10)
      ),
      plot.subtitle = ggplot2::element_text(
        size = 15,
        family = base_family,
        color = "black"
      ),
      plot.caption = ggplot2::element_text(
        size = 10,
        face = "italic",
        family = base_family,
        color = "black"
      ),
      axis.text = ggplot2::element_text(
        size = 12,
        face = "bold",
        family = base_family,
        color = "black"
      ),
      strip.text = ggplot2::element_text(
        face = "bold",
        size = 10,
        hjust = 0.5,
        family = base_family,
        color = "black"
      ),

      # Remove axis titles and legend
      axis.title.x = ggplot2::element_blank(),
      axis.title.y = ggplot2::element_blank(),
      legend.position = "none",
      legend.title = ggplot2::element_blank(),
      legend.text = ggplot2::element_text(
        size = 12,
        family = base_family,
        color = "black"
      ),
      # Title alignment
      plot.title.position = "plot"
    )
}

#' ESP Color Palette
#'
#' Named character vector of ESP-branded colors, used by
#' \code{\link{scale_color_esp}} and \code{\link{scale_fill_esp}}.
#'
#' @format A named character vector of three hex colors:
#' \describe{
#'   \item{"Warm Navy"}{\code{"#2c3254"}}
#'   \item{"Warm Red"}{\code{"#ff8361"}}
#'   \item{"Soft Green"}{\code{"#70ad8f"}}
#' }
#'
#' @seealso \code{\link{esp_navy}}, \code{\link{theme_esp}}
#'
#' @examples
#' esp_pal
#' esp_pal[["Warm Red"]]
#' @export
esp_pal <- c(
  "Warm Navy" = "#2c3254",
  "Warm Red" = "#ff8361",
  "Soft Green" = "#70ad8f"
)

#' ESP Primary Color (Navy)
#'
#' The ESP primary color ("Warm Navy", \code{"#2c3254"}) as a standalone
#' value, convenient for single-series plots:
#' \code{geom_line(color = esp_navy)}.
#'
#' @format A named character vector of length 1.
#'
#' @seealso \code{\link{esp_pal}}, \code{\link{theme_esp}}
#'
#' @examples
#' esp_navy
#' @export
esp_navy <- esp_pal["Warm Navy"]

#' ESP Discrete Color Scale
#' @rdname esp_theme
#' @export
scale_color_esp <- function(...) {
  ggplot2::scale_color_manual(values = esp_pal, ...)
}

#' ESP Discrete Fill Scale
#' @rdname esp_theme
#' @export
scale_fill_esp <- function(...) {
  ggplot2::scale_fill_manual(values = esp_pal, ...)
}

#' Alias for American/British spelling
#' @rdname esp_theme
#' @export
scale_colour_esp <- scale_color_esp

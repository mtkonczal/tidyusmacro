#' ESP Theme and Color Scales
#'
#' Custom theme and color palette for Economic Security Project graphics.
#'
#' @param base_family Base font family for the theme. Defaults to "Public Sans".
#' @param ... Passed to the underlying ggplot2 scale functions.
#'
#' @return A ggplot2 theme or scale object.
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
#' Named vector of ESP-branded colors.
#' @export
esp_pal <- c(
  "Warm Navy" = "#2c3254",
  "Warm Red" = "#ff8361",
  "Soft Green" = "#70ad8f"
)

#' ESP Primary Color (Navy)
#'
#' A standalone color value for quick use.
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

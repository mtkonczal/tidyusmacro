# =====================================================================
#  Economic Security Project ggplot2 theme & scales
#  (ggthemes‑style structure)
# =====================================================================

# ---------------------------------------------------------------------
#  Brand colours (hex) -------------------------------------------------
# ---------------------------------------------------------------------
.esp_cols <- c(
  "Warm Navy"  = "#2c3254",
  "Warm Red"   = "#ff8361",
  "Soft Green" = "#70ad8f",
  "Deep Purple"= "#472b51"
)

# ---------------------------------------------------------------------
#  THEME ---------------------------------------------------------------
# ---------------------------------------------------------------------
#' Theme inspired by Economic Security Project graphics
#'
#' A minimal theme with ESP brand colours, grid, and typography.  It builds on
#' **\link[ggplot2]{theme_minimal}**.  Use together with
#' [scale_colour_esp()] / [scale_fill_esp()].
#'
#' @inheritParams ggplot2::theme_grey
#' @param background `"white"` (default) or `"beige"`.
#' @family themes esp
#' @export
#' @importFrom grid unit
theme_esp <- function(base_size   = 12,
                      base_family = "Publico Banner",
                      background  = c("beige", "white")) {

  background <- match.arg(background)
  bg_colour  <- if (background == "white") "#ffffff" else "#f4f2e4"

  (ggplot2::theme_classic(base_size = base_size,
                          base_family = base_family) +
      ggplot2::theme(
        # apply the chosen background colour
        plot.background  = ggplot2::element_rect(fill = bg_colour, colour = NA),
        panel.background = ggplot2::element_rect(fill = bg_colour, colour = NA),

        line   = ggplot2::element_line(colour = "#2c3254"),
        rect   = ggplot2::element_rect(fill = bg_colour, colour = NA),
        text   = ggplot2::element_text(colour = .esp_cols["Warm Navy"]),

        axis.title = ggplot2::element_text(face = "bold"),
        axis.text  = ggplot2::element_text(),
        axis.ticks = ggplot2::element_blank(),
        axis.line  = ggplot2::element_blank(),

        legend.position = "right",

        plot.title.position = "plot",

        legend.title = element_blank(),

        panel.grid.major = ggplot2::element_line(
          colour = scales::alpha(.esp_cols["Warm Navy"], 0.1)),
        panel.grid.minor = ggplot2::element_blank(),

        plot.title = ggplot2::element_text(
          hjust = 0, size = ggplot2::rel(1.4), face = "bold"),
        plot.margin = grid::unit(c(1, 1, 1, 1), "lines"),

        strip.background = ggplot2::element_rect(
          fill = .esp_cols["Warm Navy"]),
        strip.text = ggplot2::element_text(
          colour = "white", face = "bold")
      ))
}

# ---------------------------------------------------------------------
#  PALETTE -------------------------------------------------------------
# ---------------------------------------------------------------------
#' ESP colour palette (discrete)
#'
#' Returns a manual palette function using the four ESP brand colours in order:
#' Warm Navy, Warm Red, Soft Green, Deep Purple.
#'
#' @family colour esp
#' @export
esp_pal <- function() {
  values <- unname(.esp_cols)
  max_n  <- length(values)
  f <- scales::manual_pal(values)
  attr(f, "max_n") <- max_n
  f
}

# ---------------------------------------------------------------------
#  COLOUR & FILL SCALES ------------------------------------------------
# ---------------------------------------------------------------------
#' ESP colour scales
#'
#' Discrete colour and fill scales using ESP brand colours.
#'
#' @inheritParams ggplot2::scale_colour_hue
#' @family colour esp
#' @rdname scale_esp
#' @seealso [theme_esp()] for examples.
#' @export
scale_colour_esp <- function(...) {
  ggplot2::discrete_scale("colour", "esp", esp_pal(), ...)
}

#' @rdname scale_esp
#' @export
scale_color_esp <- scale_colour_esp   # alias (US spelling)

#' @rdname scale_esp
#' @export
scale_fill_esp <- function(...) {
  ggplot2::discrete_scale("fill", "esp", esp_pal(), ...)
}

#' Warm Navy brand colour
#'
#' Returns the hex code `"#2c3254"`.
#'
#' @return Character vector of length 1.
#' @family colour esp
#' @export
esp_navy <- function() {
  "#2c3254"
}

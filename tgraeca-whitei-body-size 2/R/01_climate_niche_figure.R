# =============================================================================
# 01_climate_niche_figure.R
#
# Climatic niche of Testudo graeca whitei: 2D density contour plot of annual
# precipitation (BIO12) against annual mean temperature (BIO1), with the
# sampled sites of North Africa and SE Spain plotted on top.
#
# This is the code behind Figure 2 of:
#   Semaha MJ, Rodriguez-Caro RC, Fahd S, Mira-Jover A, Gimenez A, Gracia E
#   (2024). Body size variation in a lineage of spur-thighed tortoises
#   (Testudo graeca whitei) contrasts with that expected from the species
#   level. Amphibia-Reptilia. https://doi.org/10.1163/15685381-bja10171
#
# Input (both files are described in README.md)
#   background climate : one row per WorldClim grid cell inside the range
#   sites climate      : one row per sampled site
#
# Output
#   figures/fig2_climate_niche.png
#
# How to run
#   Open the .Rproj file in RStudio, then run this script from top to bottom.
#   All paths are relative to the project folder, so nothing needs editing.
#
# Requires ggplot2 (version 3.4.0 or later) and ggrepel.
# =============================================================================

library(ggplot2)
library(ggrepel)


# ---- 1. Settings -------------------------------------------------------------

# Input files. The repository ships with simulated example data. To use other
# data, point these two lines to files with the same column names.
background_file <- file.path("data", "example_background_climate.csv")
sites_file      <- file.path("data", "example_sites_climate.csv")

# Output file
figure_file <- file.path("figures", "fig2_climate_niche.png")

# Density levels at which the contours are drawn. Climate conditions that are
# rarer than the first value are left blank, which gives the plot its outline.
density_breaks <- c(0.00001, 0.0001, 0.0005, 0.0010, 0.0015, 0.0020, 0.0025,
                    0.0030)

# One colour per region. The names must match the "region" column exactly.
region_colours <- c("North Africa" = "#F8766D", "SE Spain" = "#00BFC4")


# ---- 2. Load and check the data ----------------------------------------------

background <- read.csv(background_file)
sites      <- read.csv(sites_file)

# Stop early, with a clear message, if a file does not have the expected shape.
needed_background <- c("precip_mm", "temp_c")
needed_sites      <- c("site_id", "region", "precip_mm", "temp_c")

if (!all(needed_background %in% names(background))) {
  stop("The background file needs these columns: ",
       paste(needed_background, collapse = ", "))
}
if (!all(needed_sites %in% names(sites))) {
  stop("The sites file needs these columns: ",
       paste(needed_sites, collapse = ", "))
}
if (!all(sites$region %in% names(region_colours))) {
  stop("Unknown value in the 'region' column. Expected: ",
       paste(names(region_colours), collapse = ", "))
}


# ---- 3. Build the figure -----------------------------------------------------

climate_niche_plot <-
  ggplot(background, aes(x = precip_mm, y = temp_c)) +
  # how often each combination of climate conditions occurs within the range
  geom_density_2d_filled(breaks = density_breaks, show.legend = FALSE) +
  geom_density_2d(breaks = density_breaks, colour = "black", linewidth = 0.25,
                  show.legend = FALSE) +
  # the sampled sites
  geom_point(data = sites, aes(colour = region), size = 3) +
  geom_label_repel(
    data = sites,
    aes(label = site_id),
    size = 4,
    box.padding = 0.5,
    point.padding = 1,
    segment.colour = "grey50",
    min.segment.length = 0,  # always draw the line from label to point
    max.overlaps = Inf,      # never drop a label, even in crowded areas
    seed = 42,               # same label positions every time
    show.legend = FALSE
  ) +
  # drop = FALSE keeps the colour of each density level fixed, whatever the data
  scale_fill_viridis_d(drop = FALSE) +
  scale_colour_manual(values = region_colours, name = "Region") +
  labs(
    # expression() and italic() put the scientific name in italics
    title = expression(paste("Climatic niche of ", italic("Testudo graeca whitei"),
                             " in North Africa and SE Spain")),
    x = "Annual precipitation (mm)",
    y = "Annual mean temperature (\u00b0C)"  # \u00b0 is the degree sign
  ) +
  theme_bw() +
  theme(legend.position = "bottom")

climate_niche_plot


# ---- 4. Save -----------------------------------------------------------------

dir.create("figures", showWarnings = FALSE)

ggsave(figure_file, climate_niche_plot, width = 10, height = 7, dpi = 300)

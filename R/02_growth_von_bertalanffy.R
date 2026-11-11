# =============================================================================
# 02_growth_von_bertalanffy.R
#
# Von Bertalanffy growth models of straight carapace length (SCL) against age
# in Testudo graeca whitei, fitted separately for each sex in each region
# (North Africa and SE Spain).
#
# This is the code behind Figure 5 and the growth parameters of:
#   Semaha MJ, Rodriguez-Caro RC, Fahd S, Mira-Jover A, Gimenez A, Gracia E
#   (2024). Body size variation in a lineage of spur-thighed tortoises
#   (Testudo graeca whitei) contrasts with that expected from the species
#   level. Amphibia-Reptilia. https://doi.org/10.1163/15685381-bja10171
#
# The model
#   SCL = Linf * (1 - exp(-K * (age - t0)))
#     Linf : asymptotic carapace length (mm)
#     K    : growth rate coefficient (per year)
#     t0   : theoretical age at which length is zero (a modelling artefact)
#
# Input (described in README.md)
#   tortoises : one row per individual, with its region, sex, age and SCL
#
# Output
#   tables/growth_parameters.csv    Linf, K and t0 with confidence intervals
#   figures/fig5_growth_curves.png  the four growth curves
#
# How to run
#   Open the .Rproj file in RStudio, then run this script from top to bottom.
#   The bootstrap takes about a minute.
#
# Requires FSA, car and ggplot2 (version 3.4.0 or later).
# =============================================================================

library(FSA)      # starting values for the growth model
library(car)      # bootstrap confidence intervals
library(ggplot2)


# ---- 1. Settings -------------------------------------------------------------

# Input file. The repository ships with simulated example data. To use other
# data, point this line to a file with the same column names.
tortoises_file <- file.path("data", "example_tortoises.csv")

# Output files
table_file  <- file.path("tables", "growth_parameters.csv")
figure_file <- file.path("figures", "fig5_growth_curves.png")

# Bootstrap settings
n_bootstrap         <- 999   # number of bootstrap samples per model
ci_level_parameters <- 0.90  # confidence level for Linf, K and t0
ci_level_curves     <- 0.95  # confidence level for the bands around the curves

# Ages (in years) at which the growth curves are drawn
ages_to_predict <- seq(1, 25, by = 0.2)

# One colour per region. The names must match the "region" column exactly.
region_colours <- c("North Africa" = "#F8766D", "SE Spain" = "#00BFC4")

# The bootstrap draws random samples. Fixing the seed gives exactly the same
# confidence intervals every time the script is run.
set.seed(2024)


# ---- 2. Load and check the data ----------------------------------------------

tortoises <- read.csv(tortoises_file)

needed_columns <- c("region", "sex", "age", "scl_mm")
if (!all(needed_columns %in% names(tortoises))) {
  stop("The tortoises file needs these columns: ",
       paste(needed_columns, collapse = ", "))
}
if (!all(tortoises$region %in% names(region_colours))) {
  stop("Unknown value in the 'region' column. Expected: ",
       paste(names(region_colours), collapse = ", "))
}

# A growth model needs both age and length, so drop incomplete rows.
tortoises <- tortoises[complete.cases(tortoises[, needed_columns]), ]


# ---- 3. Helper functions -----------------------------------------------------

# The von Bertalanffy growth model, written as a formula for nls().
vb_formula <- scl_mm ~ Linf * (1 - exp(-K * (age - t0)))

# nls() needs rough starting values for Linf, K and t0. The FSA package finds
# them from the data. FSA 0.10.0 replaced vbStarts() with findGrowthStarts(),
# so this function picks whichever one the installed version provides. Both
# lead to the same fitted model.
get_start_values <- function(group_data) {
  if (packageVersion("FSA") >= "0.10.0") {
    as.list(findGrowthStarts(scl_mm ~ age, data = group_data))
  } else {
    vbStarts(scl_mm ~ age, data = group_data)
  }
}

# Predicted carapace length at each age in ages_to_predict. Bootstrapping this
# function gives the confidence band around a growth curve.
predict_curve <- function(model) {
  predict(model, data.frame(age = ages_to_predict))
}


# ---- 4. Fit one model per region and sex -------------------------------------

groups <- unique(tortoises[, c("region", "sex")])

parameter_list <- list()  # will hold one table of parameters per group
curve_list     <- list()  # will hold one growth curve per group

for (i in seq_len(nrow(groups))) {

  this_region <- groups$region[i]
  this_sex    <- groups$sex[i]
  message("Fitting the growth model for: ", this_region, ", ", this_sex)

  group_data <- tortoises[tortoises$region == this_region &
                            tortoises$sex == this_sex, ]

  # fit the model by non-linear least squares
  fit <- nls(vb_formula, data = group_data,
             start = get_start_values(group_data))

  # bootstrap confidence intervals (BCa) for the three parameters
  # (R may report "Number of bootstraps was 995 out of 999 attempted": the
  # model did not converge for a few random samples, which is normal)
  boot_parameters <- Boot(fit, R = n_bootstrap)
  ci_parameters   <- confint(boot_parameters, level = ci_level_parameters,
                             type = "bca")

  parameter_list[[i]] <- data.frame(
    region    = this_region,
    sex       = this_sex,
    n         = nrow(group_data),
    parameter = names(coef(fit)),
    estimate  = unname(coef(fit)),
    ci_lower  = ci_parameters[, 1],
    ci_upper  = ci_parameters[, 2],
    row.names = NULL
  )

  # bootstrap confidence band (BCa) for the growth curve
  boot_curve <- Boot(fit, f = predict_curve, R = n_bootstrap)
  ci_curve   <- confint(boot_curve, level = ci_level_curves, type = "bca")

  curve_list[[i]] <- data.frame(
    region   = this_region,
    sex      = this_sex,
    age      = ages_to_predict,
    scl_mm   = predict_curve(fit),
    ci_lower = ci_curve[, 1],
    ci_upper = ci_curve[, 2],
    row.names = NULL
  )
}

# stack the results of the four groups into two tables
growth_parameters <- do.call(rbind, parameter_list)
growth_curves     <- do.call(rbind, curve_list)


# ---- 5. Table of growth parameters -------------------------------------------

growth_parameters$ci_level <- ci_level_parameters

# keep four significant digits, which is plenty for reporting
number_columns <- c("estimate", "ci_lower", "ci_upper")
growth_parameters[number_columns] <- signif(growth_parameters[number_columns], 4)

growth_parameters

dir.create("tables", showWarnings = FALSE)
write.csv(growth_parameters, table_file, row.names = FALSE)


# ---- 6. Figure of the growth curves ------------------------------------------

growth_curves_plot <-
  ggplot(growth_curves, aes(x = age, y = scl_mm)) +
  # confidence bands
  geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper,
                  group = interaction(region, sex)),
              fill = "grey90") +
  # growth curves: colour shows the region, line type shows the sex
  geom_line(aes(colour = region, linetype = sex), linewidth = 1) +
  scale_colour_manual(values = region_colours, name = "Region") +
  scale_linetype_manual(values = c("Female" = "solid", "Male" = "dashed"),
                        name = "Sex") +
  scale_x_continuous(breaks = seq(4, 24, by = 4)) +
  labs(
    title = "Von Bertalanffy growth curves by sex and region",
    x = "Age (years)",
    y = "Straight carapace length (mm)"
  ) +
  theme_bw() +
  theme(panel.grid = element_blank(),
        legend.position = "bottom",
        legend.key.width = unit(1.2, "cm"))

growth_curves_plot

dir.create("figures", showWarnings = FALSE)
ggsave(figure_file, growth_curves_plot, width = 9, height = 6.5, dpi = 300)

# =============================================================================
# 00_simulate_example_data.R
#
# Creates SIMULATED example data so that the scripts in this repository can be
# run by anyone, without access to the original data.
#
# The simulated files have exactly the same structure (column names and units)
# as the real ones, and broadly similar ranges of values, but the numbers are
# random. Figures and tables made from them illustrate the method only. They
# are NOT the results of the paper.
#
# Output
#   data/example_background_climate.csv
#   data/example_sites_climate.csv
#   data/example_tortoises.csv
#
# You only need to run this script if you want to regenerate the example data.
# =============================================================================

set.seed(2024)  # makes the random numbers identical every time the script runs


# ---- 1. Background climate ---------------------------------------------------
# In the real analysis this table holds one row per WorldClim grid cell inside
# the range of Testudo graeca whitei. Here we imitate it with three overlapping
# "clouds" of climate conditions.

simulate_cloud <- function(n, precip_mean, precip_sd, temp_mean, temp_sd,
                           correlation = 0) {
  # Draws n points from a bivariate normal distribution (base R only).
  z1 <- rnorm(n)
  z2 <- correlation * z1 + sqrt(1 - correlation^2) * rnorm(n)
  data.frame(
    precip_mm = precip_mean + precip_sd * z1,
    temp_c    = temp_mean + temp_sd * z2
  )
}

background <- rbind(
  # most common conditions: semi-arid and mild
  simulate_cloud(3000, precip_mean = 285, precip_sd = 40,
                 temp_mean = 15.8, temp_sd = 0.9, correlation = -0.5),
  # drier and warmer
  simulate_cloud(1500, precip_mean = 190, precip_sd = 35,
                 temp_mean = 17.5, temp_sd = 1.6, correlation = -0.3),
  # wetter areas
  simulate_cloud(1500, precip_mean = 460, precip_sd = 110,
                 temp_mean = 16.5, temp_sd = 1.5, correlation = -0.2)
)

# keep the values inside a realistic range for the region
background <- subset(
  background,
  precip_mm >= 100 & precip_mm <= 800 & temp_c >= 10 & temp_c <= 22
)
background$precip_mm <- round(background$precip_mm)
background$temp_c    <- round(background$temp_c, 1)


# ---- 2. Sampled sites --------------------------------------------------------
# 18 sites in North Africa and 11 in SE Spain, as in the paper. The climate
# values are random draws within the ranges reported in the Methods.

n_africa <- 18
n_spain  <- 11

sites <- data.frame(
  site_id   = seq_len(n_africa + n_spain),
  region    = rep(c("North Africa", "SE Spain"), times = c(n_africa, n_spain)),
  precip_mm = round(c(runif(n_africa, 167, 648), runif(n_spain, 240, 352))),
  temp_c    = round(c(runif(n_africa, 13, 17), runif(n_spain, 15, 18)), 1)
)


# ---- 3. Individual tortoises -------------------------------------------------
# One row per tortoise, with its age and straight carapace length (SCL).
# Each region-by-sex group follows its own von Bertalanffy growth curve, plus
# random variation among individuals. The growth parameters below are round
# numbers of a similar size to those estimated in the paper.

simulate_group <- function(n, region, sex, Linf, K, t0) {
  # ages 1 to 25 years, with young and middle-aged animals more common
  possible_ages <- 1:25
  age <- sample(possible_ages, n, replace = TRUE,
                prob = dgamma(possible_ages, shape = 2.5, rate = 0.25))
  expected_scl <- Linf * (1 - exp(-K * (age - t0)))
  # individuals vary around the curve by about 8% of their expected length
  scl_mm <- rnorm(n, mean = expected_scl, sd = 0.08 * expected_scl)
  data.frame(region = region, sex = sex, age = age,
             scl_mm = round(scl_mm, 1))
}

tortoises <- rbind(
  simulate_group(75,  "North Africa", "Female", Linf = 235, K = 0.09,  t0 = 0.3),
  simulate_group(75,  "North Africa", "Male",   Linf = 185, K = 0.15,  t0 = 0.5),
  simulate_group(250, "SE Spain",     "Female", Linf = 180, K = 0.09,  t0 = -0.1),
  simulate_group(250, "SE Spain",     "Male",   Linf = 135, K = 0.125, t0 = -0.7)
)
tortoises <- cbind(tortoise_id = seq_len(nrow(tortoises)), tortoises)


# ---- 4. Save -----------------------------------------------------------------

dir.create("data", showWarnings = FALSE)

write.csv(background, file.path("data", "example_background_climate.csv"),
          row.names = FALSE)
write.csv(sites, file.path("data", "example_sites_climate.csv"),
          row.names = FALSE)
write.csv(tortoises, file.path("data", "example_tortoises.csv"),
          row.names = FALSE)

message("Example data written to the 'data' folder: ",
        nrow(background), " background cells, ", nrow(sites), " sites and ",
        nrow(tortoises), " tortoises.")

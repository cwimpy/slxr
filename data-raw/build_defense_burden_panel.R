# Build the `defense_burden_panel` example dataset for slxr.
#
# Source: replication archive for Wimpy, Whitten, and Williams (2021),
# "X Marks the Spot: Unlocking the Treasure of Spatial-X Models",
# Journal of Politics 83(2): 722-739.  doi:10.1086/710089
#
# This script builds the full 1950-2008 monadic panel with three
# time-varying spatial weights matrices (contiguity, alliance,
# defense pact) stored as named lists keyed by year.  The resulting
# object is shipped as `defense_burden_panel` for replication of
# Table 3 Model 3 of the paper.

library(haven)
library(dplyr)
library(Matrix)

replication_dir <- "replication"

mon <- read_dta(file.path(replication_dir, "Military Spending--Monadic.dta"))
dy  <- read_dta(file.path(replication_dir, "Military Spending--Dyadic.dta"))

region_labels <- c(
  "Europe", "N Africa/Middle East", "Africa",
  "Asia/Oceania", "Americas"
)

# Keep the same variables as the cross-sectional slice
m <- mon |>
  select(
    ccode, year,
    ch_milex, milex_tm1, log_pop_tm1,
    civilwar_tm1, total_wars_tm1,
    alliance_us, ch_milex_us, ch_milex_ussr,
    region
  ) |>
  tidyr::drop_na() |>
  arrange(year, ccode) |>
  mutate(region_name = factor(region, levels = 1:5, labels = region_labels))

years <- sort(unique(m$year))

# Per-year sparse W builder
build_W_for_year <- function(var_name, yr, ids_yr) {
  dd <- dy |>
    filter(year == yr,
           ccode1 %in% ids_yr,
           ccode2 %in% ids_yr) |>
    select(ccode1, ccode2, v = all_of(var_name)) |>
    filter(v != 0, !is.na(v))

  n <- length(ids_yr)
  W <- sparseMatrix(
    i = match(dd$ccode1, ids_yr),
    j = match(dd$ccode2, ids_yr),
    x = 1,
    dims = c(n, n)
  )
  dimnames(W) <- list(as.character(ids_yr), as.character(ids_yr))

  rs <- rowSums(W)
  rs[rs == 0] <- 1
  W / rs
}

build_W_list <- function(var_name) {
  Ws <- lapply(years, function(yr) {
    ids_yr <- m$ccode[m$year == yr]
    build_W_for_year(var_name, yr, ids_yr)
  })
  names(Ws) <- as.character(years)
  Ws
}

message("Building contiguity Ws ...")
W_contig_list   <- build_W_list("cont")
message("Building alliance Ws ...")
W_alliance_list <- build_W_list("alliance")
message("Building defense-pact Ws ...")
W_defense_list  <- build_W_list("defense")

defense_burden_panel <- list(
  data       = tibble::as_tibble(m),
  W_contig   = W_contig_list,
  W_alliance = W_alliance_list,
  W_defense  = W_defense_list
)

n_obs <- nrow(defense_burden_panel$data)
n_yr  <- length(years)
sizes <- sapply(defense_burden_panel$W_contig, \(w) nrow(w))

message(sprintf(
  "defense_burden_panel built: %d observations, %d years (%d-%d).\n  countries per year: min %d, max %d\n  non-zeros: contig %d  alliance %d  defense %d",
  n_obs, n_yr, min(years), max(years),
  min(sizes), max(sizes),
  sum(vapply(defense_burden_panel$W_contig,   \(w) length(w@x), 1L)),
  sum(vapply(defense_burden_panel$W_alliance, \(w) length(w@x), 1L)),
  sum(vapply(defense_burden_panel$W_defense,  \(w) length(w@x), 1L))
))

usethis::use_data(defense_burden_panel, overwrite = TRUE, compress = "xz")

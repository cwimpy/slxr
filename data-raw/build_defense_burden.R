# Build the `defense_burden` example dataset for slxr.
#
# Source: replication archive for Wimpy, Whitten, and Williams (2021),
# "X Marks the Spot: Unlocking the Treasure of Spatial-X Models",
# Journal of Politics 83(2): 722-739.  doi:10.1086/710089
#
# This script trims the 1950-2008 monadic + dyadic panels to the single
# year 1995 and builds three country-by-country spatial weights matrices
# (contiguity, alliance, defense pact).  The resulting list is shipped
# as the `defense_burden` example dataset.
#
# Only a single cross-section is included because slxr v0.1 does not yet
# handle block-diagonal panel W matrices.  A full-panel replication of
# the paper's Table 3 Model 3 is planned for v0.2 once TSLS support
# lands.

library(haven)
library(dplyr)
library(Matrix)

replication_dir <- "replication"

mon <- read_dta(file.path(replication_dir, "Military Spending--Monadic.dta"))
dy  <- read_dta(file.path(replication_dir, "Military Spending--Dyadic.dta"))

year_slice <- 1995

# Monadic slice for the target year
m <- mon |>
  filter(year == year_slice) |>
  select(
    ccode, year,
    ch_milex, milex_tm1, log_pop_tm1,
    civilwar_tm1, total_wars_tm1,
    alliance_us, ch_milex_us, ch_milex_ussr,
    region
  ) |>
  tidyr::drop_na() |>
  arrange(ccode)

# Dyadic slice: restrict to rows where both partners are in the monadic slice
d <- dy |>
  filter(year == year_slice,
         ccode1 %in% m$ccode,
         ccode2 %in% m$ccode)

ids <- m$ccode
n   <- length(ids)

# Add region labels for nicer output in examples
region_labels <- c(
  "Europe", "N Africa/Middle East", "Africa",
  "Asia/Oceania", "Americas"
)
m$region_name <- factor(m$region,
                         levels = 1:5,
                         labels = region_labels)

# Build a sparse binary weights matrix from a dyadic indicator
build_W <- function(var_name) {
  dd <- d |>
    select(ccode1, ccode2, v = all_of(var_name)) |>
    filter(v != 0, !is.na(v))
  W <- sparseMatrix(
    i = match(dd$ccode1, ids),
    j = match(dd$ccode2, ids),
    x = 1,
    dims = c(n, n)
  )
  dimnames(W) <- list(as.character(ids), as.character(ids))
  W
}

W_contig   <- build_W("cont")
W_alliance <- build_W("alliance")
W_defense  <- build_W("defense")

# Row-standardize (zero-neighbor rows remain all-zero)
row_stdize <- function(W) {
  rs <- rowSums(W)
  rs[rs == 0] <- 1
  W / rs
}

W_contig   <- row_stdize(W_contig)
W_alliance <- row_stdize(W_alliance)
W_defense  <- row_stdize(W_defense)

defense_burden <- list(
  data       = tibble::as_tibble(m),
  W_contig   = W_contig,
  W_alliance = W_alliance,
  W_defense  = W_defense
)

stopifnot(
  nrow(defense_burden$data) == n,
  dim(defense_burden$W_contig)   == c(n, n),
  dim(defense_burden$W_alliance) == c(n, n),
  dim(defense_burden$W_defense)  == c(n, n)
)

message(sprintf(
  "defense_burden built: %d countries in %d.\n  contig: %d non-zeros\n  alliance: %d non-zeros\n  defense: %d non-zeros",
  n, year_slice,
  length(W_contig@x),
  length(W_alliance@x),
  length(W_defense@x)
))

usethis::use_data(defense_burden, overwrite = TRUE)

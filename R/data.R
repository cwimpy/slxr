#' Defense burden data, 1995 cross-section
#'
#' A 179-country cross-section of defense spending and conflict
#' indicators for 1995, drawn from the replication archive of Wimpy,
#' Whitten, and Williams (2021).  Three row-standardized spatial weights
#' matrices connect the units through different channels: contiguity,
#' alliance, and defense pact.
#'
#' This cross-section is intended for pedagogical demonstration of
#' variable-specific SLX specifications.  The original paper estimates a
#' pooled panel SLX across 1950-2008 with year-specific weights matrices;
#' that full-panel replication requires block-diagonal W support, which
#' is planned for `slxr` v0.2.
#'
#' @format A named list with four elements:
#' \describe{
#'   \item{`data`}{A tibble with 179 rows and 12 variables, arranged by
#'     Correlates of War country code (`ccode`). Variables:
#'     \itemize{
#'       \item `ccode` - Correlates of War country code.
#'       \item `year` - Calendar year (1995).
#'       \item `ch_milex` - Change in military expenditures (outcome).
#'       \item `milex_tm1` - Lagged military expenditures.
#'       \item `log_pop_tm1` - Lagged log population.
#'       \item `civilwar_tm1` - Lagged civil war indicator.
#'       \item `total_wars_tm1` - Lagged count of interstate wars.
#'       \item `alliance_us` - Alliance with the United States.
#'       \item `ch_milex_us` - Change in U.S. military expenditures.
#'       \item `ch_milex_ussr` - Change in Soviet/Russian military
#'         expenditures.
#'       \item `region` - Integer region code (1-5).
#'       \item `region_name` - Factor: Europe, N Africa/Middle East,
#'         Africa, Asia/Oceania, Americas.
#'     }
#'   }
#'   \item{`W_contig`}{A 179 x 179 row-standardized sparse
#'     `dgCMatrix` encoding geographic contiguity.}
#'   \item{`W_alliance`}{A 179 x 179 row-standardized sparse
#'     `dgCMatrix` encoding alliance ties.}
#'   \item{`W_defense`}{A 179 x 179 row-standardized sparse
#'     `dgCMatrix` encoding mutual defense pacts.}
#' }
#'
#' @source Wimpy, Whitten, and Williams (2021) replication archive,
#'   Journal of Politics Dataverse.
#'   \doi{10.1086/710089}
#'
#' @references
#' Wimpy, C., Whitten, G. D., & Williams, L. K. (2021). X Marks the
#' Spot: Unlocking the Treasure of Spatial-X Models. *Journal of
#' Politics*, 83(2), 722-739.
#'
#' @examples
#' data(defense_burden)
#' dim(defense_burden$data)
#' dim(defense_burden$W_contig)
"defense_burden"

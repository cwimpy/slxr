# Replication check against Wimpy, Whitten, and Williams (2021)
# Table 3, Model 3 (JoP 83:722-739, doi:10.1086/710089).
#
# The shipped defense_burden_panel$W_* matrices are row-standardized.
# The paper uses BINARY weights matrices (footnote 24), so this test
# assembles binary W matrices from the raw dyadic source data that
# ships with the replication archive. When that archive isn't present
# (CRAN builds, downstream users), the test skips.
#
# Purpose: verify that slxr recovers the paper's published coefficients
# on the defining multi-W specification - specifically the defense-pact
# spillover for lagged military expenditures, which is the substantive
# finding of Model 3.

test_that("slx() reproduces the spatial spillovers of WWW (2021) Table 3 Model 3", {
  skip_on_cran()
  replication_dir <- file.path(dirname(getwd()), "replication")
  # devtools::test() vs testthat::test_local() cwd differs; try both
  if (!dir.exists(replication_dir)) {
    replication_dir <- file.path("..", "..", "replication")
  }
  skip_if_not(dir.exists(replication_dir),
              "Replication archive not present.")
  skip_if_not_installed("haven")

  suppressPackageStartupMessages({
    requireNamespace("dplyr")
    requireNamespace("tidyr")
    requireNamespace("Matrix")
  })

  mon <- haven::read_dta(file.path(replication_dir,
                                   "Military Spending--Monadic.dta"))
  dy  <- haven::read_dta(file.path(replication_dir,
                                   "Military Spending--Dyadic.dta"))

  m <- mon |>
    dplyr::filter(year >= 1951, year <= 2008) |>
    dplyr::group_by(ccode) |> dplyr::arrange(year) |>
    dplyr::mutate(ch2_milex = dplyr::lag(milex) - dplyr::lag(milex, 2)) |>
    dplyr::ungroup() |>
    dplyr::mutate(
      ally_ch_milex_us      = alliance_us * ch_milex_us,
      ally_ch_milex_us_ussr = alliance_us * ch_milex_ussr,
      trend                 = year - 1949,
      Y42                   = as.integer(year == 1992),
      R2 = as.integer(region == 2), R3 = as.integer(region == 3),
      R4 = as.integer(region == 4), R5 = as.integer(region == 5)
    ) |>
    dplyr::select(ccode, year, ch_milex, milex_tm1, ch2_milex,
                  log_pop_tm1, civilwar_tm1, total_wars_tm1,
                  alliance_us, ch_milex_us, ch_milex_ussr,
                  ally_ch_milex_us, ally_ch_milex_us_ussr,
                  trend, Y42, R2, R3, R4, R5) |>
    tidyr::drop_na() |>
    dplyr::arrange(year, ccode)

  build_W <- function(var, yr, ids) {
    dd <- dy[dy$year == yr & dy$ccode1 %in% ids & dy$ccode2 %in% ids, ]
    dd <- dd[dd[[var]] != 0 & !is.na(dd[[var]]), ]
    Matrix::sparseMatrix(
      i = match(dd$ccode1, ids),
      j = match(dd$ccode2, ids),
      x = 1,
      dims = c(length(ids), length(ids)),
      dimnames = list(as.character(ids), as.character(ids))
    )
  }
  build_list <- function(var) {
    years <- sort(unique(m$year))
    Ws <- lapply(years, function(yr) {
      ids <- m$ccode[m$year == yr]
      build_W(var, yr, ids)
    })
    names(Ws) <- as.character(years)
    Ws
  }

  wrap <- function(Ws) {
    lapply(Ws, function(mm)
      slx_weights(style = "custom", matrix = mm, row_standardize = FALSE))
  }
  Wc <- wrap(build_list("cont"))
  Wa <- wrap(build_list("alliance"))
  Wd <- wrap(build_list("defense"))

  fit <- slx(
    ch_milex ~ milex_tm1 + ch2_milex + log_pop_tm1 +
               civilwar_tm1 + total_wars_tm1 +
               alliance_us + ch_milex_us + ch_milex_ussr +
               ally_ch_milex_us + ally_ch_milex_us_ussr +
               trend + Y42 + R2 + R3 + R4 + R5,
    data = m,
    spatial = list(
      civilwar_tm1   = Wc,
      total_wars_tm1 = list(contig = Wc, alliance = Wa),
      milex_tm1      = list(contig = Wc, defense  = Wd)
    ),
    id = "ccode", time = "year"
  )
  cf <- stats::coef(fit)

  # Headline spatial spillovers: must match paper to 2 decimal places
  expect_equal(round(cf[["W.civilwar_tm1"]],        2), -0.11)
  expect_equal(round(cf[["W.milex_tm1__contig"]],   3),  0.006)
  expect_equal(round(cf[["W.milex_tm1__defense"]],  3),  0.003)

  # Direct effects: within 0.1 of paper
  expect_lt(abs(cf[["milex_tm1"]]   - (-0.14)), 0.05)
  expect_lt(abs(cf[["ch2_milex"]]   - (-0.14)), 0.05)
  expect_lt(abs(cf[["trend"]]       - (-0.004)), 0.01)
  expect_lt(abs(cf[["alliance_us"]] - (-0.15)), 0.05)
})

test_that("slx() fits a single-W model and slx_effects() returns rows", {
  skip_if_not_installed("sf")
  skip_if_not_installed("spdep")

  nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"),
                    quiet = TRUE)
  W <- slx_weights(nc, style = "contiguity")

  fit <- slx(SID74 ~ BIR74 + NWBIR74,
             data = nc, W = W, lag = "BIR74")

  expect_s3_class(fit, "slx")
  expect_true("W.BIR74" %in% names(coef(fit)))

  eff <- slx_effects(fit)
  expect_s3_class(eff, "tbl_df")
  expect_true(all(c("direct", "indirect", "total") %in% eff$type))
})

test_that("slx_plot_effects() returns a ggplot", {
  skip_if_not_installed("sf")
  skip_if_not_installed("spdep")
  skip_if_not_installed("ggplot2")

  nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"),
                    quiet = TRUE)
  W <- slx_weights(nc, style = "contiguity")
  fit <- slx(SID74 ~ BIR74 + NWBIR74,
             data = nc, W = W, lag = "BIR74")

  p <- slx_plot_effects(fit)
  expect_s3_class(p, "ggplot")
})

test_that("defense_burden dataset loads and fits a multi-W SLX", {
  data(defense_burden)
  W_c <- slx_weights(style = "custom", matrix = defense_burden$W_contig,
                     row_standardize = FALSE)
  W_a <- slx_weights(style = "custom", matrix = defense_burden$W_alliance,
                     row_standardize = FALSE)

  fit <- slx(
    ch_milex ~ milex_tm1 + log_pop_tm1 + civilwar_tm1 + total_wars_tm1,
    data = defense_burden$data,
    spatial = list(
      civilwar_tm1   = W_c,
      total_wars_tm1 = list(contig = W_c, alliance = W_a)
    )
  )

  expect_s3_class(fit, "slx")
  expect_equal(fit$n, nrow(defense_burden$data))
  eff <- slx_effects(fit)
  expect_true(any(eff$variable == "total_wars_tm1" & eff$w_name == "alliance"))
})

test_that("slx_weights(style = 'custom') works without supplying x", {
  m <- matrix(c(0,1,0, 1,0,1, 0,1,0), nrow = 3)
  W <- slx_weights(style = "custom", matrix = m)
  expect_s3_class(W, "slx_W")
  expect_equal(W$n, 3L)
})

test_that("multiple W matrices on a single variable produce separate effects", {
  skip_if_not_installed("sf")
  skip_if_not_installed("spdep")

  nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"),
                    quiet = TRUE)
  W_contig <- slx_weights(nc, style = "contiguity")
  W_knn    <- slx_weights(nc, style = "knn", k = 4)

  fit <- slx(SID74 ~ BIR74 + NWBIR74,
             data = nc,
             spatial = list(
               BIR74   = list(contig = W_contig, knn = W_knn),
               NWBIR74 = W_contig
             ))

  expect_true("W.BIR74__contig" %in% names(coef(fit)))
  expect_true("W.BIR74__knn" %in% names(coef(fit)))

  eff <- slx_effects(fit)
  bir_indirect <- eff[eff$variable == "BIR74" & eff$type == "indirect", ]
  expect_equal(nrow(bir_indirect), 2L)
  expect_setequal(bir_indirect$w_name, c("contig", "knn"))
})

test_that("slx_weights() returns an slx_W object", {
  skip_if_not_installed("sf")

  nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"),
                    quiet = TRUE)
  W <- slx_weights(nc, style = "contiguity")

  expect_s3_class(W, "slx_W")
  expect_equal(W$n, nrow(nc))
  expect_true(W$row_standardized)
})

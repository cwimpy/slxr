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

test_that("slx_weights() returns an slx_W object", {
  skip_if_not_installed("sf")

  nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"),
                    quiet = TRUE)
  W <- slx_weights(nc, style = "contiguity")

  expect_s3_class(W, "slx_W")
  expect_equal(W$n, nrow(nc))
  expect_true(W$row_standardized)
})

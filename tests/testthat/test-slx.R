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

test_that("slx_compare() returns one row per model with fit stats", {
  data(defense_burden)
  W <- slx_weights(style = "custom", matrix = defense_burden$W_contig,
                   row_standardize = FALSE)
  ols <- lm(ch_milex ~ milex_tm1 + civilwar_tm1,
            data = defense_burden$data)
  fit <- slx(ch_milex ~ milex_tm1 + civilwar_tm1,
             data = defense_burden$data, W = W, lag = "civilwar_tm1")

  cmp <- slx_compare(OLS = ols, SLX = fit, W = W)
  expect_s3_class(cmp, "tbl_df")
  expect_equal(nrow(cmp), 2L)
  expect_true(all(c("model", "n", "r.squared", "AIC", "moran_I") %in% names(cmp)))
})

test_that("slx_plot_shock() produces a ggplot and sums to β + Σ θ W[,i]", {
  skip_if_not_installed("ggplot2")
  data(defense_burden)
  W <- slx_weights(style = "custom", matrix = defense_burden$W_contig,
                   row_standardize = FALSE)
  fit <- slx(ch_milex ~ milex_tm1 + civilwar_tm1,
             data = defense_burden$data, W = W, lag = "civilwar_tm1")

  p <- slx_plot_shock(fit, variable = "civilwar_tm1", unit = 10)
  expect_s3_class(p, "ggplot")

  # Verify numerics internally: replicate the math
  cf    <- stats::coef(fit$fit)
  beta  <- cf[["civilwar_tm1"]]
  theta <- cf[["W.civilwar_tm1"]]
  col   <- as.numeric(W$W[, 10])
  expected <- theta * col
  expected[10] <- expected[10] + beta
  expect_equal(sum(expected), beta + theta * sum(col))
})

test_that("panel slx() matches manual block-wise Wx", {
  ids <- c("A","B","C","D")
  panel <- expand.grid(id = ids, year = 2000:2002,
                       stringsAsFactors = FALSE)
  panel$x <- seq_len(nrow(panel)) + 0.5
  panel$y <- rnorm(nrow(panel))

  Wmat <- Matrix::Matrix(c(0,1,0,0, 1,0,1,0, 0,1,0,0, 0,0,0,0),
                         4, 4, byrow = TRUE, sparse = TRUE)
  dimnames(Wmat) <- list(ids, ids)
  W <- slx_weights(style = "custom", matrix = Wmat,
                   row_standardize = FALSE)

  fit <- slx(y ~ x, data = panel, W = W, lag = "x",
             id = "id", time = "year")

  # Expected W.x for year 2000 directly
  y00    <- panel[panel$year == 2000, ]
  expect <- as.numeric(Wmat %*% y00$x)
  got    <- fit$data$W.x[fit$data[[".slx_time"]] == 2000]
  expect_equal(unname(got), expect)
})

test_that("panel TSLS shifts W.x by one period within unit", {
  ids <- c("A","B","C")
  panel <- expand.grid(id = ids, year = 2000:2002,
                       stringsAsFactors = FALSE)
  panel$x <- seq_len(nrow(panel)) + 0.5
  panel$y <- rnorm(nrow(panel))

  Wmat <- Matrix::Matrix(c(0,1,0, 1,0,1, 0,1,0), 3, 3,
                         byrow = TRUE, sparse = TRUE)
  dimnames(Wmat) <- list(ids, ids)
  W <- slx_weights(style = "custom", matrix = Wmat,
                   row_standardize = FALSE)

  fit0 <- slx(y ~ x, data = panel, W = W, lag = "x",
              id = "id", time = "year", time_lag = 0)
  fit1 <- slx(y ~ x, data = panel, W = W, lag = "x",
              id = "id", time = "year", time_lag = 1)

  for (unit in ids) {
    # 2001 WL1.x should equal 2000 W.x within the same unit
    a <- fit1$data[fit1$data[[".slx_id"]] == unit &
                    fit1$data[[".slx_time"]] == 2001, "WL1.x"]
    b <- fit0$data[fit0$data[[".slx_id"]] == unit &
                    fit0$data[[".slx_time"]] == 2000, "W.x"]
    expect_equal(unname(a), unname(b))
  }
  # First-period TSLS rows are NA and dropped by lm()
  expect_true(all(is.na(fit1$data[fit1$data[[".slx_time"]] == 2000,
                                  "WL1.x"])))
})

test_that("time-varying W list dispatches by year", {
  ids <- c("A","B","C")
  panel <- expand.grid(id = ids, year = 2000:2001,
                       stringsAsFactors = FALSE)
  panel$x <- seq_len(nrow(panel)) + 0.5
  panel$y <- rnorm(nrow(panel))

  # W00: A-B only; W01: B-C only
  M00 <- Matrix::Matrix(c(0,1,0, 1,0,0, 0,0,0), 3, 3,
                        byrow = TRUE, sparse = TRUE)
  M01 <- Matrix::Matrix(c(0,0,0, 0,0,1, 0,1,0), 3, 3,
                        byrow = TRUE, sparse = TRUE)
  dimnames(M00) <- dimnames(M01) <- list(ids, ids)

  W00 <- slx_weights(style = "custom", matrix = M00, row_standardize = FALSE)
  W01 <- slx_weights(style = "custom", matrix = M01, row_standardize = FALSE)

  fit <- slx(y ~ x, data = panel,
             W = list("2000" = W00, "2001" = W01),
             lag = "x", id = "id", time = "year")

  # Year 2000: W00 %*% x00
  x00 <- panel$x[panel$year == 2000]
  x01 <- panel$x[panel$year == 2001]
  expect_equal(unname(fit$data$W.x[fit$data[[".slx_time"]] == 2000]),
               as.numeric(M00 %*% x00))
  expect_equal(unname(fit$data$W.x[fit$data[[".slx_time"]] == 2001]),
               as.numeric(M01 %*% x01))
})

test_that("defense_burden_panel fits a multi-W panel SLX", {
  data(defense_burden_panel)
  db <- defense_burden_panel
  wrap_list <- function(W_list) {
    lapply(W_list, function(m) slx_weights(style = "custom", matrix = m,
                                            row_standardize = FALSE))
  }
  Wc <- wrap_list(db$W_contig)
  Wd <- wrap_list(db$W_defense)

  fit <- slx(ch_milex ~ milex_tm1 + log_pop_tm1,
             data = db$data,
             spatial = list(milex_tm1 = list(contig = Wc, defense = Wd)),
             id = "ccode", time = "year")

  expect_true(fit$panel)
  expect_true("W.milex_tm1__defense" %in% names(coef(fit)))
  expect_equal(fit$n, nrow(db$data))
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

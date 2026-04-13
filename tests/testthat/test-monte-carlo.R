# Recovery test against a known data-generating process.
# Uses the same DGP as Wimpy, Whitten, and Williams (2021) Monte Carlo
# experiments: y = x1 + x2 + theta_1 W x1 + theta_2 W x2 + e,
# e ~ N(0, 2^2), W a row-standardized 200 x 200 contiguity matrix.
#
# We verify that slx() recovers true beta and theta values across a
# hard scenario (positive theta_1, negative theta_2) that any
# single-parameter spatial model would get wrong.

test_that("slx() recovers the DGP on the paper's Monte Carlo setup", {
  skip_on_cran()          # 200 sims take ~20s; keep out of CRAN timing
  skip_if_not_installed("Matrix")

  set.seed(648)
  n <- 100                # smaller than paper's 200 for faster test

  # Random row-standardized contiguity-style weights matrix
  raw <- matrix(0, n, n)
  for (i in seq_len(n)) {
    nbrs <- sample(setdiff(seq_len(n), i), size = 3)
    raw[i, nbrs] <- 1
  }
  raw <- raw / rowSums(raw)
  W_mat <- Matrix::Matrix(raw, sparse = TRUE)
  dimnames(W_mat) <- list(as.character(seq_len(n)), as.character(seq_len(n)))
  W <- slx_weights(style = "custom", matrix = W_mat,
                   row_standardize = FALSE)

  beta_true   <- c(x1 = 1.0,  x2 = 1.0)
  theta_true  <- c(theta_1 = 0.4, theta_2 = -0.8)

  nsim <- 200
  est  <- matrix(NA_real_, nsim, 4,
                 dimnames = list(NULL, c("b1", "b2", "t1", "t2")))
  for (i in seq_len(nsim)) {
    x1  <- runif(n, -10, 10)
    x2  <- runif(n,  -5,  5)
    Wx1 <- as.numeric(W_mat %*% x1)
    Wx2 <- as.numeric(W_mat %*% x2)
    y   <- beta_true["x1"] * x1 + beta_true["x2"] * x2 +
           theta_true["theta_1"] * Wx1 + theta_true["theta_2"] * Wx2 +
           rnorm(n, 0, 2)
    dat <- data.frame(y = y, x1 = x1, x2 = x2)
    fit <- slx(y ~ x1 + x2, data = dat, W = W, lag = c("x1", "x2"))
    cf  <- stats::coef(fit)
    est[i, ] <- c(cf["x1"], cf["x2"], cf["W.x1"], cf["W.x2"])
  }

  means <- colMeans(est)

  # Within 0.05 of truth on average over 200 sims
  expect_lt(abs(means["b1"] - beta_true["x1"]),  0.05)
  expect_lt(abs(means["b2"] - beta_true["x2"]),  0.05)
  expect_lt(abs(means["t1"] - theta_true["theta_1"]), 0.10)
  expect_lt(abs(means["t2"] - theta_true["theta_2"]), 0.10)
})

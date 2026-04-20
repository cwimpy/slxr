#' Tidy and glance methods for SLX models
#'
#' These methods make `slx` objects compatible with the `broom` and
#' `modelsummary` ecosystems.
#'
#' @param x An `slx` object.
#' @param conf.int Logical; include confidence intervals?
#' @param conf.level Confidence level.
#' @param ... Unused.
#'
#' @return
#' `tidy.slx()` returns a [tibble::tibble()] with one row per model
#'   coefficient (both direct and spatial-lag terms) and columns
#'   `term`, `estimate`, `std.error`, `statistic`, and `p.value`. When
#'   `conf.int = TRUE`, `conf.low` and `conf.high` columns are added.
#'
#' `glance.slx()` returns a one-row [tibble::tibble()] summarizing the
#'   overall fit, with columns `r.squared`, `adj.r.squared`, `sigma`,
#'   `statistic` (F statistic), `df`, `df.residual`, `nobs`, and
#'   `n_lag_terms` (the number of spatial-lag regressors in the model).
#'
#' @name slx-tidiers
#' @examples
#' data(defense_burden)
#' W <- slx_weights(style = "custom", matrix = defense_burden$W_contig,
#'                  row_standardize = FALSE)
#' fit <- slx(ch_milex ~ milex_tm1 + civilwar_tm1,
#'            data = defense_burden$data, W = W, lag = "civilwar_tm1")
#' tidy(fit)
#' glance(fit)
NULL

#' @rdname slx-tidiers
#' @importFrom generics tidy
#' @exportS3Method generics::tidy
tidy.slx <- function(x, conf.int = FALSE, conf.level = 0.95, ...) {
  s <- summary(x$fit)$coefficients
  out <- data.frame(
    term      = rownames(s),
    estimate  = s[, 1L],
    std.error = s[, 2L],
    statistic = s[, 3L],
    p.value   = s[, 4L],
    stringsAsFactors = FALSE,
    row.names = NULL
  )
  if (conf.int) {
    ci <- stats::confint(x$fit, level = conf.level)
    out$conf.low  <- ci[, 1L]
    out$conf.high <- ci[, 2L]
  }
  tibble::as_tibble(out)
}

#' @rdname slx-tidiers
#' @importFrom generics glance
#' @exportS3Method generics::glance
glance.slx <- function(x, ...) {
  g <- summary(x$fit)
  tibble::tibble(
    r.squared     = g$r.squared,
    adj.r.squared = g$adj.r.squared,
    sigma         = g$sigma,
    statistic     = g$fstatistic[[1L]],
    df            = g$fstatistic[[2L]],
    df.residual   = g$df[[2L]],
    nobs          = x$n,
    n_lag_terms   = nrow(x$lag_terms)
  )
}

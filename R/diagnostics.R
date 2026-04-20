#' Compare OLS, SLX, and other lm-like models side by side
#'
#' Builds a tidy tibble of fit statistics (observations, coefficient
#' count, R-squared, adjusted R-squared, residual standard error, AIC,
#' BIC) for any combination of `lm` and `slx` objects. If a weights
#' matrix is supplied, also reports Moran's I on each model's
#' residuals - the standard diagnostic for spatial autocorrelation
#' left unexplained by the fitted model.
#'
#' @param ... Named `lm` or `slx` models. Names are used as the model
#'   labels in the output.
#' @param W Optional weights matrix to use for Moran's I on residuals.
#'   Accepts an `slx_W`, a `listw` object from `spdep`, or `NULL` to
#'   skip the test. In panel mode, supply a list keyed by time value.
#'
#' @return A tibble with one row per model.
#'
#' @examples
#' data(defense_burden)
#' W <- slx_weights(style = "custom", matrix = defense_burden$W_contig,
#'                  row_standardize = FALSE)
#' ols <- lm(ch_milex ~ milex_tm1 + civilwar_tm1,
#'           data = defense_burden$data)
#' slx_fit <- slx(ch_milex ~ milex_tm1 + civilwar_tm1,
#'                data = defense_burden$data, W = W,
#'                lag = "civilwar_tm1")
#' slx_compare(OLS = ols, SLX = slx_fit, W = W)
#' @export
slx_compare <- function(..., W = NULL) {
  models <- list(...)
  if (length(models) == 0L) {
    stop("Supply at least one model.", call. = FALSE)
  }
  if (is.null(names(models)) || any(names(models) == "")) {
    names(models) <- sprintf("model%d", seq_along(models))
  }

  rows <- lapply(seq_along(models), function(i) {
    m    <- models[[i]]
    nm   <- names(models)[i]
    .compare_row(nm, m, W = W)
  })
  out <- do.call(rbind, rows)
  tibble::as_tibble(out)
}

.compare_row <- function(label, m, W = NULL) {
  lm_obj <- if (inherits(m, "slx")) m$fit else m
  if (!inherits(lm_obj, "lm")) {
    stop("Model '", label, "' is not an lm or slx object.",
         call. = FALSE)
  }
  s <- summary(lm_obj)

  moran <- NA_real_
  moran_p <- NA_real_
  if (!is.null(W)) {
    mres <- .moran_on_residuals(lm_obj, W)
    if (!is.null(mres)) {
      moran   <- mres$estimate
      moran_p <- mres$p.value
    }
  }

  data.frame(
    model       = label,
    class       = if (inherits(m, "slx")) "slx" else class(m)[1],
    n           = stats::nobs(lm_obj),
    k           = length(stats::coef(lm_obj)),
    r.squared   = s$r.squared,
    adj.r.squared = s$adj.r.squared,
    sigma       = s$sigma,
    AIC         = stats::AIC(lm_obj),
    BIC         = stats::BIC(lm_obj),
    moran_I     = moran,
    moran_p     = moran_p,
    stringsAsFactors = FALSE
  )
}

.moran_on_residuals <- function(lm_obj, W) {
  if (!requireNamespace("spdep", quietly = TRUE)) return(NULL)

  r <- stats::residuals(lm_obj)
  n <- length(r)

  listw <- .to_listw(W, n)
  if (is.null(listw)) return(NULL)

  res <- tryCatch(
    spdep::moran.test(r, listw, zero.policy = TRUE),
    error = function(e) NULL
  )
  if (is.null(res)) return(NULL)
  list(estimate = unname(res$estimate["Moran I statistic"]),
       p.value  = res$p.value)
}

.to_listw <- function(W, n) {
  if (inherits(W, "slx_W")) return(W$listw)
  if (inherits(W, "listw")) return(W)
  if (inherits(W, "Matrix") || is.matrix(W)) {
    if (nrow(W) != n) return(NULL)
    return(spdep::mat2listw(as.matrix(W), style = "W",
                            zero.policy = TRUE))
  }
  NULL
}

#' Sensitivity across alternative weights matrices
#'
#' Stub - v0.2. Planned: refit an SLX model across a list of alternative
#' `W` specifications and return a tidy comparison of key effects.
#'
#' @param fit An `slx` model.
#' @param W_list A named list of `slx_W` objects.
#'
#' @return
#' Not yet implemented; currently called only for its side effect of
#' signalling an error. A future release will return a
#' [tibble::tibble()] comparing key effect estimates across
#' alternative weights matrices.
#'
#' @export
#' @keywords internal
slx_sensitivity <- function(fit, W_list) {
  stop("slx_sensitivity() is not yet implemented.", call. = FALSE)
}

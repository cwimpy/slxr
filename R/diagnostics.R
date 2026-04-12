#' Compare SLX with alternative models
#'
#' Stub — v0.2. Planned: side-by-side fit statistics (AIC/BIC), Moran's I
#' on residuals, and LM tests versus OLS and SAR baselines.
#'
#' @param ... Fitted models.
#' @export
#' @keywords internal
slx_compare <- function(...) {
  stop("slx_compare() is not yet implemented.", call. = FALSE)
}

#' Sensitivity across alternative weights matrices
#'
#' Stub — v0.2. Planned: refit an SLX model across a list of alternative
#' `W` specifications and return a tidy comparison of key effects.
#'
#' @param fit An `slx` model.
#' @param W_list A named list of `slx_W` objects.
#' @export
#' @keywords internal
slx_sensitivity <- function(fit, W_list) {
  stop("slx_sensitivity() is not yet implemented.", call. = FALSE)
}

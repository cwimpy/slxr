#' Fit a Spatial-X (SLX) model
#'
#' Estimates a Spatial-X regression of the form
#' \deqn{y = X\beta + WX\theta + \varepsilon,}
#' where `W` is a spatial weights matrix and `X` includes both the
#' directly-entering regressors and a user-specified subset that is
#' spatially lagged. SLX estimation is OLS on the augmented design matrix,
#' which makes estimation, interpretation, and effects decomposition much
#' simpler than for SAR-family models (Wimpy, Whitten, and Williams 2021).
#'
#' @param formula A standard model formula, e.g. `y ~ x1 + x2 + x3`.
#' @param data A data frame (or `sf` object) whose rows correspond, in
#'   order, to the rows/columns of `W`.
#' @param W An `slx_W` object produced by [slx_weights()], or a numeric or
#'   sparse matrix. Required when `spatial` is not supplied.
#' @param lag Character vector of variable names from `formula` that
#'   should be spatially lagged. If `NULL` (default) and `W` is supplied,
#'   all right-hand-side variables are lagged.
#' @param order Integer vector giving the orders of `W` to include for
#'   each lagged variable (e.g. `1:2` adds both `Wx` and `W²x`). Default
#'   `1`.
#' @param spatial Optional named list for variable-specific weights
#'   matrices. Names must match variables in `formula`. Each element is
#'   either an `slx_W` object or a list of them (for multiple `W` per
#'   variable, as in Wimpy, Whitten, and Williams 2021). When supplied,
#'   `W` and `lag` are ignored.
#' @param time_lag Integer, number of time periods to lag the spatial
#'   terms (TSLS). Requires `id` and `time`.
#' @param id,time Column names identifying panel unit and period. Only
#'   used when `time_lag > 0`.
#' @param na.action How to handle missing values. Defaults to
#'   `stats::na.omit`.
#'
#' @return An object of class `slx` with elements:
#'   \describe{
#'     \item{`fit`}{The underlying `lm` object.}
#'     \item{`formula`}{The expanded model formula.}
#'     \item{`call`}{The original call.}
#'     \item{`W`}{The weights matrix (or list thereof) used.}
#'     \item{`lag_terms`}{A data frame mapping spatial-lag terms to their
#'       source variable, W matrix, and order.}
#'     \item{`data`}{The (possibly augmented) model frame.}
#'   }
#'
#' @references
#' Wimpy, C., Whitten, G. D., & Williams, L. K. (2021). X Marks the Spot:
#' Unlocking the Treasure of Spatial-X Models. *Journal of Politics*,
#' 83(2), 722–739.
#'
#' Vega, S. H., & Elhorst, J. P. (2015). The SLX Model.
#' *Journal of Regional Science*, 55(3), 339–363.
#'
#' @examples
#' \dontrun{
#' library(sf)
#' nc <- st_read(system.file("shape/nc.shp", package = "sf"))
#' W  <- slx_weights(nc, style = "contiguity")
#' fit <- slx(SID74 ~ BIR74 + NWBIR74, data = nc, W = W, lag = "BIR74")
#' summary(fit)
#' slx_effects(fit)
#' }
#' @export
slx <- function(formula,
                data,
                W = NULL,
                lag = NULL,
                order = 1L,
                spatial = NULL,
                time_lag = 0L,
                id = NULL,
                time = NULL,
                na.action = stats::na.omit) {

  cl <- match.call()

  if (time_lag > 0L) {
    stop("time_lag (TSLS) support is planned for a future release.",
         call. = FALSE)
  }

  # Determine which vars get lagged and through which W
  if (!is.null(spatial)) {
    spec <- .normalize_spatial(spatial, order = order)
  } else {
    if (is.null(W)) {
      stop("Supply either `W` (and optionally `lag`) or `spatial`.",
           call. = FALSE)
    }
    rhs_vars <- all.vars(formula[[3L]])
    if (is.null(lag)) lag <- rhs_vars
    lag <- intersect(lag, rhs_vars)
    if (length(lag) == 0L) {
      stop("No variables selected for spatial lagging.", call. = FALSE)
    }
    spec <- .normalize_spatial(
      stats::setNames(rep(list(W), length(lag)), lag),
      order = order
    )
  }

  # Build the augmented model frame
  mf <- stats::model.frame(formula, data = data, na.action = na.action)
  n  <- nrow(mf)

  lag_terms <- data.frame(
    variable = character(),
    w_name   = character(),
    order    = integer(),
    colname  = character(),
    stringsAsFactors = FALSE
  )

  for (v in names(spec)) {
    if (!v %in% colnames(mf)) {
      stop("Variable '", v, "' is not in `formula`/`data`.", call. = FALSE)
    }
    xv <- mf[[v]]
    if (!is.numeric(xv)) {
      stop("Spatial lag requires numeric variable; '", v, "' is not.",
           call. = FALSE)
    }
    for (entry in spec[[v]]) {
      Wk <- entry$W
      if (Wk$n != n) {
        stop("W for variable '", v, "' has n = ", Wk$n,
             " but model has ", n, " rows.", call. = FALSE)
      }
      Wmat <- Wk$W
      for (ord in entry$order) {
        lagged <- xv
        for (i in seq_len(ord)) lagged <- as.numeric(Wmat %*% lagged)
        colnm <- if (ord == 1L) sprintf("W.%s", v)
                 else sprintf("W%d.%s", ord, v)
        if (!is.null(entry$name)) {
          colnm <- sprintf("%s__%s", colnm, entry$name)
        }
        mf[[colnm]] <- lagged
        lag_terms <- rbind(lag_terms, data.frame(
          variable = v, w_name = entry$name %||% "W",
          order = ord, colname = colnm,
          stringsAsFactors = FALSE
        ))
      }
    }
  }

  rhs <- paste(
    c(attr(stats::terms(formula), "term.labels"),
      lag_terms$colname),
    collapse = " + "
  )
  full_formula <- stats::as.formula(
    paste(deparse(formula[[2L]]), "~", rhs)
  )

  fit <- stats::lm(full_formula, data = mf)

  out <- list(
    fit        = fit,
    formula    = full_formula,
    orig_formula = formula,
    call       = cl,
    W          = if (!is.null(spatial)) spatial else W,
    spec       = spec,
    lag_terms  = lag_terms,
    data       = mf,
    n          = n
  )
  class(out) <- "slx"
  out
}

#' @export
print.slx <- function(x, ...) {
  cat("Spatial-X (SLX) model\n")
  cat("Call: "); print(x$call)
  cat("\nCoefficients:\n")
  print(stats::coef(x$fit))
  invisible(x)
}

#' @export
summary.slx <- function(object, ...) {
  s <- summary(object$fit)
  structure(list(
    call         = object$call,
    coefficients = s$coefficients,
    lag_terms    = object$lag_terms,
    r.squared    = s$r.squared,
    adj.r.squared = s$adj.r.squared,
    sigma        = s$sigma,
    df           = s$df,
    n            = object$n
  ), class = "summary.slx")
}

#' @export
print.summary.slx <- function(x, ...) {
  cat("Spatial-X (SLX) model summary\n")
  cat("n =", x$n,
      "   R^2 =", signif(x$r.squared, 3),
      "   adj R^2 =", signif(x$adj.r.squared, 3), "\n\n")
  stats::printCoefmat(x$coefficients, signif.stars = TRUE)
  if (nrow(x$lag_terms) > 0L) {
    cat("\nSpatial lag terms:\n")
    print(x$lag_terms, row.names = FALSE)
  }
  invisible(x)
}

#' @export
coef.slx <- function(object, ...) stats::coef(object$fit)

#' @export
vcov.slx <- function(object, ...) stats::vcov(object$fit)

# --- internal helpers ---------------------------------------------------------

.normalize_spatial <- function(spatial, order = 1L) {
  if (is.null(names(spatial)) || any(names(spatial) == "")) {
    stop("`spatial` must be a named list keyed by variable name.",
         call. = FALSE)
  }
  lapply(spatial, function(entry) {
    if (inherits(entry, "slx_W")) {
      list(list(W = entry, order = order, name = NULL))
    } else if (is.list(entry)) {
      # multiple Ws for one variable
      nms <- names(entry)
      lapply(seq_along(entry), function(i) {
        e <- entry[[i]]
        if (!inherits(e, "slx_W")) {
          stop("Each element must be an slx_W object.", call. = FALSE)
        }
        list(W = e, order = order,
             name = if (!is.null(nms)) nms[i] else paste0("W", i))
      })
    } else {
      stop("Unsupported entry in `spatial`; must be slx_W or list of slx_W.",
           call. = FALSE)
    }
  })
}

`%||%` <- function(a, b) if (is.null(a)) b else a

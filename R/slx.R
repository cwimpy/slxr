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
#' @section Cross-sectional and panel modes:
#' When `id` and `time` are `NULL`, `slx()` treats the data as a single
#' cross-section: rows of `data` must correspond, in order, to the rows
#' and columns of `W`. When both `id` and `time` are supplied, `slx()`
#' enters panel mode and performs block-wise spatial lagging period by
#' period. In panel mode the weights matrices must have `dimnames`
#' matching the unit identifiers in `data[[id]]`; the same units need
#' not appear in every period (unbalanced panels are supported).
#'
#' @section Time-varying weights:
#' In panel mode, a `W` argument can be either (a) a single `slx_W`
#' object applied to every period or (b) a named list of `slx_W`
#' objects keyed by the stringified `time` value (e.g.
#' `list("1990" = W_90, "1991" = W_91)`). The same options apply to
#' any entry inside `spatial`.
#'
#' @section Temporally-lagged spatial lag (TSLS):
#' The `time_lag` argument implements equation 7 of Wimpy, Whitten,
#' and Williams (2021): it lags every constructed spatial term `W_t x`
#' by `time_lag` periods within each unit so that the regressor becomes
#' `W_t x_{t - time_lag}`. The first `time_lag` periods per unit drop
#' out, mirroring any temporally-lagged variable.
#'
#' @param formula A standard model formula, e.g. `y ~ x1 + x2 + x3`.
#' @param data A data frame (or `sf` object) whose rows correspond, in
#'   order, to the rows/columns of `W` (cross-sectional mode) or contain
#'   `id` and `time` columns (panel mode).
#' @param W An `slx_W` object produced by [slx_weights()], a numeric or
#'   sparse matrix, or - in panel mode - a named list of such objects
#'   keyed by time value. Required when `spatial` is not supplied.
#' @param lag Character vector of variable names from `formula` that
#'   should be spatially lagged. If `NULL` (default) and `W` is supplied,
#'   all right-hand-side variables are lagged.
#' @param order Integer vector giving the orders of `W` to include for
#'   each lagged variable (e.g. `1:2` adds both `Wx` and `W^2 x`).
#'   Default `1`.
#' @param spatial Optional named list for variable-specific weights
#'   matrices. Names must match variables in `formula`. Each element is
#'   either an `slx_W`, a list of `slx_W`s (multiple channels for one
#'   variable), a time-keyed list of `slx_W`s (single channel, time-
#'   varying), or a named list of channels whose values are themselves
#'   single or time-keyed `slx_W`s.
#' @param time_lag Integer, number of time periods to lag the spatial
#'   terms (TSLS). Requires `id` and `time`. Default `0`.
#' @param id,time Column names identifying the panel unit and period.
#'   Required for panel mode or TSLS. `time` must be numeric.
#' @param na.action How to handle missing values. Defaults to
#'   `stats::na.omit` in cross-sectional mode. In panel mode missing
#'   values on formula variables are dropped; `id` and `time` must never
#'   be missing.
#'
#' @return An object of class `slx` with elements:
#'   \describe{
#'     \item{`fit`}{The underlying `lm` object.}
#'     \item{`formula`}{The expanded model formula.}
#'     \item{`call`}{The original call.}
#'     \item{`W`}{The weights matrix (or list thereof) used.}
#'     \item{`lag_terms`}{A data frame mapping spatial-lag terms to their
#'       source variable, W matrix, order, and time lag.}
#'     \item{`data`}{The (possibly augmented) model frame.}
#'     \item{`panel`}{Logical flag.}
#'   }
#'
#' @references
#' Wimpy, C., Whitten, G. D., & Williams, L. K. (2021). X Marks the Spot:
#' Unlocking the Treasure of Spatial-X Models. *Journal of Politics*,
#' 83(2), 722-739.
#'
#' Vega, S. H., & Elhorst, J. P. (2015). The SLX Model.
#' *Journal of Regional Science*, 55(3), 339-363.
#'
#' @examples
#' data(defense_burden)
#' W_c <- slx_weights(style = "custom", matrix = defense_burden$W_contig,
#'                    row_standardize = FALSE)
#' fit <- slx(ch_milex ~ milex_tm1 + log_pop_tm1 + civilwar_tm1,
#'            data = defense_burden$data, W = W_c, lag = "civilwar_tm1")
#' slx_effects(fit)
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

  panel_mode <- !is.null(id) && !is.null(time)
  if (xor(is.null(id), is.null(time))) {
    stop("`id` and `time` must both be supplied, or both NULL.",
         call. = FALSE)
  }
  if (time_lag > 0L && !panel_mode) {
    stop("`time_lag > 0` requires panel mode (supply `id` and `time`).",
         call. = FALSE)
  }

  if (panel_mode) {
    if (!(id   %in% names(data))) stop("Column '", id,   "' not in data.", call. = FALSE)
    if (!(time %in% names(data))) stop("Column '", time, "' not in data.", call. = FALSE)
    if (!is.numeric(data[[time]])) {
      stop("`time` column must be numeric.", call. = FALSE)
    }
    time_values <- sort(unique(data[[time]]))
  } else {
    time_values <- NULL
  }

  # Determine which vars get lagged and through which W
  if (!is.null(spatial)) {
    spec <- .normalize_spatial(spatial, order = order,
                               time_values = time_values)
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
      order = order,
      time_values = time_values
    )
  }

  # Build the augmented model frame
  if (panel_mode) {
    mf <- .panel_model_frame(formula, data, id, time)
  } else {
    mf <- stats::model.frame(formula, data = data, na.action = na.action)
  }
  n  <- nrow(mf)

  lag_terms <- data.frame(
    variable = character(),
    w_name   = character(),
    order    = integer(),
    time_lag = integer(),
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
      for (ord in entry$order) {
        lagged <- xv
        for (i in seq_len(ord)) {
          lagged <- if (panel_mode) {
            .compute_wx_panel(lagged,
                              mf[[".slx_id"]],
                              mf[[".slx_time"]],
                              entry$provider)
          } else {
            .compute_wx_cross(lagged, entry$provider)
          }
        }
        if (time_lag > 0L) {
          lagged <- .shift_within_unit(lagged,
                                        mf[[".slx_id"]],
                                        mf[[".slx_time"]],
                                        time_lag)
        }
        colnm <- .build_colname(v, ord, time_lag, entry$name)
        mf[[colnm]] <- lagged
        lag_terms <- rbind(lag_terms, data.frame(
          variable = v,
          w_name   = entry$name %||% "W",
          order    = ord,
          time_lag = time_lag,
          colname  = colnm,
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
    fit          = fit,
    formula      = full_formula,
    orig_formula = formula,
    call         = cl,
    W            = if (!is.null(spatial)) spatial else W,
    spec         = spec,
    lag_terms    = lag_terms,
    data         = mf,
    n            = n,
    panel        = panel_mode,
    id           = id,
    time         = time,
    time_lag     = time_lag
  )
  class(out) <- "slx"
  out
}

#' @export
print.slx <- function(x, ...) {
  cat("Spatial-X (SLX) model",
      if (isTRUE(x$panel)) " (panel)" else "", "\n", sep = "")
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
    n            = object$n,
    panel        = isTRUE(object$panel)
  ), class = "summary.slx")
}

#' @export
print.summary.slx <- function(x, ...) {
  cat("Spatial-X (SLX) model summary",
      if (isTRUE(x$panel)) " (panel)" else "", "\n", sep = "")
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

.build_colname <- function(v, ord, time_lag, name) {
  head <- if (ord == 1L) "W" else sprintf("W%d", ord)
  if (time_lag > 0L) head <- sprintf("%sL%d", head, time_lag)
  colnm <- sprintf("%s.%s", head, v)
  if (!is.null(name)) colnm <- sprintf("%s__%s", colnm, name)
  colnm
}

.compute_wx_cross <- function(x, provider) {
  if (!inherits(provider, "slx_W")) {
    stop("Cross-sectional slx() expects a single slx_W per variable.",
         call. = FALSE)
  }
  if (provider$n != length(x)) {
    stop("W has n = ", provider$n, " but model has ", length(x), " rows.",
         call. = FALSE)
  }
  as.numeric(provider$W %*% x)
}

.compute_wx_panel <- function(x, unit, tm, provider) {
  out <- numeric(length(x))
  time_groups <- split(seq_along(x), tm)
  for (t_str in names(time_groups)) {
    rows  <- time_groups[[t_str]]
    Wt    <- .provider_for_time(provider, t_str)
    Wmat  <- Wt$W
    ids_t <- as.character(unit[rows])

    if (is.null(rownames(Wmat))) {
      stop("Panel mode requires W to have row/column names matching the ",
           "id column. No dimnames found.", call. = FALSE)
    }
    missing <- setdiff(ids_t, rownames(Wmat))
    if (length(missing) > 0L) {
      stop("W for time '", t_str, "' lacks rows for ids: ",
           paste(utils::head(missing, 5), collapse = ", "),
           if (length(missing) > 5L) ", ..." else "",
           call. = FALSE)
    }
    W_sub <- Wmat[ids_t, ids_t, drop = FALSE]
    out[rows] <- as.numeric(W_sub %*% x[rows])
  }
  out
}

.provider_for_time <- function(provider, t_str) {
  if (inherits(provider, "slx_W")) {
    provider
  } else if (is.list(provider)) {
    if (is.null(provider[[t_str]])) {
      stop("No W supplied for time '", t_str, "'.", call. = FALSE)
    }
    provider[[t_str]]
  } else {
    stop("Invalid W provider.", call. = FALSE)
  }
}

.shift_within_unit <- function(x, unit, tm, k) {
  key_have <- paste(unit, tm, sep = "\r")
  key_want <- paste(unit, tm - k, sep = "\r")
  pos <- match(key_want, key_have)
  x[pos]
}

.panel_model_frame <- function(formula, data, id, time) {
  vars <- unique(c(all.vars(formula), id, time))
  if (!all(vars %in% names(data))) {
    missing <- setdiff(vars, names(data))
    stop("Columns not found in data: ", paste(missing, collapse = ", "),
         call. = FALSE)
  }
  src <- as.data.frame(data[, vars, drop = FALSE])
  if (any(is.na(src[[id]])) || any(is.na(src[[time]]))) {
    stop("Missing values are not allowed in `id` or `time`.", call. = FALSE)
  }
  formula_vars <- all.vars(formula)
  keep <- stats::complete.cases(src[, formula_vars, drop = FALSE])
  src  <- src[keep, , drop = FALSE]
  mf   <- stats::model.frame(formula, data = src,
                             na.action = stats::na.pass)
  mf[[".slx_id"]]   <- src[[id]]
  mf[[".slx_time"]] <- src[[time]]
  mf
}

.looks_time_varying <- function(lst, time_values) {
  if (!is.list(lst) || is.null(names(lst)) || any(names(lst) == "")) return(FALSE)
  if (is.null(time_values)) return(FALSE)
  # Time-varying if every time value in the data is covered by the list
  # (extra entries for years outside the data are fine)
  all(as.character(time_values) %in% names(lst))
}

.is_valid_provider <- function(x, time_values) {
  inherits(x, "slx_W") || .looks_time_varying(x, time_values)
}

.normalize_spatial <- function(spatial, order = 1L, time_values = NULL) {
  if (is.null(names(spatial)) || any(names(spatial) == "")) {
    stop("`spatial` must be a named list keyed by variable name.",
         call. = FALSE)
  }
  lapply(spatial, function(entry) {
    if (inherits(entry, "slx_W")) {
      list(list(provider = entry, order = order, name = NULL))
    } else if (.looks_time_varying(entry, time_values)) {
      # single channel, time-varying
      .validate_time_varying(entry)
      list(list(provider = entry, order = order, name = NULL))
    } else if (is.list(entry)) {
      # multi-channel: each element is either slx_W or time-keyed list
      nms <- names(entry)
      if (is.null(nms) || any(nms == "")) {
        stop("Multi-channel entries must be a named list.", call. = FALSE)
      }
      lapply(seq_along(entry), function(i) {
        e <- entry[[i]]
        if (inherits(e, "slx_W")) {
          list(provider = e, order = order, name = nms[i])
        } else if (.looks_time_varying(e, time_values)) {
          .validate_time_varying(e)
          list(provider = e, order = order, name = nms[i])
        } else {
          stop("Channel '", nms[i],
               "' must be an slx_W or a time-keyed list of slx_W objects.",
               call. = FALSE)
        }
      })
    } else {
      stop("Unsupported entry in `spatial`.", call. = FALSE)
    }
  })
}

.validate_time_varying <- function(lst) {
  ok <- vapply(lst, inherits, logical(1), what = "slx_W")
  if (!all(ok)) {
    stop("Every element of a time-keyed W list must be an slx_W object.",
         call. = FALSE)
  }
  invisible(TRUE)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

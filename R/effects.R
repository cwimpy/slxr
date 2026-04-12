#' Direct, indirect, and total effects from an SLX model
#'
#' For an SLX model the effects decomposition is trivial — no matrix
#' inversion, no simulation. For each variable \eqn{x} that enters both
#' directly and as a spatial lag, the direct effect is its OLS coefficient
#' \eqn{\hat\beta} and the indirect effect at order \eqn{k} is
#' \eqn{\hat\theta_k}. Standard errors come straight from `vcov()`.
#'
#' @param object An `slx` object returned by [slx()].
#' @param by_order Logical; if `TRUE`, report indirect effects separately
#'   by order of W. Default `FALSE` sums across orders for a single
#'   indirect effect per variable–W combination.
#' @param conf.level Confidence level for reported intervals. Default 0.95.
#'
#' @return A tibble with columns `variable`, `w_name`, `order` (when
#'   `by_order = TRUE`), `type` (direct/indirect/total), `estimate`,
#'   `std.error`, `conf.low`, `conf.high`, `p.value`.
#'
#' @examples
#' \dontrun{
#' fit <- slx(y ~ x1 + x2, data = df, W = W, lag = "x1")
#' slx_effects(fit)
#' }
#' @export
slx_effects <- function(object, by_order = FALSE, conf.level = 0.95) {

  stopifnot(inherits(object, "slx"))

  cf  <- stats::coef(object$fit)
  vc  <- stats::vcov(object$fit)
  df  <- object$fit$df.residual
  crit <- stats::qt(1 - (1 - conf.level) / 2, df)

  lt <- object$lag_terms

  # Direct effects: one row per lagged variable, using its base coefficient
  direct_vars <- unique(lt$variable)
  direct_rows <- lapply(direct_vars, function(v) {
    if (!v %in% names(cf)) return(NULL)
    est <- cf[[v]]
    se  <- sqrt(vc[v, v])
    .effect_row(v, NA_character_, NA_integer_, "direct",
                est, se, crit, df)
  })
  direct_tbl <- do.call(rbind, direct_rows)

  # Indirect effects
  if (by_order) {
    indirect_rows <- lapply(seq_len(nrow(lt)), function(i) {
      colnm <- lt$colname[i]
      if (!colnm %in% names(cf)) return(NULL)
      est <- cf[[colnm]]
      se  <- sqrt(vc[colnm, colnm])
      .effect_row(lt$variable[i], lt$w_name[i], lt$order[i],
                  "indirect", est, se, crit, df)
    })
    indirect_tbl <- do.call(rbind, indirect_rows)
  } else {
    # Sum across orders per (variable, w_name); variance uses linear combo
    key <- paste(lt$variable, lt$w_name, sep = "\r")
    groups <- split(seq_len(nrow(lt)), key)
    indirect_rows <- lapply(groups, function(idx) {
      cols <- lt$colname[idx]
      cols <- cols[cols %in% names(cf)]
      if (length(cols) == 0L) return(NULL)
      est <- sum(cf[cols])
      v_sub <- vc[cols, cols, drop = FALSE]
      se  <- sqrt(sum(v_sub))
      .effect_row(lt$variable[idx[1L]], lt$w_name[idx[1L]],
                  NA_integer_, "indirect", est, se, crit, df)
    })
    indirect_tbl <- do.call(rbind, indirect_rows)
  }

  # Total effects: direct + (summed) indirect per (variable, w_name)
  total_rows <- lapply(direct_vars, function(v) {
    base_est <- cf[[v]]
    sub <- lt[lt$variable == v, , drop = FALSE]
    w_names <- unique(sub$w_name)
    lapply(w_names, function(wn) {
      cols <- sub$colname[sub$w_name == wn]
      cols <- cols[cols %in% names(cf)]
      all_cols <- c(v, cols)
      est <- sum(cf[all_cols])
      v_sub <- vc[all_cols, all_cols, drop = FALSE]
      se  <- sqrt(sum(v_sub))
      .effect_row(v, wn, NA_integer_, "total", est, se, crit, df)
    })
  })
  total_tbl <- do.call(rbind, unlist(total_rows, recursive = FALSE))

  out <- rbind(direct_tbl, indirect_tbl, total_tbl)
  rownames(out) <- NULL
  if (!by_order) out$order <- NULL
  tibble::as_tibble(out)
}

.effect_row <- function(variable, w_name, order, type,
                        est, se, crit, df) {
  tstat <- est / se
  pval  <- 2 * stats::pt(-abs(tstat), df)
  data.frame(
    variable  = variable,
    w_name    = w_name,
    order     = order,
    type      = type,
    estimate  = est,
    std.error = se,
    conf.low  = est - crit * se,
    conf.high = est + crit * se,
    p.value   = pval,
    stringsAsFactors = FALSE
  )
}

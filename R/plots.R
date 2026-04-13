#' Coefficient plot of direct, indirect, and total effects
#'
#' Produces a ggplot of the direct, indirect, and total effects from an
#' SLX model, with 95% confidence intervals. For models with
#' variable-specific weights matrices, effects are faceted by `w_name`
#' so spillover patterns from each matrix are visible side-by-side.
#'
#' @param fit An `slx` object returned by [slx()].
#' @param types Character vector of effect types to include. Any subset of
#'   `c("direct", "indirect", "total")`. Default shows all three.
#' @param conf.level Confidence level for the intervals. Default 0.95.
#' @param by_order Logical; if `TRUE`, break indirect effects out by order
#'   of W. Default `FALSE`.
#' @param ... Passed to [slx_effects()].
#'
#' @return A `ggplot` object.
#'
#' @examples
#' \dontrun{
#' fit <- slx(SID74 ~ BIR74 + NWBIR74, data = nc, W = W, lag = "BIR74")
#' slx_plot_effects(fit)
#' }
#' @export
slx_plot_effects <- function(fit,
                             types = c("direct", "indirect", "total"),
                             conf.level = 0.95,
                             by_order = FALSE,
                             ...) {

  stopifnot(inherits(fit, "slx"))
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required for slx_plot_effects().",
         call. = FALSE)
  }

  types <- match.arg(types, several.ok = TRUE)

  eff <- slx_effects(fit, by_order = by_order, conf.level = conf.level)
  eff <- eff[eff$type %in% types, , drop = FALSE]
  eff$type <- factor(eff$type, levels = c("direct", "indirect", "total"))

  # Label: variable, annotated with order when faceting by order
  eff$label <- if (by_order) {
    ifelse(is.na(eff$order),
           eff$variable,
           sprintf("%s (W^%d)", eff$variable, eff$order))
  } else {
    eff$variable
  }

  multi_w <- length(unique(stats::na.omit(eff$w_name))) > 1L

  p <- ggplot2::ggplot(
         eff,
         ggplot2::aes(x = .data$estimate,
                      y = .data$label,
                      colour = .data$type)
       ) +
    ggplot2::geom_vline(xintercept = 0, linetype = "dashed",
                        colour = "grey60") +
    ggplot2::geom_errorbar(
      ggplot2::aes(xmin = .data$conf.low, xmax = .data$conf.high),
      width = 0.2,
      orientation = "y",
      position = ggplot2::position_dodge(width = 0.5)
    ) +
    ggplot2::geom_point(
      size = 2,
      position = ggplot2::position_dodge(width = 0.5)
    ) +
    ggplot2::labs(
      x = "Effect estimate",
      y = NULL,
      colour = "Effect",
      title = "SLX effects decomposition",
      caption = sprintf("%.0f%% confidence intervals",
                        100 * conf.level)
    ) +
    ggplot2::theme_minimal()

  if (multi_w) {
    p <- p + ggplot2::facet_wrap(~ w_name, scales = "free_x")
  }

  p
}

#' Plot how indirect effects decay across orders of W
#'
#' For SLX models fit with higher-order lags (`order = 1:k`), shows the
#' size of the indirect effect at each order, with confidence intervals.
#'
#' @param fit An `slx` model fit with higher-order `W` terms.
#' @param variables Optional character vector restricting to specific
#'   lagged variables. Default plots all.
#' @param conf.level Confidence level.
#'
#' @return A `ggplot` object.
#' @export
slx_plot_decay <- function(fit, variables = NULL, conf.level = 0.95) {

  stopifnot(inherits(fit, "slx"))
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required for slx_plot_decay().",
         call. = FALSE)
  }

  eff <- slx_effects(fit, by_order = TRUE, conf.level = conf.level)
  eff <- eff[eff$type == "indirect" & !is.na(eff$order), , drop = FALSE]
  if (!is.null(variables)) {
    eff <- eff[eff$variable %in% variables, , drop = FALSE]
  }
  if (nrow(eff) == 0L) {
    stop("No higher-order indirect effects found; did you fit with ",
         "`order > 1`?", call. = FALSE)
  }

  ggplot2::ggplot(
    eff,
    ggplot2::aes(x = .data$order, y = .data$estimate,
                 colour = .data$variable, group = .data$variable)
  ) +
    ggplot2::geom_hline(yintercept = 0, linetype = "dashed",
                        colour = "grey60") +
    ggplot2::geom_ribbon(
      ggplot2::aes(ymin = .data$conf.low, ymax = .data$conf.high,
                   fill = .data$variable),
      alpha = 0.15, colour = NA
    ) +
    ggplot2::geom_line() +
    ggplot2::geom_point(size = 2) +
    ggplot2::scale_x_continuous(breaks = unique(eff$order)) +
    ggplot2::labs(
      x = "Order of W",
      y = "Indirect effect",
      colour = "Variable", fill = "Variable",
      title = "Decay of indirect effects across orders"
    ) +
    ggplot2::theme_minimal()
}

#' Counterfactual shock plot
#'
#' Given a fitted SLX model, a choice of variable, and a target unit,
#' returns a plot of the predicted change in the outcome across every
#' unit in the sample under a unit shock to that variable in the
#' target unit.
#'
#' For an SLX model at first order with channels indexed by `c`, the
#' predicted change at unit `j` from a shock of size `magnitude` to
#' variable `x` in unit `i` is
#' \deqn{\text{magnitude}\ \left(\beta\ \mathbb{1}\{j=i\} + \sum_c \theta_c\ W_c[j, i]\right).}
#' Higher-order lags add additional `theta_{c,k} (W_c^k)[j, i]` terms.
#' No simulation is required: the shock effect is a single column of
#' the spatial multiplier.
#'
#' If an `sf` object with matching row count is supplied via `geom`,
#' the result is drawn as a choropleth. Otherwise a horizontal bar of
#' the largest effects is returned.
#'
#' @param fit A cross-sectional `slx` model. Panel shocks are planned
#'   for a future release.
#' @param variable Character, the name of a spatially-lagged regressor
#'   in `fit` to shock.
#' @param unit Integer row index (or character id, if the weights
#'   matrix has dimnames matching something in `fit$data`) of the unit
#'   receiving the shock.
#' @param magnitude Numeric, shock size. Default `1`.
#' @param geom Optional `sf` object with `nrow(geom) == fit$n` aligned
#'   to `fit$data`. If supplied, the function returns a map.
#' @param top_n For the non-map plot, how many non-zero indirect
#'   effects to show. Default `15`.
#'
#' @return A `ggplot` object.
#'
#' @examples
#' \dontrun{
#' data(defense_burden)
#' W_c <- slx_weights(style = "custom", matrix = defense_burden$W_contig,
#'                    row_standardize = FALSE)
#' fit <- slx(ch_milex ~ milex_tm1 + civilwar_tm1,
#'            data = defense_burden$data, W = W_c,
#'            lag = "civilwar_tm1")
#' slx_plot_shock(fit, variable = "civilwar_tm1", unit = 1)
#' }
#' @export
slx_plot_shock <- function(fit, variable, unit,
                           magnitude = 1,
                           geom = NULL,
                           top_n = 15) {

  stopifnot(inherits(fit, "slx"))
  if (isTRUE(fit$panel)) {
    stop("slx_plot_shock() is not yet implemented for panel fits. ",
         "A panel version requires a target time period and will ",
         "land in a future release.", call. = FALSE)
  }
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required for slx_plot_shock().",
         call. = FALSE)
  }

  lt  <- fit$lag_terms
  lt  <- lt[lt$variable == variable, , drop = FALSE]
  if (nrow(lt) == 0L) {
    stop("Variable '", variable,
         "' is not spatially lagged in this fit.", call. = FALSE)
  }

  cf <- stats::coef(fit$fit)
  n  <- fit$n

  # Resolve unit to integer row index
  idx <- if (is.numeric(unit)) {
    as.integer(unit)
  } else if (is.character(unit)) {
    # try to find in first W available
    first_W <- fit$spec[[variable]][[1]]$provider$W
    rn <- rownames(first_W)
    if (is.null(rn) || !unit %in% rn) {
      stop("Could not resolve unit '", unit, "'.", call. = FALSE)
    }
    match(unit, rn)
  } else {
    stop("`unit` must be an integer row index or a character id.",
         call. = FALSE)
  }
  if (is.na(idx) || idx < 1L || idx > n) {
    stop("`unit` index out of range.", call. = FALSE)
  }

  # Direct contribution
  effect <- numeric(n)
  if (variable %in% names(cf)) effect[idx] <- cf[[variable]]

  # Indirect contributions: sum over channels and orders
  for (i in seq_len(nrow(lt))) {
    colnm <- lt$colname[i]
    if (!colnm %in% names(cf)) next
    theta <- cf[[colnm]]
    ord   <- lt$order[i]
    w_name <- lt$w_name[i]

    # Find the slx_W that produced this term
    channels <- fit$spec[[variable]]
    provider <- NULL
    for (ch in channels) {
      if (identical(ch$name %||% "W", w_name)) {
        provider <- ch$provider
        break
      }
    }
    if (is.null(provider) || !inherits(provider, "slx_W")) next

    Wmat <- provider$W
    Wk   <- Wmat
    if (ord > 1L) for (k in 2:ord) Wk <- Wk %*% Wmat
    effect <- effect + theta * as.numeric(Wk[, idx])
  }

  effect <- effect * magnitude

  if (!is.null(geom)) {
    if (!requireNamespace("sf", quietly = TRUE)) {
      stop("Package 'sf' is required when `geom` is supplied.",
           call. = FALSE)
    }
    if (nrow(geom) != n) {
      stop("`geom` must have ", n, " rows to align with fit.",
           call. = FALSE)
    }
    gdf <- geom
    gdf$.effect <- effect
    gdf$.shocked <- seq_len(n) == idx
    return(
      ggplot2::ggplot(gdf) +
        ggplot2::geom_sf(ggplot2::aes(fill = .data$.effect),
                         colour = "grey80", linewidth = 0.1) +
        ggplot2::geom_sf(data = gdf[gdf$.shocked, , drop = FALSE],
                         fill = NA, colour = "black", linewidth = 0.6) +
        ggplot2::scale_fill_gradient2(
          low = "#b2182b", mid = "white", high = "#2166ac",
          midpoint = 0
        ) +
        ggplot2::labs(
          title = sprintf(
            "Predicted change in outcome from shock to %s (unit %d)",
            variable, idx
          ),
          fill = "Effect"
        ) +
        ggplot2::theme_minimal()
    )
  }

  # No geometry: show the largest-magnitude effects as a bar
  df <- data.frame(
    row    = seq_len(n),
    effect = effect,
    shocked = seq_len(n) == idx
  )
  df <- df[order(-abs(df$effect)), , drop = FALSE]
  df <- utils::head(df, top_n)
  df$row <- factor(df$row, levels = rev(df$row))

  ggplot2::ggplot(df,
                  ggplot2::aes(x = .data$effect, y = .data$row,
                               fill = .data$shocked)) +
    ggplot2::geom_col() +
    ggplot2::geom_vline(xintercept = 0, linetype = "dashed",
                        colour = "grey60") +
    ggplot2::scale_fill_manual(values = c(`TRUE` = "firebrick",
                                          `FALSE` = "steelblue"),
                               guide = "none") +
    ggplot2::labs(
      x = "Predicted change in outcome",
      y = "Row index",
      title = sprintf(
        "Top %d effects from shock to %s (unit %d)",
        nrow(df), variable, idx
      )
    ) +
    ggplot2::theme_minimal()
}

#' Heatmap of a spatial weights matrix
#'
#' A quick visual check on the structure of a weights matrix. For large
#' `n` the heatmap becomes noisy; use the `max_n` argument to subsample.
#'
#' @param W An `slx_W` object.
#' @param max_n Optional integer; if `nrow(W) > max_n`, a random sample
#'   of rows/columns is plotted. Default `NULL` (plot everything).
#' @param labels Optional character vector of row/column labels.
#'
#' @return A `ggplot` object.
#' @export
slx_plot_W <- function(W, max_n = NULL, labels = NULL) {

  if (!inherits(W, "slx_W")) {
    stop("`W` must be an slx_W object from slx_weights().", call. = FALSE)
  }
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required for slx_plot_W().",
         call. = FALSE)
  }

  M <- as.matrix(W$W)
  n <- nrow(M)
  idx <- seq_len(n)
  if (!is.null(max_n) && n > max_n) {
    idx <- sort(sample.int(n, max_n))
    M   <- M[idx, idx, drop = FALSE]
    if (!is.null(labels)) labels <- labels[idx]
  }

  if (is.null(labels)) labels <- as.character(idx)
  rownames(M) <- colnames(M) <- labels

  df <- data.frame(
    row = factor(rep(labels, times = length(labels)), levels = labels),
    col = factor(rep(labels, each  = length(labels)), levels = labels),
    w   = as.numeric(M)
  )

  ggplot2::ggplot(df, ggplot2::aes(x = .data$col, y = .data$row,
                                   fill = .data$w)) +
    ggplot2::geom_tile() +
    ggplot2::scale_y_discrete(limits = rev(labels)) +
    ggplot2::scale_fill_gradient(low = "white", high = "steelblue") +
    ggplot2::labs(
      x = NULL, y = NULL, fill = "w",
      title = sprintf("Weights matrix (%s, n = %d)",
                      W$style, W$n)
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 90, hjust = 1, size = 7),
      axis.text.y = ggplot2::element_text(size = 7),
      panel.grid  = ggplot2::element_blank()
    )
}

#' @importFrom rlang .data
#' @keywords internal
#' @noRd
.__rlang_data_pronoun_import__ <- function() NULL

utils::globalVariables(c("w_name"))

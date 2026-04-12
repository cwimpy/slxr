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

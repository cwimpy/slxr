#' Construct a spatial weights matrix
#'
#' A thin, opinionated wrapper around common `spdep` weights constructors.
#' Returns a standardized `slx_W` object that carries both the sparse matrix
#' and the `listw` form used by downstream routines.
#'
#' @param x An `sf` object (for `"contiguity"`, `"knn"`, `"distance"`), a
#'   matrix of coordinates, or a raw numeric/sparse matrix (for
#'   `"custom"`).
#' @param style Weights style. One of `"contiguity"` (queen), `"rook"`,
#'   `"knn"`, `"distance"`, or `"custom"`.
#' @param k Number of neighbors for `style = "knn"`.
#' @param threshold Distance threshold for `style = "distance"` (units of
#'   the coordinate system).
#' @param row_standardize Logical; row-standardize the matrix? Default
#'   `TRUE`. The paper notes row-standardization is a theoretical choice;
#'   set to `FALSE` when connection count should itself carry weight.
#' @param matrix A numeric or sparse `Matrix` for `style = "custom"`.
#' @param ... Passed to the underlying `spdep` constructor.
#'
#' @return An object of class `slx_W` with elements `W` (sparse matrix),
#'   `listw` (spdep `listw` object), `style`, and `row_standardized`.
#'
#' @examples
#' \dontrun{
#' library(sf)
#' nc <- st_read(system.file("shape/nc.shp", package = "sf"))
#' W  <- slx_weights(nc, style = "contiguity")
#' }
#' @export
slx_weights <- function(x,
                        style = c("contiguity", "rook", "knn",
                                  "distance", "custom"),
                        k = 5,
                        threshold = NULL,
                        row_standardize = TRUE,
                        matrix = NULL,
                        ...) {

  style <- match.arg(style)

  if (style == "custom") {
    if (is.null(matrix)) {
      stop("`matrix` must be supplied when style = 'custom'.", call. = FALSE)
    }
    W <- Matrix::Matrix(as.matrix(matrix), sparse = TRUE)
  } else {
    if (!requireNamespace("spdep", quietly = TRUE)) {
      stop("Package 'spdep' is required for style = '", style, "'.",
           call. = FALSE)
    }

    nb <- switch(style,
      contiguity = spdep::poly2nb(x, queen = TRUE),
      rook       = spdep::poly2nb(x, queen = FALSE),
      knn        = spdep::knn2nb(spdep::knearneigh(
                     suppressWarnings(sf::st_centroid(x)), k = k)),
      distance   = {
        if (is.null(threshold)) {
          stop("`threshold` must be supplied when style = 'distance'.",
               call. = FALSE)
        }
        coords <- suppressWarnings(sf::st_centroid(x))
        spdep::dnearneigh(coords, d1 = 0, d2 = threshold)
      }
    )

    lw <- spdep::nb2listw(nb,
                          style = if (row_standardize) "W" else "B",
                          zero.policy = TRUE)
    W <- spdep::listw2mat(lw)
    W <- Matrix::Matrix(W, sparse = TRUE)
  }

  if (style != "custom" && row_standardize) {
    # already handled by style = "W"
  } else if (style == "custom" && row_standardize) {
    rs <- Matrix::rowSums(W)
    rs[rs == 0] <- 1
    W <- W / rs
  }

  lw_out <- if (style == "custom") spdep::mat2listw(as.matrix(W),
                                                    style = "M",
                                                    zero.policy = TRUE)
            else lw

  out <- list(
    W                = W,
    listw            = lw_out,
    style            = style,
    row_standardized = row_standardize,
    n                = nrow(W)
  )
  class(out) <- "slx_W"
  out
}

#' @export
print.slx_W <- function(x, ...) {
  cat("<slx_W>  n =", x$n,
      "  style =", x$style,
      "  row-standardized =", x$row_standardized, "\n")
  invisible(x)
}

#' Multiply W by a numeric vector
#'
#' Internal helper; returns Wx as a plain numeric vector.
#' @param W An `slx_W` object or compatible matrix.
#' @param x A numeric vector of length `nrow(W)`.
#' @keywords internal
#' @noRd
wx <- function(W, x) {
  M <- if (inherits(W, "slx_W")) W$W else W
  as.numeric(M %*% x)
}

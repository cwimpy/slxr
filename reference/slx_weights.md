# Construct a spatial weights matrix

A thin, opinionated wrapper around common `spdep` weights constructors.
Returns a standardized `slx_W` object that carries both the sparse
matrix and the `listw` form used by downstream routines.

## Usage

``` r
slx_weights(
  x = NULL,
  style = c("contiguity", "rook", "knn", "distance", "custom"),
  k = 5,
  threshold = NULL,
  row_standardize = TRUE,
  matrix = NULL,
  ...
)
```

## Arguments

- x:

  An `sf` object (for `"contiguity"`, `"knn"`, `"distance"`), a matrix
  of coordinates, or a raw numeric/sparse matrix (for `"custom"`).

- style:

  Weights style. One of `"contiguity"` (queen), `"rook"`, `"knn"`,
  `"distance"`, or `"custom"`.

- k:

  Number of neighbors for `style = "knn"`.

- threshold:

  Distance threshold for `style = "distance"` (units of the coordinate
  system).

- row_standardize:

  Logical; row-standardize the matrix? Default `TRUE`. The paper notes
  row-standardization is a theoretical choice; set to `FALSE` when
  connection count should itself carry weight.

- matrix:

  A numeric or sparse `Matrix` for `style = "custom"`.

- ...:

  Passed to the underlying `spdep` constructor.

## Value

An object of class `slx_W` with elements `W` (sparse matrix), `listw`
(spdep `listw` object), `style`, and `row_standardized`.

## Examples

``` r
if (FALSE) { # \dontrun{
library(sf)
nc <- st_read(system.file("shape/nc.shp", package = "sf"))
W  <- slx_weights(nc, style = "contiguity")
} # }
```
